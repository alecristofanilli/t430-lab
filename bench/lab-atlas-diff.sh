# lab-atlas-diff <atlas-A> <atlas-B> — cosa è cambiato tra due fotografie della macchina.
#
# Testi: diff unificato (esclusi i file "rumorosi" come dmesg). Binari (flash SPI, RAM
# dell'EC, SMBIOS): elenco dei singoli byte diversi con valore prima/dopo, e i bit cambiati.

if [ "$#" -ne 2 ]; then
  echo "uso: lab-atlas-diff atlasA atlasB" >&2
  exit 1
fi
a="$1"
b="$2"

echo "### file presenti solo in uno dei due"
diff <(cd "$a" && find . -type f | sort) <(cd "$b" && find . -type f | sort) || true

echo
echo "### differenze testuali"
diff -ru --exclude='dmesg.txt' --exclude='*.bin' --exclude='*.dat' --exclude='MANIFEST.sha256' \
  --exclude='*.err' --exclude='sysctl.txt' "$a" "$b" || true

echo
echo "### differenze binarie (offset: prima → dopo | bit cambiati)"
while IFS= read -r -d '' f; do
  rel="${f#"$a"/}"
  if [ -f "$b/$rel" ] && ! cmp -s "$f" "$b/$rel"; then
    echo "-- $rel"
    cmp -l "$f" "$b/$rel" 2>/dev/null | head -n 512 | while read -r off va vb; do
      x=$((8#$va))
      y=$((8#$vb))
      printf '  0x%06x: 0x%02x → 0x%02x | xor 0x%02x\n' "$((off - 1))" "$x" "$y" "$((x ^ y))"
    done
  fi
done < <(find "$a" -type f -name '*.bin' -print0)
