# Layout del disco come codice. ATTENZIONE: applicarlo CANCELLA il disco indicato.
#
#   GPT
#   ├─ BIOS boot (1M)   → permette l'avvio anche in legacy/SeaBIOS (es. futuro coreboot "Skulls")
#   ├─ ESP (1G, vfat)   → /boot, avvio UEFI col BIOS Lenovo
#   └─ LUKS2 "cryptroot"
#      └─ btrfs (zstd)
#         ├─ @root            /                (in futuro: azzerato a ogni boot, "impermanence")
#         ├─ @root-blank      snapshot vuoto di riferimento, creato a mano dopo l'installazione
#         ├─ @nix             /nix
#         ├─ @home            /home
#         ├─ @home-snapshots  /home/.snapshots (snapper)
#         ├─ @persist         /persist         (ciò che dovrà sopravvivere all'impermanence)
#         ├─ @log             /var/log
#         └─ @swap            /swap            (swapfile, oltre a zram)
{ lib, ... }:
let
  opts = [
    "compress=zstd"
    "noatime"
  ];
in
{
  disko.devices.disk.main = {
    type = "disk";
    # Verificare con `lsblk` prima di installare (con un mSATA aggiuntivo potrebbe cambiare).
    device = lib.mkDefault "/dev/sda";
    content = {
      type = "gpt";
      partitions = {
        bios = {
          size = "1M";
          type = "EF02";
        };
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            # Nessun passwordFile: disko chiede la passphrase in modo interattivo.
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [
                "-f"
                "-L"
                "nixos"
              ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = opts;
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = opts;
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = opts;
                };
                "@home-snapshots" = {
                  mountpoint = "/home/.snapshots";
                  mountOptions = opts;
                };
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = opts;
                };
                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = opts;
                };
                "@swap" = {
                  mountpoint = "/swap";
                  swap.swapfile.size = "4G";
                };
              };
            };
          };
        };
      };
    };
  };

  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var/log".neededForBoot = true;
}
