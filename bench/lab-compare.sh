# lab-compare A.json B.json — confronta due misure di lab-snapshot.
#
# Esempio: lab-compare ~/lab/results/*-baseline.json ~/lab/results/*-perf.json

if [ "$#" -ne 2 ]; then
  echo "uso: lab-compare prima.json dopo.json" >&2
  exit 1
fi

jq -n -r --slurpfile a "$1" --slurpfile b "$2" '
  def pct(x; y): if (x | type) == "number" and (y | type) == "number" and x != 0
                 then ((y - x) / x * 100 * 10 | round / 10 | tostring) + "%"
                 else "-" end;
  def row(name; x; y): "\(name)\t\(x // "-")\t\(y // "-")\t\(pct(x; y))";
  $a[0] as $A | $b[0] as $B |
  "metrica\t\($A.label)\t\($B.label)\tdelta",
  row("generazione"; $A.nixos_generation; $B.nixos_generation),
  row("kernel"; $A.kernel; $B.kernel),
  row("governor"; $A.governor; $B.governor),
  row("boot"; $A.boot_time; $B.boot_time),
  row("consumo (W)"; $A.power.draw_watts; $B.power.draw_watts),
  row("CPU (ev/s)"; $A.cpu_sysbench_events_per_s; $B.cpu_sysbench_events_per_s),
  row("RAM usata (MiB)"; $A.memory_used_mib; $B.memory_used_mib),
  row("ventola (rpm)"; $A.fan_rpm; $B.fan_rpm),
  row("cmdline"; $A.cmdline; $B.cmdline)
' | column -t -s "$(printf '\t')"
