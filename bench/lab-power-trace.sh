# lab-power-trace [intervallo_s] [durata_s] — traccia di consumo per componente in CSV.
#
# Unisce due fonti: la batteria (potenza totale assorbita dal portatile) e i contatori RAPL
# della CPU (package, core, grafica integrata). La differenza stima tutto il resto: schermo,
# Wi-Fi, SSD, chipset. Con abbastanza tracce si costruisce un modello del consumo del T430.
# Da usare a batteria per avere il dato totale.

if [ "$(id -u)" -ne 0 ]; then exec sudo --preserve-env=LAB_DIR,HOME "$0" "$@"; fi

interval="${1:-1}"
duration="${2:-300}"
rapl=/sys/class/powercap/intel-rapl:0
bat=/sys/class/power_supply/BAT0

outdir="${LAB_DIR:-$HOME/lab}/power"
mkdir -p "$outdir"
out="$outdir/$(date +%Y%m%dT%H%M%S).csv"
echo "t,battery_w,pkg_w,core_w,gfx_w,rest_w,cpu_temp_c,freq_mhz,backlight" >"$out"

rd() { if [ -r "$1" ]; then cat "$1"; else echo 0; fi; }
energy() { rd "$rapl/energy_uj" && rd "$rapl/intel-rapl:0:0/energy_uj" && rd "$rapl/intel-rapl:0:1/energy_uj"; }
max_range="$(rd "$rapl/max_energy_range_uj")"

mapfile -t e0 < <(energy)
t0="$(date +%s.%N)"
end=$((SECONDS + duration))
echo "Registro $out per ${duration}s..."
while [ "$SECONDS" -lt "$end" ]; do
  sleep "$interval"
  mapfile -t e1 < <(energy)
  t1="$(date +%s.%N)"
  batt_uw="$(rd "$bat/power_now")"
  temp="$(rd /sys/class/thermal/thermal_zone0/temp)"
  freq="$(rd /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)"
  bl="$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -n1 || echo 0)"
  awk -v t0="$t0" -v t1="$t1" -v max="$max_range" \
    -v p0="${e0[0]}" -v p1="${e1[0]}" -v c0="${e0[1]}" -v c1="${e1[1]}" -v g0="${e0[2]}" -v g1="${e1[2]}" \
    -v bw="$batt_uw" -v temp="$temp" -v freq="$freq" -v bl="$bl" '
    function d(a, b) { x = b - a; if (x < 0) x += max; return x }
    BEGIN {
      dt = t1 - t0
      pkg = d(p0, p1) / dt / 1e6; core = d(c0, c1) / dt / 1e6; gfx = d(g0, g1) / dt / 1e6
      batt = bw / 1e6; rest = (batt > 0) ? batt - pkg : 0
      printf "%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.1f,%d,%s\n", t1, batt, pkg, core, gfx, rest, temp / 1000, freq / 1000, bl
    }' | tee -a "$out"
  e0=("${e1[@]}")
  t0="$t1"
done
chown "$(stat -c %u:%g "${LAB_DIR:-$HOME/lab}")" "$out" 2>/dev/null || true
echo "Fatto: $out"
