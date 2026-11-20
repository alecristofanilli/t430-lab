# La scatola nera: sempre attiva, si apre da sola su stalli (PSI) e throttling. Vedi bench/lab-blackbox.py.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lab.blackbox;
in
{
  options.lab.blackbox = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Scatola nera del laboratorio (campionamento continuo + aperture automatiche).";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "alessandro";
      description = "Utente nella cui ~/lab/blackbox finiscono le registrazioni.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.lab-blackbox = {
      description = "t430-lab: scatola nera (PSI, throttling, processi)";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      path = [ config.systemd.package ]; # journalctl per il log del kernel
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 ${../bench/lab-blackbox.py} --dir /home/${cfg.user}/lab/blackbox --owner ${cfg.user}";
        Restart = "always";
        RestartSec = 5;
        # deve riuscire a girare proprio quando la macchina è sotto stress
        Nice = -5;
        MemoryMax = "96M";
        ProtectSystem = "strict";
        ReadWritePaths = [ "/home/${cfg.user}/lab" ];
        PrivateTmp = true;
      };
    };

    # Le cartelle devono esistere prima che systemd monti ReadWritePaths (preStart sarebbe troppo tardi)
    systemd.tmpfiles.rules = [
      "d /home/${cfg.user}/lab 0755 ${cfg.user} users -"
      "d /home/${cfg.user}/lab/blackbox 0755 ${cfg.user} users -"
    ];

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "lab-blackbox-dump" ''
        sudo systemctl kill -s USR1 lab-blackbox && echo "Scatola nera aperta: ~/lab/blackbox/"
      '')
    ];
  };
}
