# "Erase your darlings": a ogni avvio il subvolume @root viene archiviato e ricreato vuoto.
# Tutto ciò che deve sopravvivere va dichiarato qui sotto (o vive in /home, /nix, /persist).
# Le root precedenti restano in old_roots/ per qualche giorno: utili per le autopsie
# (`lab-fs-diff` mostra cosa si è accumulato fuori dalla dichiarazione).
{ ... }:
{
  boot.initrd.systemd.services.rollback-root = {
    description = "Archivia la root btrfs e ne crea una vuota";
    wantedBy = [ "initrd.target" ];
    requires = [ "systemd-cryptsetup@cryptroot.service" ];
    after = [ "systemd-cryptsetup@cryptroot.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /btrfs_tmp
      mount -t btrfs -o subvol=/ /dev/mapper/cryptroot /btrfs_tmp

      if [ -e /btrfs_tmp/@root ]; then
        mkdir -p /btrfs_tmp/old_roots
        ts=$(date --date="@$(stat -c %Y /btrfs_tmp/@root)" "+%Y-%m-%d_%H-%M-%S")
        mv /btrfs_tmp/@root "/btrfs_tmp/old_roots/$ts"
      fi

      delete_subvolume_recursively() {
        IFS=$'\n'
        for sub in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
          delete_subvolume_recursively "/btrfs_tmp/$sub"
        done
        btrfs subvolume delete "$1"
      }

      # Tiene le ultime 10 root archiviate (i nomi sono timestamp, quindi ordinabili)
      for old in $(ls -1 /btrfs_tmp/old_roots | head -n -10); do
        delete_subvolume_recursively "/btrfs_tmp/old_roots/$old"
      done

      btrfs subvolume create /btrfs_tmp/@root
      umount /btrfs_tmp
    '';
  };

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/lib/nixos" # mappa uid/gid: indispensabile
      "/var/lib/systemd/coredump"
      "/var/lib/systemd/timers"
      "/var/lib/systemd/backlight"
      "/var/lib/bluetooth"
      "/var/lib/flatpak"
      "/var/lib/containers"
      "/var/lib/upower"
      "/var/lib/tlp"
      "/etc/NetworkManager/system-connections"
      {
        directory = "/var/lib/private";
        mode = "0700";
      }
    ];
    files = [ "/etc/machine-id" ];
  };

  # Chiavi host SSH generate e tenute direttamente in /persist (identità stabile della macchina)
  services.openssh.hostKeys = [
    {
      path = "/persist/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];

  # Niente "lezioncina" di sudo a ogni boot
  security.sudo.extraConfig = "Defaults lecture = never";
}
