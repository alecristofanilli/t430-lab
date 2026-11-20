# lab-snapshot — fotografa lo stato della macchina e lo salva come JSON.
#
#   lab-snapshot [etichetta] [--no-cpu]
#
# Un file per misura in ~/lab/results (o $LAB_DIR/results). Confrontando i file
# prima/dopo una modifica si vede se l'ottimizzazione ha funzionato davvero.
# Per misure di consumo affidabili: a batteria, schermo a luminosità fissa, 5 minuti a riposo.

label="manual"
run_cpu=1
for arg in "$@"; do
  case "$arg" in
    --no-cpu) run_cpu=0 ;;
    *) label="$arg" ;;
  esac
done

outdir="${LAB_DIR:-$HOME/lab}/results"
mkdir -p "$outdir"

ts="$(date -Iseconds)"
stamp="$(date +%Y%m%dT%H%M%S)"

read_or() { if [ -r "$1" ]; then cat "$1"; else echo "$2"; fi; }

# Generazione NixOS attiva
link="$(readlink /nix/var/nix/profiles/system 2>/dev/null || echo "system-0-link")"
gen="${link#system-}"
gen="${gen%-link}"

kernel="$(uname -r)"
cmdline="$(cat /proc/cmdline)"
governor="$(read_or /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor unknown)"
boot_time="$(systemd-analyze time 2>/dev/null | head -n1 || echo unknown)"

# Energia
bat=/sys/class/power_supply/BAT0
ac_online="$(read_or /sys/class/power_supply/AC/online unknown)"
power_w="null"
if [ -r "$bat/power_now" ]; then
  power_w="$(awk -v u="$(cat "$bat/power_now")" 'BEGIN { printf "%.2f", u / 1000000 }')"
fi
health_pct="null"
if [ -r "$bat/energy_full" ] && [ -r "$bat/energy_full_design" ]; then
  health_pct="$(awk -v f="$(cat "$bat/energy_full")" -v d="$(cat "$bat/energy_full_design")" \
    'BEGIN { if (d > 0) printf "%.1f", 100 * f / d; else print "null" }')"
fi

# Memoria a riposo (MiB)
mem_used="$(free -m | awk '/^Mem:/ { print $3 }')"

# Sensori (temperature, ventola)
sensors_json="$(sensors -j 2>/dev/null || echo '{}')"
fan_rpm="$(awk '/^speed:/ { print $2 }' /proc/acpi/ibm/fan 2>/dev/null || true)"

# Mitigazioni CPU attive
vulns="$(
  for f in /sys/devices/system/cpu/vulnerabilities/*; do
    if [ -r "$f" ]; then printf '%s\t%s\n' "$(basename "$f")" "$(cat "$f")"; fi
  done | jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {(.[0]): .[1]}) | add // {}'
)"

# Micro-benchmark CPU (10 s, tutti i thread)
cpu_eps="null"
if [ "$run_cpu" -eq 1 ]; then
  cpu_eps="$(sysbench cpu --threads="$(nproc)" --time=10 run | awk '/events per second/ { print $4 }')"
  cpu_eps="${cpu_eps:-null}"
fi

out="$outdir/${stamp}-${label}.json"
jq -n \
  --arg ts "$ts" \
  --arg label "$label" \
  --arg gen "$gen" \
  --arg kernel "$kernel" \
  --arg cmdline "$cmdline" \
  --arg governor "$governor" \
  --arg boot_time "$boot_time" \
  --arg ac_online "$ac_online" \
  --arg fan_rpm "${fan_rpm:-unknown}" \
  --argjson power_w "$power_w" \
  --argjson health_pct "$health_pct" \
  --argjson mem_used "${mem_used:-null}" \
  --argjson cpu_eps "$cpu_eps" \
  --argjson sensors "$sensors_json" \
  --argjson vulns "$vulns" \
  '{
    timestamp: $ts, label: $label, nixos_generation: $gen,
    kernel: $kernel, cmdline: $cmdline, governor: $governor, boot_time: $boot_time,
    power: { ac_online: $ac_online, draw_watts: $power_w, battery_health_pct: $health_pct },
    memory_used_mib: $mem_used, fan_rpm: $fan_rpm,
    cpu_sysbench_events_per_s: $cpu_eps,
    sensors: $sensors, cpu_vulnerabilities: $vulns
  }' >"$out"

echo "Salvato: $out"
jq -r '"gen \(.nixos_generation) | kernel \(.kernel) | \(.power.draw_watts // "?") W | CPU \(.cpu_sysbench_events_per_s // "-") ev/s | RAM \(.memory_used_mib) MiB"' "$out"
