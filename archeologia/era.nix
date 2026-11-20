# Un sistema NixOS "di un'altra epoca", avviabile in RAM sul T430 (filone 11 del programma di ricerca).
#
# Verificato il 2026-11-20: con il Nix del 2026 questa espressione valuta nixpkgs release-17.09
# (kernel 4.9.86) in circa un secondo e mezzo:
#
#   git clone --depth 1 -b release-17.09 https://github.com/NixOS/nixpkgs /tmp/nixpkgs-1709
#   nix-instantiate --eval --strict --json archeologia/era.nix --argstr nixpkgs /tmp/nixpkgs-1709 -A info
#
# Il sistema è un'immagine netboot: kernel + initrd che contiene tutto in RAM (squashfs). Si avvia
# dal sistema del laboratorio con kexec, senza toccare il disco. Una NixOS del 2017 non sa aprire
# LUKS2, quindi i risultati si scrivono sulla partizione EFI (vfat, leggibile da qualsiasi kernel).
#
# Da qui in poi è lavoro per Claude sul T430: aggiungere il modulo di benchmark (benchModule), verificare
# che i binari dell'epoca siano ancora su cache.nixos.org (altrimenti: build da sorgente su un builder
# remoto, sorgenti da tarballs.nixos.org) e scrivere lo script kexec.
{
  nixpkgs, # percorso (stringa) di un checkout di nixpkgs di una certa epoca
  benchModule ? { }, # modulo con i benchmark da eseguire all'avvio
}:
let
  root = /. + nixpkgs;
  sys = import (root + "/nixos") {
    system = "x86_64-linux";
    configuration =
      { ... }:
      {
        imports = [
          (root + "/nixos/modules/installer/netboot/netboot-minimal.nix")
          benchModule
        ];
      };
  };
in
{
  inherit sys;
  kernel = sys.config.system.build.kernel;
  ramdisk = sys.config.system.build.netbootRamdisk;
  info = {
    kernel = sys.config.boot.kernelPackages.kernel.version;
    nixos = sys.config.system.nixos.version or sys.config.system.nixosVersion or "?";
    kernelDrv = sys.config.system.build.kernel.drvPath;
    ramdiskDrv = sys.config.system.build.netbootRamdisk.drvPath;
  };
}
