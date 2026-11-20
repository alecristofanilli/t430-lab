#!/usr/bin/env python3
"""lab-blackbox — la scatola nera del T430.

Gira sempre, in background, e tiene in memoria gli ultimi 30 minuti della macchina a intervalli
di pochi secondi: pressione di CPU, memoria e I/O (PSI), temperature, frequenza, consumo, eventi
di throttling, processi più attivi e processi bloccati in I/O.

Quando qualcosa va storto la scatola nera si "apre" da sola e salva su disco cosa è successo
prima e dopo:
  - stallo di CPU, memoria o I/O, segnalato dal kernel tramite i trigger PSI
    (/proc/pressure/*: il kernel sveglia questo processo appena lo stallo supera la soglia);
  - nuovo evento di throttling termico della CPU;
  - richiesta manuale (SIGUSR1, comando `lab-blackbox-dump`).

Ogni apertura crea ~/lab/blackbox/<data>-<motivo>/ con:
  before.jsonl   i campioni dei minuti precedenti
  after.jsonl    i campioni del minuto successivo (scritto dopo 60 s)
  processes.txt  tutti i processi, ordinati per CPU e memoria
  kernel.txt     log del kernel e del sistema degli ultimi minuti
Sono i dati che servono per capire un rallentamento il giorno dopo, senza averlo dovuto riprodurre.
"""

import argparse
import collections
import json
import os
import pathlib
import pwd
import select
import signal
import subprocess
import sys
import time

PAGE = os.sysconf("SC_PAGE_SIZE")
TICK = os.sysconf("SC_CLK_TCK")

# soglia di stallo (µs) in una finestra (µs): "some" = almeno un task fermo ad aspettare la risorsa
TRIGGERS = {
    "cpu": "some 300000 2000000",
    "memory": "some 150000 2000000",
    "io": "some 300000 2000000",
}
# le finestre devono essere multipli di 2 s per i processi senza CAP_SYS_RESOURCE (kernel >= 6.5)
TRIGGERS_SENSITIVE = {res: "some 50000 2000000" for res in TRIGGERS}


def log(msg):
    print(f"lab-blackbox: {msg}", flush=True)


def read(path, default=None):
    try:
        return pathlib.Path(path).read_text().strip()
    except OSError:
        return default


def read_int(path, default=None):
    v = read(path)
    try:
        return int(v) if v is not None else default
    except ValueError:
        return default


def psi(res):
    out = {}
    for line in (read(f"/proc/pressure/{res}", "") or "").splitlines():
        kind, *fields = line.split()
        out[kind] = {k: float(v) for k, v in (f.split("=") for f in fields)}
    return out


def processes():
    procs = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        stat = read(f"/proc/{pid}/stat")
        if not stat:
            continue
        r = stat.rfind(")")
        comm = stat[stat.find("(") + 1 : r]
        rest = stat[r + 2 :].split()
        try:
            procs[int(pid)] = {
                "comm": comm,
                "state": rest[0],
                "ticks": int(rest[11]) + int(rest[12]),
                "rss_mib": int(rest[21]) * PAGE / 2**20,
            }
        except (IndexError, ValueError):
            continue
    return procs


def thermal():
    temps = {}
    for zone in sorted(pathlib.Path("/sys/class/thermal").glob("thermal_zone*")):
        t = read_int(zone / "temp")
        if t is not None:
            temps[read(zone / "type", zone.name)] = t / 1000
    return temps


def throttle_count():
    total = 0
    for f in pathlib.Path("/sys/devices/system/cpu").glob("cpu[0-9]*/thermal_throttle/*_throttle_count"):
        total += read_int(f, 0)
    return total


def meminfo():
    info = {}
    for line in (read("/proc/meminfo", "") or "").splitlines():
        key, _, value = line.partition(":")
        if key in ("MemAvailable", "SwapFree", "SwapTotal", "Dirty"):
            info[key] = int(value.split()[0]) // 1024  # MiB
    return info


