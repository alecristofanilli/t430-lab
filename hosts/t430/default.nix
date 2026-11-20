{ ... }:
{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../modules/base.nix
    ../../modules/impermanence.nix
    ../../modules/desktop.nix
    ../../modules/home.nix
    ../../modules/power.nix
    ../../modules/performance.nix
    ../../modules/research.nix
    ../../modules/lab.nix
    ../../modules/agent.nix
    ../../modules/experiments.nix
    ../../modules/deep.nix
  ];

  networking.hostName = "t430";

  # Va impostato alla release dell'ISO usata per l'installazione e poi NON cambiato più.
  system.stateVersion = "26.05";
}
