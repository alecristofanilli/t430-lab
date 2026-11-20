# Dotfile dichiarativi con home-manager (shell, terminale, strumenti CLI).
{ pkgs, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";

    users.alessandro = {
      home.stateVersion = "26.05";

      home.packages = with pkgs; [
        eza
        bat
        fzf
        zoxide
        dust
        duf
        tldr
      ];

      programs.zsh = {
        enable = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        history = {
          size = 100000;
          save = 100000;
          share = true;
        };
        shellAliases = {
          ls = "eza --group-directories-first";
          ll = "eza -la --git --group-directories-first";
          cat = "bat --paging=never";
          rebuild = "sudo nixos-rebuild switch --flake ~/t430-lab#t430";
          gens = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
          lab = "cd ~/t430-lab";
        };
      };

      programs.starship = {
        enable = true;
        settings = {
          add_newline = false;
          nix_shell.format = "[❄ $name]($style) ";
          battery.display = [
            {
              threshold = 30;
              style = "bold red";
            }
          ];
        };
      };

      programs.zoxide.enable = true;
      programs.fzf.enable = true;

      programs.git = {
        enable = true;
        settings = {
          user.name = "Alessandro";
          init.defaultBranch = "main";
          pull.rebase = true;
        };
      };

      programs.foot = {
        enable = true;
        settings = {
          main = {
            font = "JetBrainsMono Nerd Font:size=10";
            pad = "6x6";
          };
          mouse.hide-when-typing = "yes";
        };
      };

      programs.btop = {
        enable = true;
        settings.update_ms = 1000;
      };
    };
  };
}
