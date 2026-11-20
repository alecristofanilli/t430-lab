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

  # Fotografia completa fino ai registri (SMBIOS, MSR, PCI, ACPI, EC, SPD, flash SPI in "deep").
  # Gli strumenti specifici (dmidecode, rdmsr, flashrom, chipsec, ...) li installa modules/deep.nix.
  lab-atlas = mk "lab-atlas" (
    with pkgs;
    [
      coreutils
      findutils
      gnugrep
      util-linux
      kmod
      procps
      pciutils
      usbutils
      xxd
    ]
  );

  # Confronto tra due atlas, binari compresi (byte e bit cambiati)
  lab-atlas-diff = mk "lab-atlas-diff" (
    with pkgs;
    [
      coreutils
      diffutils
      findutils
    ]
  );

  # Osserva la RAM dell'embedded controller e registra ogni byte che cambia
  lab-ec-watch = mk "lab-ec-watch" (
    with pkgs;
    [
      coreutils
      kmod
    ]
  );

  # Traccia di consumo: batteria + RAPL (package, core, GPU) + resto stimato
  lab-power-trace = mk "lab-power-trace" (
    with pkgs;
    [
      coreutils
      gawk
    ]
  );

  # Limiti di potenza, moltiplicatori turbo, lock del BIOS, TjMax, PROCHOT: la base dell'overclock
  lab-limits = mk "lab-limits" (
    with pkgs;
    [
      coreutils
      gawk
      gnugrep
      gnused
      kmod
      msr-tools
      pciutils
    ]
  );

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
