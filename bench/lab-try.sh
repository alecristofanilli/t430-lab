# lab-try [minuti] — applica la configurazione del repo IN PROVA, con revert automatico.
#
# Dead man's switch: la nuova config viene attivata con `nixos-rebuild test` (non entra
# nel bootloader) e parte un timer che, allo scadere, riattiva la generazione di default.
# Se l'esperimento rompe rete, sessione o accesso dell'agente, la macchina torna da sola
# allo stato precedente. Se si blocca del tutto, basta un riavvio.
# Per tenere la modifica: `lab-keep`.

minutes="${1:-5}"
repo="${LAB_REPO:-$HOME/t430-lab}"

sudo systemctl stop lab-revert.timer 2>/dev/null || true
sudo systemctl reset-failed lab-revert.timer lab-revert.service 2>/dev/null || true

sudo nixos-rebuild test --flake "$repo#t430"

sudo systemd-run \
  --unit=lab-revert \
  --description="t430-lab: revert automatico della configurazione in prova" \
  --on-active="${minutes}m" \
  --timer-property=AccuracySec=1s \
  --collect \
  /nix/var/nix/profiles/system/bin/switch-to-configuration test

echo "Configurazione in prova ATTIVA. Revert automatico tra ${minutes} minuti."
echo "  lab-keep                         → la rendi permanente"
echo "  sudo systemctl start lab-revert  → revert immediato"
