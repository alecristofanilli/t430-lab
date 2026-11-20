# t430-lab — istruzioni per Claude sulla macchina

Questo repo È il sistema operativo del ThinkPad T430 di Alessandro. È una **macchina di test**:
hai accesso completo e il mandato di spingere su customizzazione, ottimizzazione e ricerca.
Non serve prudenza sul software: serve **metodo**. Ogni modifica è un esperimento con
ipotesi, misura e conclusione, e deve restare reversibile.

## Hardware (da completare al primo avvio: `lscpu`, `lshw -short`, `lsblk`, `tlp-stat -b`)
- ThinkPad T430, Intel Ivy Bridge (Gen 3), grafica Intel HD 4000, socket rPGA988B
- CPU: ?  RAM: ?  Disco: ?  Wi-Fi: ?  Batteria (salute %): ?
- Firmware: BIOS Lenovo (coreboot = fase hardware, la decide ed esegue Alessandro — vedi docs/hardware.md)

## Architettura del repo
- `hosts/t430/` — ciò che dipende da questa macchina (disco con disko, hardware)
- `modules/base.nix` — boot (GRUB UEFI+legacy), nix, rete, utente, snapper, zram
- `modules/impermanence.nix` — root azzerata a ogni boot; stato ammesso solo se dichiarato
- `modules/performance.nix` — tuning dietro `lab.tuning.enable`
- `modules/experiments.nix` — specialisations: vanilla (controllo), perf, battery
- `modules/agent.nix` — sudo senza password, turno notturno opzionale (`lab.agent.nightly`)
- `modules/home.nix` — dotfile con home-manager
- `pkgs/` + `bench/` — strumenti del laboratorio
- `shells/` — ambienti di ricerca (`nix develop .#datascience` ecc.)

## Strumenti del laboratorio
| comando | a cosa serve |
|---|---|
| `lab-snapshot <etichetta>` | misura (consumo, CPU, temperature, mitigazioni, generazione) → ~/lab/results/*.json |
| `lab-compare a.json b.json` | tabella prima/dopo con delta percentuali |
| `lab-try [minuti]` | applica la config in prova con **revert automatico** (default 5 min) |
| `lab-keep` | conferma la config in prova e la rende permanente |
| `lab-fs-diff` | file scritti nella root effimera da questo avvio (stato non dichiarato) |
| `nvd diff /run/booted-system /run/current-system` | cosa è cambiato tra generazioni |

## Metodo (obbligatorio)
1. **Baseline**: `lab-snapshot <tema>-before`. Per i consumi: a batteria, luminosità fissa, 5 min di riposo,
   ripeti 3 volte. Un numero solo non è un dato.
2. **Una variabile alla volta**, nel modulo giusto. `nix flake check` deve passare.
3. **Applica con `lab-try`**, mai direttamente con `switch`. Se perdi la sessione, il revert ti salva.
   Per kernel, initrd e bootloader: `nixos-rebuild boot` + riavvio (lo stato precedente resta in GRUB).
4. **Rimisura**: `lab-snapshot <tema>-after`, poi `lab-compare`.
5. **Decidi**: beneficio misurabile → `lab-keep`, commit e voce in NOTEBOOK.md.
   Nessun beneficio → revert, voce in NOTEBOOK.md comunque (anche i risultati negativi sono risultati).

## Limiti (gli unici)
- Non toccare partizioni, LUKS, `/persist/secrets` e i dati in `/home` senza chiedere ad Alessandro.
- Firmware e hardware: solo lui. Puoi preparare script e guide, non eseguire flash.
- Niente stato imperativo fuori dal repo (`nix-env -i`, file a mano in /etc): se serve, è Nix.
- Prima di disattivare la rete o SSH in modo permanente, chiedi.

## Backlog di ricerca
- [ ] Completare la sezione Hardware; baseline completa a corrente e a batteria (3 ripetizioni)
- [ ] Confronto default / vanilla / perf / battery: costo reale delle mitigazioni su Ivy Bridge
- [ ] Scheduler sched_ext: scx_lavd vs scx_bpfland vs scx_rustland vs EEVDF (latenza interattiva + build)
- [ ] Kernel: linuxPackages_latest vs CachyOS (xddxdd/nix-cachyos-kernel) vs custom `-march=ivybridge`
      con config ridotta (localmodconfig); misurare boot, RAM, prestazioni
- [ ] Tempo di boot: `systemd-analyze blame/critical-chain/plot`, obiettivo dichiarato e misurato
- [ ] Soglie batteria (`tlp-stat -b`), curva thinkfan sotto stress-ng, profilo termico con s-tui
- [ ] Ridurre il persistito al minimo con `lab-fs-diff`
- [ ] Hardening: lynis, sysctl kernel, AppArmor, kernel lockdown; specialisation "seclab" con tool offensivi
- [ ] Osservabilità: bpftrace/perf, flamegraph di boot e workload tipici
- [ ] Tema coerente (stylix) e waybar con metriche del laboratorio (W, °C, scheduler attivo)
- [ ] Integrazione col cluster Kubernetes su Raspberry (kubectl, k9s, WireGuard)
- [ ] Generatore di report: dai JSON di ~/lab/results a grafici e a una pagina riassuntiva
