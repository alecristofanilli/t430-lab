# lab-limits — decodifica i limiti che governano prestazioni e overclock della CPU (sola lettura).
#
# Mostra: potenza nominale (TDP), limiti di potenza PL1/PL2 e se sono bloccati dal BIOS, moltiplicatori
# turbo e se sono programmabili (CPU XM sbloccate), temperatura massima (TjMax), stato di PROCHOT
# bidirezionale, turbo attivo, temperatura attuale. Con la voce GRUB "deep" legge anche il secondo
# limite di potenza in MMIO (MCHBAR), che su questi chipset può essere più restrittivo di quello MSR.
# È il primo passo prima di qualsiasi esperimento di overclock o di aumento dei limiti.

if [ "$(id -u)" -ne 0 ]; then exec sudo "$0" "$@"; fi
modprobe msr 2>/dev/null || true

msr() { local v; v="$(rdmsr -p0 -0 "$1" 2>/dev/null)" || return 1; echo $((16#$v)); }
bits() { echo $((($1 >> $2) & ((1 << ($3 - $2 + 1)) - 1))); } # bits valore basso alto

unit_raw="$(msr 0x606)" || {
  echo "MSR non leggibili (modulo msr?)" >&2
  exit 1
}
pu=$((1 << $(bits "$unit_raw" 0 3)))   # unità di potenza = 1/pu W
tu=$((1 << $(bits "$unit_raw" 16 19))) # unità di tempo = 1/tu s
watts() { awk -v r="$1" -v u="$pu" 'BEGIN { printf "%.2f W", r / u }'; }
window() {
  awk -v y="$1" -v z="$2" -v u="$tu" 'BEGIN { printf "%.2f s", (2 ^ y) * (1 + z / 4) / u }'
}
yes_no() { if [ "$1" -eq 1 ]; then echo "sì"; else echo "no"; fi; }

echo "== CPU"
grep -m1 "model name" /proc/cpuinfo | sed 's/.*: //'

if info="$(msr 0xce)"; then
  echo
  echo "== Piattaforma (MSR 0xCE)"
  echo "moltiplicatore base:            x$(bits "$info" 8 15)"
  echo "moltiplicatore minimo:          x$(bits "$info" 40 47)"
  echo "turbo programmabile (XM):       $(yes_no "$(bits "$info" 28 28)")"
  echo "limiti TDP programmabili:       $(yes_no "$(bits "$info" 29 29)")"
fi

if tr="$(msr 0x1ad)"; then
  echo
  echo "== Turbo (MSR 0x1AD)"
  echo "1 core: x$(bits "$tr" 0 7)   2 core: x$(bits "$tr" 8 15)   3 core: x$(bits "$tr" 16 23)   4 core: x$(bits "$tr" 24 31)"
fi
if me="$(msr 0x1a0)"; then
  echo "turbo disattivato dal firmware: $(yes_no "$(bits "$me" 38 38)")"
fi

if pi="$(msr 0x614)"; then
  echo
  echo "== Potenza (unità: 1/$pu W, 1/$tu s)"
  echo "TDP nominale (MSR 0x614):       $(watts "$(bits "$pi" 0 14)")"
fi
if pl="$(msr 0x610)"; then
  echo "PL1 (lungo periodo):            $(watts "$(bits "$pl" 0 14)")  attivo: $(yes_no "$(bits "$pl" 15 15)")  finestra: $(window "$(bits "$pl" 17 21)" "$(bits "$pl" 22 23)")"
  echo "PL2 (picco):                    $(watts "$(bits "$pl" 32 46)")  attivo: $(yes_no "$(bits "$pl" 47 47)")"
  echo "BLOCCATO dal BIOS (bit 63):     $(yes_no "$(bits "$pl" 63 63)")"
fi

if grep -q "iomem=relaxed" /proc/cmdline; then
  lo="$(setpci -s 00:00.0 48.l)"
  hi="$(setpci -s 00:00.0 4c.l)"
  mchbar=$(((16#$hi << 32 | 16#$lo) & ~0x7fff))
  if mm="$(dd if=/dev/mem bs=8 count=1 skip=$(((mchbar + 0x59a0) / 8)) 2>/dev/null | od -An -tx8 | tr -d ' ')" && [ -n "$mm" ]; then
    v=$((16#$mm))
    echo "PL1 MMIO (MCHBAR+0x59A0):       $(watts "$(bits "$v" 0 14)")  PL2 MMIO: $(watts "$(bits "$v" 32 46)")  bloccato: $(yes_no "$(bits "$v" 63 63)")"
  fi
else
  echo "(limiti MMIO: avvia la voce GRUB 'deep' per leggerli)"
fi

echo
echo "== Termica"
if tt="$(msr 0x1a2)"; then
  tjmax=$(bits "$tt" 16 23)
  echo "TjMax:                          ${tjmax} °C"
  if ts="$(msr 0x19c)"; then
    echo "temperatura core 0 ora:         $((tjmax - $(bits "$ts" 16 22))) °C"
    echo "throttling termico in corso:    $(yes_no "$(bits "$ts" 0 0)")   avvenuto dal boot: $(yes_no "$(bits "$ts" 1 1)")"
    echo "PROCHOT/forzato esterno ora:    $(yes_no "$(bits "$ts" 2 2)")"
  fi
fi
if pc="$(msr 0x1fc)"; then
  echo "PROCHOT bidirezionale:          $(yes_no "$(bits "$pc" 0 0)")"
fi

echo
echo "== Frequenze e alimentazione"
echo "governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)  driver: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null)"
for f in /sys/class/drm/card*/gt_RP0_freq_mhz; do
  if [ -r "$f" ]; then
    d="$(dirname "$f")"
    echo "GPU HD 4000: min $(cat "$d/gt_min_freq_mhz") / max $(cat "$d/gt_max_freq_mhz") MHz (hardware: RPn $(cat "$d/gt_RPn_freq_mhz") – RP0 $(cat "$d/gt_RP0_freq_mhz") MHz)"
    break
  fi
done
echo "alimentatore collegato: $(cat /sys/class/power_supply/AC/online 2>/dev/null || echo ?)  (per una CPU quad-core serve quello da 90 W)"
