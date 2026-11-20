# Gli strumenti del laboratorio. Installati dal modulo lab.nix, eseguibili anche con `nix run .#<nome>`.
{ pkgs }:
let
  mk =
    name: runtimeInputs:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = builtins.readFile (../bench + "/${name}.sh");
    };
in
{
  # Fotografia della macchina in JSON (consumi, temperature, CPU, mitigazioni, generazione)
  lab-snapshot = mk "lab-snapshot" (
    with pkgs;
    [
      coreutils
      gawk
      jq
      lm_sensors
      procps
      sysbench
      systemd
    ]
  );

  # Confronto tra due snapshot: lab-compare before.json after.json
  lab-compare = mk "lab-compare" (
    with pkgs;
    [
      coreutils
      jq
      util-linux
    ]
  );

  # Applica la config in prova con revert automatico (dead man's switch)
  lab-try = mk "lab-try" (with pkgs; [ coreutils ]);

  # Conferma la config in prova e la rende la generazione di default
  lab-keep = mk "lab-keep" (with pkgs; [ coreutils ]);

  # Cosa si è accumulato nella root effimera dall'ultimo avvio (stato non dichiarato)
  lab-fs-diff = mk "lab-fs-diff" (
    with pkgs;
    [
      coreutils
      findutils
      gnugrep
      gnused
      util-linux
    ]
  );
}