class Recorder:
    def __init__(self, outdir, owner, sample_s, ring_minutes, cooldown_s):
        self.outdir = pathlib.Path(outdir)
        self.owner = owner
        self.sample_s = sample_s
        self.ring = collections.deque(maxlen=int(ring_minutes * 60 / sample_s))
        self.cooldown_s = cooldown_s
        self.last_dump = {}
        self.pending_after = []  # (cartella, timestamp evento, scadenza)
        self.prev_ticks = {}
        self.prev_time = time.monotonic()
        self.prev_throttle = throttle_count()

    def sample(self):
        now_m = time.monotonic()
        dt = max(now_m - self.prev_time, 1e-3)
        procs = processes()
        ticks = {pid: p["ticks"] for pid, p in procs.items()}
        # Un processo nato dopo il campione precedente ha consumato tutti i suoi tick nell'intervallo:
        # base 0, altrimenti proprio il processo che causa uno stallo improvviso risulterebbe allo 0%.
        # Al primo campione in assoluto non c'è un intervallo da misurare.
        first = not self.prev_ticks
        top = sorted(
            (
                ((t - (t if first else self.prev_ticks.get(pid, 0))) / TICK / dt * 100, procs[pid]["comm"], pid)
                for pid, t in ticks.items()
            ),
            reverse=True,
        )[:5]
        self.prev_ticks, self.prev_time = ticks, now_m
        bat = read_int("/sys/class/power_supply/BAT0/power_now")
        s = {
            "t": time.time(),
            "psi": {res: psi(res).get("some", {}).get("avg10") for res in ("cpu", "memory", "io")},
            "load": (read("/proc/loadavg", "") or "").split()[:3],
            "mem": meminfo(),
            "temp_c": thermal(),
            "freq_mhz": (read_int("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq", 0) or 0) // 1000,
            "battery_w": round(bat / 1e6, 2) if bat else None,
            "throttle_events": throttle_count(),
            "top_cpu": [{"pct": round(p, 1), "comm": c, "pid": pid} for p, c, pid in top if p > 0.5],
            "blocked_io": sorted({p["comm"] for p in procs.values() if p["state"] == "D"}),
            "nprocs": len(procs),
        }
        self.ring.append(s)
        self._flush_after()
        if s["throttle_events"] > self.prev_throttle:
            self.prev_throttle = s["throttle_events"]
            self.dump("throttling")
        return s

    def _chown(self, path):
        if self.owner:
            try:
                os.chown(path, self.owner.pw_uid, self.owner.pw_gid)
            except OSError:
                pass

    def _write(self, path, text):
        path.write_text(text)
        self._chown(path)

    def _flush_after(self):
        now = time.time()
        for item in list(self.pending_after):
            folder, t_event, deadline = item
            if now >= deadline:
                after = [s for s in self.ring if s["t"] > t_event]
                self._write(folder / "after.jsonl", "".join(json.dumps(s) + "\n" for s in after))
                self.pending_after.remove(item)

    def dump(self, reason, force=False):
        now = time.time()
        if not force and now - self.last_dump.get(reason, 0) < self.cooldown_s:
            return None
        self.last_dump[reason] = now
        folder = self.outdir / f"{time.strftime('%Y%m%dT%H%M%S')}-{reason}"
        folder.mkdir(parents=True, exist_ok=True)
        self._chown(self.outdir)
        self._chown(folder)

        self._write(folder / "before.jsonl", "".join(json.dumps(s) + "\n" for s in self.ring))

        procs = processes()
        lines = [f"{'PID':>7} {'STATO':5} {'RSS MiB':>9}  COMANDO"]
        for pid, p in sorted(procs.items(), key=lambda kv: -kv[1]["rss_mib"]):
            lines.append(f"{pid:>7} {p['state']:5} {p['rss_mib']:>9.1f}  {p['comm']}")
        pressure = "\n".join(f"{res}: {read(f'/proc/pressure/{res}', 'n/d')}" for res in ("cpu", "memory", "io"))
        self._write(folder / "processes.txt", pressure + "\n\n" + "\n".join(lines) + "\n")

        kernel = []
        for cmd in (
            ["journalctl", "-k", "--since", "-10min", "--no-pager", "-o", "short-precise"],
            ["journalctl", "-p", "warning", "--since", "-10min", "--no-pager", "-o", "short-precise"],
        ):
            try:
                kernel.append(f"$ {' '.join(cmd)}\n" + subprocess.run(cmd, capture_output=True, text=True, timeout=20).stdout)
            except (OSError, subprocess.SubprocessError) as e:
                kernel.append(f"$ {' '.join(cmd)}\n(non disponibile: {e})\n")
        self._write(folder / "kernel.txt", "\n".join(kernel))

        self.pending_after.append((folder, now, now + 60))
        log(f"aperta: {reason} → {folder}")
        return folder


