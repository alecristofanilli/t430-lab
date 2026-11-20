# Strumenti di studio e ricerca disponibili a livello di sistema.
# Gli stack di calcolo (Python, Julia, R) vivono nei devShells: vedi shells/default.nix.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # note e scrittura
    # (Zotero: su nixpkgs-unstable al momento dipende da un Firefox ESR marcato insecure,
    #  quindi passa da Flatpak: `flatpak install flathub org.zotero.Zotero`)
    obsidian
    typst
    tinymist
    pandoc
    texliveMedium
    # lettura e visualizzazione
    zathura
    imv
    mpv
    graphviz
    gnuplot
  ];

  # Ogni cartella di progetto attiva da sola il suo ambiente (file .envrc con `use flake`)
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  services.flatpak.enable = true;
  systemd.services.flatpak-flathub = {
    description = "Aggiunge il remote Flathub";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    serviceConfig.Type = "oneshot";
    script = "flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo";
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };
}
