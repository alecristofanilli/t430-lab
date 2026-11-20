# lab-keep — conferma la configurazione in prova: ferma il revert e la rende la generazione di default.

repo="${LAB_REPO:-$HOME/t430-lab}"

if sudo systemctl stop lab-revert.timer 2>/dev/null; then
  echo "Revert automatico annullato."
fi
sudo nixos-rebuild switch --flake "$repo#t430"
echo "Configurazione resa permanente (nuova generazione di default)."
