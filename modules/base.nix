{ pkgs, ... }:
{
  # --- Boot -----------------------------------------------------------------
  # GRUB con doppio target: UEFI (BIOS Lenovo) + BIOS legacy (via partizione EF02,
  # che disko collega da solo a boot.loader.grub.devices). Il portatile resta avviabile
  # anche dopo un eventuale passaggio a coreboot con payload SeaBIOS.
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true; # niente scritture in NVRAM, più robusto
    configurationLimit = 30; # generazioni selezionabili all'avvio
  };
  boot.loader.efi.canTouchEfiVariables = false;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.tmp.useTmpfs = true;

  # --- Nix ------------------------------------------------------------------
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    trusted-users = [
      "root"
      "@wheel"
    ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nixpkgs.config.allowUnfree = true;

  # Binari precompilati "non Nix" (tool scaricati, VS Code server, ...)
  programs.nix-ld.enable = true;

  # --- Localizzazione -------------------------------------------------------
  time.timeZone = "Europe/Rome";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "it_IT.UTF-8";
    LC_NUMERIC = "it_IT.UTF-8";
    LC_MONETARY = "it_IT.UTF-8";
    LC_PAPER = "it_IT.UTF-8";
    LC_MEASUREMENT = "it_IT.UTF-8";
  };
  console.keyMap = "it";

  # --- Rete e sicurezza -----------------------------------------------------
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;
  networking.firewall.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # --- Utente ---------------------------------------------------------------
  # Con la root effimera /etc/shadow si rigenera a ogni boot: utenti e password sono
  # SOLO dichiarativi. L'hash della password vive in /persist (creato in installazione,
  # vedi README) e non finisce mai nel repo.
  users.mutableUsers = false;
  users.users.alessandro = {
    hashedPasswordFile = "/persist/secrets/alessandro.hash";
    isNormalUser = true;
    description = "Alessandro";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
    shell = pkgs.zsh;
    # openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA... alessandro@pc" ];
  };
  programs.zsh.enable = true;

  # --- Memoria e filesystem -------------------------------------------------
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };

  services.snapper.configs.home = {
    SUBVOLUME = "/home";
    ALLOW_USERS = [ "alessandro" ];
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_LIMIT_HOURLY = 24;
    TIMELINE_LIMIT_DAILY = 7;
    TIMELINE_LIMIT_WEEKLY = 4;
    TIMELINE_LIMIT_MONTHLY = 0;
    TIMELINE_LIMIT_YEARLY = 0;
  };

  services.fstrim.enable = true;
  services.smartd.enable = true;

  # --- Strumenti di base ----------------------------------------------------
  environment.systemPackages = with pkgs; [
    git
    neovim
    tmux
    curl
    wget
    ripgrep
    fd
    jq
    btop
    htop
    tree
    unzip
    pciutils
    usbutils
    lshw
    dmidecode
    smartmontools
    lm_sensors
    nvd # diff tra generazioni: `nvd diff /run/booted-system /run/current-system`
  ];
}
