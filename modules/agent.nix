# Claude come "ricercatore residente" sulla macchina.
#
# - Claude Code installato a livello di sistema, sudo senza password per l'utente:
#   è una macchina di test e l'agente deve poter ricostruire il sistema da solo.
# - La rete di sicurezza non è il permesso, è il rollback: `lab-try` applica una
#   configurazione in prova con revert automatico, e GRUB conserva 30 generazioni.
# - Opzionale: un turno notturno in cui Claude porta avanti da solo il backlog di CLAUDE.md.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lab.agent;
in
{
  options.lab.agent.nightly = {
    enable = lib.mkEnableOption "turno notturno autonomo di Claude sul backlog di ricerca";
    time = lib.mkOption {
      type = lib.types.str;
      default = "03:00";
      description = "Orario di avvio (formato OnCalendar di systemd).";
    };
  };

  config = lib.mkMerge [
    {
      environment.systemPackages = [ pkgs.claude-code ];
      security.sudo.wheelNeedsPassword = false;
    }

    (lib.mkIf cfg.nightly.enable {
      systemd.services.lab-nightly = {
        description = "Claude: turno notturno sul backlog di t430-lab";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          User = "alessandro";
          WorkingDirectory = "/home/alessandro/t430-lab";
          TimeoutStartSec = "3h";
          Nice = 10;
        };
        environment.PATH = lib.mkForce "/run/wrappers/bin:/run/current-system/sw/bin";
        script = ''
          claude -p --dangerously-skip-permissions \
            "Turno notturno. Leggi CLAUDE.md e NOTEBOOK.md. Scegli UN esperimento dal backlog,
             misura la baseline, applicalo SOLO con lab-try, rimisura, decidi tenere/revertire,
             annota tutto in NOTEBOOK.md e fai commit. Mai toccare disco, LUKS o firmware." \
            > "/home/alessandro/lab/nightly-$(date +%Y%m%d).log" 2>&1
        '';
      };
      systemd.timers.lab-nightly = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.nightly.time;
          Persistent = false;
        };
      };
    })
  ];
}
