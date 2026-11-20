# Tuning di sistema. Tutto dietro `lab.tuning.enable`, così la specialisation "vanilla"
# (gruppo di controllo) può spegnerlo e confrontare i numeri con lab-snapshot.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lab.tuning;
in
{
  options.lab.tuning.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Applica il tuning di sistema del laboratorio (disattivato nella specialisation vanilla).";
  };

  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl = {
      # zram come swap principale: swap aggressivo verso RAM compressa, niente read-ahead
      "vm.swappiness" = 180;
      "vm.page-cluster" = 0;
      "vm.watermark_boost_factor" = 0;
      "vm.watermark_scale_factor" = 125;
      # meno risvegli inutili
      "kernel.nmi_watchdog" = 0;
      # writeback più regolare su SSD SATA
      "vm.dirty_bytes" = 268435456;
      "vm.dirty_background_bytes" = 67108864;
    };

    # Priorità automatiche dei processi (regole CachyOS): desktop reattivo sotto carico
    services.ananicy = {
      enable = true;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-rules-cachyos;
    };

    # Pacchetti scaricati in parallelo e build che non saturano due core e mezzo
    nix.settings = {
      max-jobs = 2;
      cores = 2;
      http-connections = 50;
    };
    nix.daemonCPUSchedPolicy = "idle";
    nix.daemonIOSchedClass = "idle";
  };
}
