# lab-fs-diff — elenca i file scritti nella root effimera dall'ultimo avvio.
#
# La root (@root) viene ricreata vuota a ogni boot: ogni file regolare che ci trovi
# dentro è stato scritto dopo l'avvio e SPARIRÀ al prossimo riavvio. Serve a capire
# cosa un programma salva e se va aggiunto a environment.persistence.

top="$(mktemp -d)"
cleanup() {
  sudo umount "$top" 2>/dev/null || true
  rmdir "$top"
}
trap cleanup EXIT

sudo mount -t btrfs -o subvol=/,ro /dev/mapper/cryptroot "$top"

sudo find "$top/@root" -xdev -type f \
  -not -path "$top/@root/tmp/*" \
  -not -path "$top/@root/etc/static/*" \
  -not -path "$top/@root/nix/*" \
  2>/dev/null |
  sed "s|^$top/@root||" |
  { grep -vxE '/etc/(passwd|group|shadow|subuid|subgid|sudoers|\.clean|\.updated|NIXOS)' || true; } |
  sort