def open_triggers(table):
    poller = select.poll()
    fds = {}
    for res, spec in table.items():
        try:
            fd = os.open(f"/proc/pressure/{res}", os.O_RDWR | os.O_NONBLOCK)
            os.write(fd, spec.encode() + b"\0")
            poller.register(fd, select.POLLPRI)
            fds[fd] = res
            log(f"trigger PSI {res}: {spec}")
        except OSError as e:
            log(f"trigger PSI {res} non disponibile ({e}): resta il campionamento")
    return poller, fds


def main():
    ap = argparse.ArgumentParser(description="Scatola nera del T430")
    ap.add_argument("--dir", default=os.path.expanduser("~/lab/blackbox"))
    ap.add_argument("--owner", help="utente proprietario dei file salvati")
    ap.add_argument("--sample", type=float, default=5.0, help="secondi tra un campione e l'altro")
    ap.add_argument("--ring-minutes", type=float, default=30.0)
    ap.add_argument("--cooldown", type=float, default=300.0, help="secondi minimi tra due aperture per lo stesso motivo")
    ap.add_argument("--sensitive", action="store_true", help="soglie PSI basse, per i test")
    ap.add_argument("--selftest", action="store_true", help="3 campioni, un'apertura forzata, poi esce")
    args = ap.parse_args()

    owner = pwd.getpwnam(args.owner) if args.owner else None
    rec = Recorder(args.dir, owner, args.sample, args.ring_minutes, args.cooldown)

    if args.selftest:
        for _ in range(3):
            time.sleep(0.5)
            rec.sample()
        folder = rec.dump("selftest", force=True)
        rec.pending_after[-1] = (folder, 0, 0)
        rec._flush_after()
        print(folder)
        return 0

    manual = {"requested": False}
    running = {"on": True}
    signal.signal(signal.SIGUSR1, lambda *_: manual.update(requested=True))
    signal.signal(signal.SIGTERM, lambda *_: running.update(on=False))

    poller, fds = open_triggers(TRIGGERS_SENSITIVE if args.sensitive else TRIGGERS)
    next_sample = time.monotonic()
    log(f"in ascolto: campione ogni {args.sample}s, memoria {args.ring_minutes} min, uscite in {args.dir}")
    while running["on"]:
        timeout_ms = max(0.0, next_sample - time.monotonic()) * 1000
        try:
            events = poller.poll(timeout_ms)
        except InterruptedError:
            events = []
        for fd, ev in events:
            if ev & select.POLLERR:
                log(f"trigger {fds.get(fd)} chiuso dal kernel")
                poller.unregister(fd)
            elif ev & select.POLLPRI:
                rec.sample()  # fotografa subito il momento dello stallo
                rec.dump(f"stallo-{fds[fd]}")
        if manual["requested"]:
            manual["requested"] = False
            rec.sample()
            rec.dump("manuale", force=True)
        if time.monotonic() >= next_sample:
            rec.sample()
            next_sample += args.sample
    log("chiusa")
    return 0


if __name__ == "__main__":
    sys.exit(main())
