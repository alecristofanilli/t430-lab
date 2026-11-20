# t430-lab

Un ThinkPad T430 trasformato in laboratorio: NixOS interamente dichiarativo, root effimera,
esperimenti di ottimizzazione misurati, e Claude come ricercatore residente con accesso completo.

```
flake.nix
├─ hosts/t430/        disko (GPT + LUKS2 + btrfs), hardware
├─ modules/           base · impermanence · desktop (sway) · home (home-manager)
│                     power (TLP, thinkfan) · performance · experiments · research · lab · agent
├─ pkgs/ + bench/     lab-snapshot · lab-compare · lab-try · lab-keep · lab-fs-diff
├─ shells/            datascience · julia · r · bench
├─ docs/              hardware e firmware, progetti di riferimento
├─ CLAUDE.md          metodo e backlog per Claude sulla macchina
└─ NOTEBOOK.md        diario degli esperimenti
```

## Cosa c'è dentro
- **Root effimera** ("erase your darlings"): a ogni avvio `/` riparte vuota. Sopravvive solo ciò che è
  dichiarato in `modules/impermanence.nix`, più `/home`, `/nix`, `/persist`. Niente "sporcizia" accumulata.
- **Disco**: LUKS2 → btrfs zstd con subvolumi, snapshot orari di `/home` (snapper), zram + swapfile.
- **Boot doppio**: GRUB installato sia per UEFI sia per BIOS legacy, così resta avviabile anche dopo un
  eventuale passaggio a coreboot con SeaBIOS.
- **Esperimenti come voci di GRUB**: `vanilla` (gruppo di controllo), `perf` (mitigazioni off + sched_ext
  scx_lavd), `battery` (massimo risparmio). Stesso sistema, una variabile cambiata.
- **Dead man's switch**: `lab-try` applica una config con revert automatico. Si può spingere senza paura.
- **Claude sulla macchina**: Claude Code installato, sudo senza password (macchina di test), turno notturno
  opzionale in cui porta avanti il backlog da solo.

## Prima dell'installazione
1. **BIOS Lenovo**: Startup → UEFI/Legacy Boot = *Both* (UEFI first) · Security → Secure Boot *off* (se presente)
   · Security → Virtualization: VT-x e VT-d *on*.
2. **Questa installazione cancella il disco.** Salva quello che serve.
3. Metti questo repo su GitHub (può essere privato, ma pubblico rende il clone dall'ISO più semplice:
   non contiene segreti).
4. Scarica l'ISO **minimal** di NixOS e scrivila su una chiavetta. Per l'installazione è più comodo un cavo Ethernet.

## Installazione

### Opzione A — la fa Claude (consigliata)
Avvia l'ISO, collegati in rete, poi:
```bash
sudo -i
NIXPKGS_ALLOW_UNFREE=1 nix --extra-experimental-features "nix-command flakes" run --impure nixpkgs#claude-code
```
Fai il login (Claude Code ti dà un link da aprire sul telefono o sul PC), poi digli:
> Clona github.com/<tuo-utente>/t430-lab e installa NixOS seguendo il README, sezione Opzione B.
> Il disco da usare è quello che ti indico dopo aver visto `lsblk`.

### Opzione B — a mano
```bash
sudo -i
nix-shell -p git
git clone https://github.com/<tuo-utente>/t430-lab /tmp/t430-lab && cd /tmp/t430-lab

lsblk   # se il disco non è /dev/sda, aggiorna `device` in hosts/t430/disko.nix

# 1. Partiziona, cifra e monta (chiede la passphrase LUKS)
nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest -- --mode destroy,format,mount --flake .#t430

# 2. Hardware reale della macchina (i filesystem li gestisce disko)
nixos-generate-config --no-filesystems --show-hardware-config > hosts/t430/hardware.nix

# 3. Password utente (con utenti immutabili e root effimera vive solo qui)
mkdir -p /mnt/persist/secrets && chmod 700 /mnt/persist/secrets
mkpasswd -m yescrypt > /mnt/persist/secrets/alessandro.hash
chmod 600 /mnt/persist/secrets/alessandro.hash

# 4. Identità stabile della macchina
mkdir -p /mnt/persist/etc && tr -d '-' < /proc/sys/kernel/random/uuid > /mnt/persist/etc/machine-id

# 5. Installa
nixos-install --flake .#t430 --no-root-passwd

# 6. Il repo in home, per lavorarci dopo
mkdir -p /mnt/home/alessandro && cp -r /tmp/t430-lab /mnt/home/alessandro/
chown -R 1000:100 /mnt/home/alessandro

reboot
```

## Primo avvio
```bash
cd ~/t430-lab
git add -A && git commit -m "hardware.nix reale + flake.lock"   # fissa le versioni
lab-snapshot baseline
claude          # da qui in poi: "leggi CLAUDE.md e comincia dal backlog"
```

Per il turno notturno autonomo: in `hosts/t430/default.nix` aggiungi `lab.agent.nightly.enable = true;`.

## Comandi utili
| | |
|---|---|
| `rebuild` | applica il repo (alias di `nixos-rebuild switch`) |
| `lab-try 10` | prova una modifica con revert automatico tra 10 minuti |
| `lab-keep` | conferma la modifica |
| `sudo nixos-rebuild switch --rollback` | torna alla generazione precedente |
| `nix develop .#datascience` | Jupyter, numpy, pandas, scikit-learn... |
| `nix flake update` | aggiorna tutto (poi `lab-try`, misura, `lab-keep`) |

## Note
- Zotero passa da Flatpak (`flatpak install flathub org.zotero.Zotero`): su nixpkgs-unstable al momento dipende
  da un Firefox ESR segnalato come vulnerabile, e il repo non autorizza pacchetti insicuri.
- La config è stata verificata con `nix eval` (sistema completo e specialisations) contro nixpkgs-unstable di
  novembre 2026, e gli script con shellcheck. Non è ancora stata avviata su hardware reale: il primo boot
  è il primo esperimento.
