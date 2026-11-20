# lab-ec-watch [intervallo_s] [durata_s] — registra ogni byte della RAM dell'embedded controller che cambia.
#
# L'EC del ThinkPad gestisce ventola, batteria, tastiera, LED, coperchio, temperature.
# Molti dei suoi registri non sono documentati: questo strumento li osserva mentre fai cose
# (chiudi il coperchio, stacchi l'alimentatore, premi Fn, lanci stress-ng) e salva un CSV
# timestamp,offset,prima,dopo,xor. Correlando eventi e cambiamenti si ricostruisce la mappa.
# Richiede la voce GRUB "deep" (modulo ec_sys). Sola lettura.

if [ "$(id -u)" -ne 0 ]; then exec sudo --preserve-env=LAB_DIR,HOME "$0" "$@"; fi

interval="${1:-0.5}"
duration="${2:-120}"
io=/sys/kernel/debug/ec/ec0/io

modprobe ec_sys 2>/dev/null || true
if [ ! -r "$io" ]; then
  echo "RAM dell'EC non accessibile: avvia la voce GRUB 'deep'." >&2
  exit 1
fi

outdir="${LAB_DIR:-$HOME/lab}/ec"
mkdir -p "$outdir"
out="$outdir/$(date +%Y%m%dT%H%M%S).csv"
echo "t,offset,old,new,xor" >"$out"

snap() { od -An -v -tu1 -w256 "$io" | tr -s ' '; }

read -ra prev <<<"$(snap)"
echo "Registro $out per ${duration}s (ogni ${interval}s). Fai le tue azioni e annotale."
end=$((SECONDS + duration))
while [ "$SECONDS" -lt "$end" ]; do
  sleep "$interval"
  read -ra cur <<<"$(snap)"
  now="$(date +%s.%N)"
  for i in "${!cur[@]}"; do
    if [ "${prev[$i]:-}" != "${cur[$i]}" ]; then
      line="$(printf '%s,0x%02x,%d,%d,0x%02x' "$now" "$i" "${prev[$i]:-0}" "${cur[$i]}" "$((${prev[$i]:-0} ^ cur[i]))")"
      echo "$line" >>"$out"
      echo "  $line"
    fi
  done
  prev=("${cur[@]}")
done
chown "$(stat -c %u:%g "${LAB_DIR:-$HOME/lab}")" "$out" 2>/dev/null || true
echo "Fatto: $(($(wc -l <"$out") - 1)) cambiamenti in $out"
