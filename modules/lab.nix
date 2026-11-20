# Il "laboratorio": strumenti per misurare la macchina prima e dopo ogni modifica.
{ pkgs, ... }:
let
  labPkgs = import ../pkgs { inherit pkgs; };
in
{
  environment.systemPackages =
    (builtins.attrValues labPkgs)
    ++ (with pkgs; [
      powertop
      hyperfine
      stress-ng
      s-tui
      fio
      sysbench
      glmark2
      perf
      bpftrace
      bcc
      iotop-c
      nvtopPackages.intel
    ]);

  # bpftrace/perf utilizzabili senza root e simboli del kernel visibili
  boot.kernel.sysctl = {
    "kernel.perf_event_paranoid" = 1;
    "kernel.kptr_restrict" = 0;
  };
}
