# lab-atlas [etichetta] — fotografia completa della macchina fino al livello dei registri.
#
# Crea ~/lab/atlas/<data>-<etichetta>/ con: SMBIOS, CPUID grezzo, MSR, spazio di configurazione
# PCI completo, tabelle ACPI disassemblate, RAM dell'EC, EDID, SPD della DRAM, sensori, RAPL,
# kernel. Nella voce di GRUB "deep" anche: dump della flash SPI (sola lettura), registri del
# chipset (inteltool), stato dell'Intel ME e audit chipsec.
#
# Due atlas si confrontano con `lab-atlas-diff`: a corrente vs batteria, riposo vs carico,
# BIOS Lenovo vs coreboot. Ogni bit che cambia è un indizio.

if [ "$(id -u)" -ne 0 ]; then exec sudo --preserve-env=LAB_DIR,HOME "$0" "$@"; fi

label="${1:-manual}"
root="${LAB_DIR:-$HOME/lab}/atlas/$(date +%Y%m%dT%H%M%S)-$label"
mkdir -p "$root"
deep=0
grep -q "iomem=relaxed" /proc/cmdline && deep=1

# cap <file> <comando...>: esegue, salva l'output, non si ferma se lo strumento fallisce
cap() {
  local out="$root/$1"
  shift
  mkdir -p "$(dirname "$out")"
  if ! "$@" >"$out" 2>"$out.err"; then
    echo "  ! $1 → $(basename "$out") non completo (vedi .err)"
  fi
  if [ ! -s "$out.err" ]; then rm -f "$out.err"; fi
}

echo "== atlas: $root (deep=$deep)"

echo "-- sistema"
cap system/uname.txt uname -a
cap system/cmdline.txt cat /proc/cmdline
cap system/generation.txt readlink /nix/var/nix/profiles/system
cap system/booted-system.txt readlink /run/booted-system
cap system/lsmod.txt lsmod
cap system/dmesg.txt dmesg
cap system/sysctl.txt sysctl -a

echo "-- SMBIOS"
cap smbios/dmidecode.txt dmidecode
cap smbios/dump.log dmidecode --dump-bin "$root/smbios/smbios.bin"

echo "-- CPU e MSR"
cap cpu/lscpu.txt lscpu
cap cpu/cpuinfo.txt cat /proc/cpuinfo
cap cpu/cpuid-raw.txt cpuid -r
cap cpu/cpuid.txt cpuid -1
cap cpu/vulnerabilities.txt grep -r . /sys/devices/system/cpu/vulnerabilities/
cap cpu/spectre-meltdown-checker.txt spectre-meltdown-checker --no-color --batch text
{
  # Registri modello-specifici rilevanti per Ivy Bridge (valori per ogni CPU logica)
  for msr in 0x3a 0xce 0xe2 0x198 0x199 0x19a 0x19b 0x19c 0x1a0 0x1a2 0x1aa 0x1b0 0x1b1 0x1fc \
    0x606 0x610 0x611 0x614 0x638 0x639 0x640 0x641 0x60a 0x60b 0x60c 0x48 0x10a; do
    printf '%s:' "$msr"
    rdmsr -a -0 "$msr" 2>/dev/null | tr '\n' ' ' || printf ' n/d'
    echo
  done
} >"$root/cpu/msr.txt"

echo "-- PCI"
cap pci/lspci-tree.txt lspci -tvnn
cap pci/lspci-verbose.txt lspci -nnvvv
cap pci/config-space.txt lspci -xxxx # 4 KiB di spazio di configurazione per dispositivo

echo "-- ACPI"
mkdir -p "$root/acpi"
if acpidump -o "$root/acpi/tables.dat" 2>"$root/acpi/acpidump.err"; then
  (cd "$root/acpi" && acpixtract -a tables.dat >/dev/null 2>&1 && iasl -d ./*.dat >iasl.log 2>&1) || true
  rm -f "$root/acpi/acpidump.err"
fi

echo "-- Embedded controller"
modprobe ec_sys 2>/dev/null || true
mkdir -p "$root/ec"
if [ -r /sys/kernel/debug/ec/ec0/io ] && cp /sys/kernel/debug/ec/ec0/io "$root/ec/ram.bin"; then
  cap ec/ram.hex xxd "$root/ec/ram.bin"
fi
cap ec/thinkpad-acpi.txt grep -r . /proc/acpi/ibm/

echo "-- Grafica e schermo"
for edid in /sys/class/drm/*/edid; do
  if [ -s "$edid" ]; then
    name="$(basename "$(dirname "$edid")")"
    cap "display/$name-edid.txt" edid-decode "$edid"
  fi
done
cap display/i915-info.txt cat /sys/kernel/debug/dri/0/i915_capabilities

echo "-- DRAM (SPD)"
modprobe i2c-i801 2>/dev/null || true
modprobe at24 2>/dev/null || true
cap dram/i2cdetect.txt i2cdetect -l
cap dram/decode-dimms.txt decode-dimms
cap dram/meminfo.txt cat /proc/meminfo

echo "-- Storage e USB"
cap storage/lsblk.json lsblk -O --json
for disk in /dev/sd?; do
  if [ -b "$disk" ]; then cap "storage/smart-$(basename "$disk").txt" smartctl -x "$disk"; fi
done
cap usb/lsusb.txt lsusb -v

echo "-- Sensori, energia, RAPL"
cap sensors/sensors.json sensors -j
cap power/battery.txt cat /sys/class/power_supply/BAT0/uevent
cap power/rapl.txt grep -r . /sys/class/powercap/intel-rapl/
cap power/turbostat.txt turbostat --quiet --num_iterations 1 --interval 5
cap power/cpupower.txt cpupower frequency-info

if [ "$deep" -eq 1 ]; then
  echo "-- firmware (deep)"
  cap firmware/flashrom.log flashrom -p internal -r "$root/firmware/spi-flash.bin"
  if [ -s "$root/firmware/spi-flash.bin" ]; then
    cap firmware/ifdtool.txt ifdtool -d "$root/firmware/spi-flash.bin"
    cap firmware/me_cleaner-check.txt me_cleaner -c "$root/firmware/spi-flash.bin"
  fi
  cap firmware/intelmetool.txt intelmetool -m -s
  cap firmware/inteltool.txt inteltool -a
  cap firmware/superiotool.txt superiotool -deV
  cap firmware/chipsec.txt chipsec_main --helper linuxnative --no-banner
else
  echo "-- firmware: saltato (avvia la voce GRUB 'deep' per flash SPI, chipset, ME e chipsec)"
fi

echo "-- manifest"
manifest="$(mktemp)"
(cd "$root" && find . -type f -print0 | sort -z | xargs -0 sha256sum) >"$manifest"
mv "$manifest" "$root/MANIFEST.sha256" && chmod 644 "$root/MANIFEST.sha256"
chown -R "$(stat -c %u:%g "${LAB_DIR:-$HOME/lab}")" "$root" 2>/dev/null || true

echo "Atlas completo: $root ($(du -sh "$root" | cut -f1))"
