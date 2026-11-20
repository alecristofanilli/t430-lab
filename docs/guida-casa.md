# T430-lab — Guida per l'installazione a casa

Aggiornata al 2026-11-20.

## Prima di iniziare

Servono 1–2 ore, quasi tutte di attesa: l'installazione la fa Claude Code direttamente sul T430, tu prepari la chiavetta, scrivi le password e confermi il disco. Tutto il progetto è nel repository **[github.com/alecristofanilli/t430-lab](https://github.com/alecristofanilli/t430-lab)**: questa guida non dipende da nessuna chat.

| Cosa | Perché |
| --- | --- |
| Chiavetta USB da almeno 4 GB | Ci va l'installer di NixOS; il contenuto attuale viene cancellato |
| Cavo Ethernet collegato al router | L'installazione scarica diversi GB; il Wi-Fi dalla riga di comando è più scomodo |
| PC Windows con PowerShell | Da lì comandi il T430 via SSH, con copia-incolla |
| Account Claude e account GitHub | Claude Code chiede il login; GitHub serve per salvare il lavoro |
| Alimentatore da 90 W (consigliato) | Con quello da 65 W la CPU va in throttling sotto carico e le misure risultano falsate |

**Il disco del T430 viene cancellato completamente, Windows compreso.** Salva prima tutto quello che ti serve.

**Decidi le due password prima di cominciare e scrivile in un posto sicuro:**

- **passphrase del disco (LUKS):** la digiti a ogni accensione. Se la perdi, i dati non si recuperano in nessun modo. Usa solo lettere e numeri, niente simboli: all'avvio la tastiera potrebbe non essere ancora in italiano.
- **password dell'utente `alessandro`:** per il login e per lo sblocco dello schermo.

## Fase 1 — Sul PC Windows: la chiavetta

La chiavetta deve contenere l'ISO **Minimal** di NixOS scritta in **modalità DD**: è l'errore più comune, e con la modalità ISO spesso il T430 non la avvia.

1. Su [nixos.org/download](https://nixos.org/download) scegli **NixOS → Minimal ISO image**, versione a 64 bit (Intel/AMD).
2. Scarica [Rufus](https://rufus.ie) e avvialo; inserisci la chiavetta.
3. In Rufus seleziona la chiavetta e l'ISO appena scaricata, poi **Avvia**.
4. Quando Rufus chiede come scrivere l'immagine, scegli **"Scrivi in modalità immagine DD"** e conferma la cancellazione.
5. Apri [github.com/alecristofanilli/t430-lab](https://github.com/alecristofanilli/t430-lab) e controlla che il repository si veda: il T430 lo scaricherà da lì.

## Fase 2 — Sul T430: BIOS e avvio della live

Alla fine di questa fase il T430 è acceso sulla chiavetta, collegato in rete e raggiungibile via SSH dal PC.

1. Accendi il T430 e premi **F1** per entrare nel BIOS. Imposta:
   - **Startup → UEFI/Legacy Boot:** Both, con **UEFI/Legacy Boot Priority:** UEFI First
   - **Security → Virtualization:** Intel VT-x e Intel VT-d su Enabled
   - **Security → Secure Boot:** Disabled, se la voce esiste
   - salva ed esci con **F10**
2. Collega il cavo Ethernet, inserisci la chiavetta, accendi e premi **F12**: dal menu scegli la chiavetta (se compare due volte, la voce UEFI).
3. Arrivi a un prompt di testo (`nixos@nixos`). Scrivi:

```
sudo loadkeys it
passwd
sudo systemctl start sshd
ip -4 a
```

- `loadkeys it` mette la tastiera in italiano.
- `passwd` imposta una password temporanea per l'utente `nixos`: serve solo per entrare via SSH dalla live, poi sparisce.
- `ip -4 a` mostra l'indirizzo IP: cerca la riga `inet` sotto la scheda Ethernet (di solito `enp0s25`), per esempio `192.168.1.42`. Annotalo.

Senza cavo Ethernet: vedi "Se qualcosa va storto" per collegare il Wi-Fi dalla live.

## Fase 3 — Dal PC: Claude Code installa il sistema

Da qui lavori dal PC Windows e il T430 resta acceso sulla scrivania. Claude Code gira sulla live del T430 e segue il README del repository; tu confermi il disco e scrivi le password.

1. Apri PowerShell e collegati (usa l'IP annotato, rispondi `yes` alla prima domanda e inserisci la password temporanea):

```
ssh nixos@192.168.1.42
```

2. Diventa root e avvia Claude Code (il primo avvio scarica qualche centinaio di MB):

```
sudo -i
NIXPKGS_ALLOW_UNFREE=1 nix --extra-experimental-features "nix-command flakes" run --impure nixpkgs#claude-code
```

3. Per il login, Claude Code mostra un link: aprilo nel browser del PC, accedi e incolla nel terminale il codice che ti dà.
4. Incolla questo messaggio:

```
Sei sulla live di NixOS del mio ThinkPad T430. Clona https://github.com/alecristofanilli/t430-lab e installa il sistema seguendo il README, Opzione B. Prima di partizionare mostrami lsblk e aspetta la mia conferma sul disco. Quando serve la passphrase LUKS o la password utente, fermati e lascia che le scriva io. Se il build fallisce per un pacchetto o un'opzione cambiati in nixpkgs, correggi il file .nix, spiegami cosa hai cambiato e continua.
```

5. Durante l'installazione:
   - **conferma del disco:** Claude ti mostra `lsblk`; il disco giusto è l'SSD interno, di solito `/dev/sda` (controlla la dimensione). Una chiavetta da 4–32 GB non è il disco giusto.
   - **passphrase LUKS:** la scrivi tu, due volte. Solo lettere e numeri.
   - **password utente:** la scrivi tu, due volte, quando parte `mkpasswd`.
   - **attesa:** il download e il build richiedono 20–60 minuti, a seconda della rete.
6. Quando Claude conferma che `nixos-install` è terminato, scrivi `reboot` e togli la chiavetta mentre il T430 si spegne.

## Fase 4 — Primo avvio

Al riavvio compare GRUB: lascia partire la prima voce (**NixOS**), le altre sono gli esperimenti (vedi "Uso quotidiano").

1. Scrivi la **passphrase LUKS** sulla tastiera del T430.
2. Al login testuale entra come `alessandro` con la tua password: parte sway, il desktop a finestre affiancate.
3. Le scorciatoie di sway che ti servono subito (**Super** = tasto Windows):

| Scorciatoia | Azione |
| --- | --- |
| Super + Invio | apre il terminale |
| Super + D | cerca e apre un programma |
| Super + Shift + Q | chiude la finestra |
| Super + 1, 2, 3… | cambia desktop virtuale |
| Super + Shift + E | esce dalla sessione |

4. Rete: il cavo funziona da solo. Per il Wi-Fi apri il terminale e usa `nmtui`.
5. Nel terminale fissa le versioni dei pacchetti, collega GitHub e salva:

```
cd ~/t430-lab
git add -A && git commit -m "hardware reale + versioni fissate"
gh auth login
git push
```

Con `gh auth login` scegli GitHub.com, HTTPS e il login dal browser: ti mostra un codice da inserire nella pagina che apre in Firefox.

## Fase 5 — Avviare il laboratorio

Da qui il lavoro lo porta avanti Claude Code sul T430: legge da solo `CLAUDE.md`, che contiene metodo, strumenti, limiti e backlog.

1. Nel terminale del T430:

```
cd ~/t430-lab
claude
```

2. Rifai il login (quello della live non viene conservato) e incolla:

```
Leggi CLAUDE.md, NOTEBOOK.md e docs/programma-ricerca.md. Comincia completando la sezione Hardware e le misure di riferimento, poi passa alla Parte II del programma. Segui il metodo di CLAUDE.md, annota ogni esperimento in NOTEBOOK.md, fai commit e push.
```

3. Cosa aspettarti dalla prima sessione:
   - rileva l'hardware e completa la scheda in `CLAUDE.md`;
   - legge i limiti di potenza con `lab-limits` e fa il primo `lab-atlas`;
   - ti chiede di staccare l'alimentatore per le misure a batteria;
   - per le analisi profonde (flash del BIOS, EC, chipset) ti chiede di riavviare e scegliere la voce GRUB **deep**.
4. Turno notturno (facoltativo): scrivi a Claude "attiva il turno notturno". Ogni notte alle 3 porterà avanti da solo un esperimento del backlog e consumerà il tuo abbonamento Claude.

## Uso quotidiano

Ogni voce di GRUB è lo stesso sistema con una variabile cambiata; senza toccare niente parte quella principale.

| Voce di GRUB | Quando usarla |
| --- | --- |
| NixOS (principale) | Uso normale, con tutto il tuning attivo |
| vanilla | Gruppo di controllo per gli esperimenti: niente tuning |
| perf | Massime prestazioni, protezioni Spectre/Meltdown spente: solo per misure |
| battery | Massimo risparmio energetico |
| deep | Analisi a basso livello (flash del BIOS, EC, chipset): solo per le sessioni di analisi |
| NixOS - All configurations | Le versioni precedenti del sistema, per tornare indietro |

| Comando | A cosa serve |
| --- | --- |
| `claude` (in `~/t430-lab`) | Riprende il lavoro con Claude |
| `rebuild` | Applica il repository al sistema |
| `lab-try 10` / `lab-keep` | Prova una modifica con annullamento automatico dopo 10 minuti / la conferma |
| `sudo nixos-rebuild switch --rollback` | Torna alla versione precedente |
| `lab-snapshot nome` / `lab-limits` | Una misura della macchina / lettura dei limiti di potenza |
| `lab-blackbox-dump` | Salva ora lo stato della scatola nera, per esempio dopo un rallentamento |
| `nix flake update` poi `lab-try` | Aggiorna tutto il software, in prova |

I dati grezzi delle misure restano sul T430 in `~/lab` e non vanno su GitHub, perché contengono numeri di serie e firmware. Ogni tanto copiali su un disco esterno.

## Se qualcosa va storto

Quasi tutto si risolve ripartendo dalla chiavetta, e nessun errore del software è definitivo: GRUB conserva le versioni precedenti.

| Problema | Soluzione |
| --- | --- |
| Il T430 non si avvia dalla chiavetta | Riscrivila con Rufus in modalità DD; con F12 prova l'altra voce della chiavetta; nel BIOS controlla "Both" |
| `ssh` risponde "connection refused" | Sulla live: `sudo systemctl start sshd` |
| `ssh` rifiuta la password | Sulla live: `passwd` di nuovo |
| Niente rete sulla live | Usa il cavo, oppure il Wi-Fi (comandi qui sotto) |
| Il build si ferma con un errore su un pacchetto | Di solito un nome cambiato in nixpkgs: Claude Code corregge il file e riprende. Da solo: commenta la riga indicata nell'errore |
| Il disco non è `/dev/sda` | Va cambiato `device` in `hosts/t430/disko.nix` prima di partizionare |
| `mkpasswd` non esiste | `nix-shell -p mkpasswd` e poi di nuovo il comando |
| La passphrase LUKS non viene accettata all'avvio | Controlla Bloc Maiusc; se contiene simboli, prova a digitarla come su una tastiera americana |
| Il login rifiuta la password | Il file con la password manca o è sbagliato: rigeneralo dalla chiavetta (comandi qui sotto) |
| Dopo una modifica qualcosa non va | In GRUB scegli "NixOS - All configurations" e una versione precedente, oppure `sudo nixos-rebuild switch --rollback` |

**Wi-Fi dalla live** (al posto del cavo):

```
sudo systemctl start wpa_supplicant
wpa_cli
> add_network
> set_network 0 ssid "NOME-RETE"
> set_network 0 psk "PASSWORD-WIFI"
> enable_network 0
> quit
```

**Rigenerare la password dell'utente** (dalla chiavetta, se il login non funziona):

```
sudo cryptsetup open /dev/disk/by-partlabel/disk-main-luks cryptroot
sudo mount -o subvol=@persist /dev/mapper/cryptroot /mnt
nix-shell -p mkpasswd --run "mkpasswd -m yescrypt" | sudo tee /mnt/secrets/alessandro.hash
sudo umount /mnt && sudo cryptsetup close cryptroot
```

Se Claude Code non parte sulla live, il README del repository (Opzione B) ha tutti i comandi per installare a mano.

## Riprendere il progetto con Claude in futuro

La memoria del progetto è il repository, non una chat: qualsiasi sessione di Claude può riprendere da dove si era rimasti.

- **Sul T430:** `cd ~/t430-lab` e `claude`. Claude legge da solo `CLAUDE.md`; per riprendere basta scrivere "leggi NOTEBOOK.md e continua dal backlog".
- **Da un altro computer o da claude.ai:** "Lavora sul repository github.com/alecristofanilli/t430-lab: leggi README.md, CLAUDE.md, NOTEBOOK.md e docs/programma-ricerca.md". Per modificare il repository da lì serve l'accesso GitHub di Claude (l'app GitHub di Claude installata su quel repository).
- **Dove trovi cosa:**

| File | Contenuto |
| --- | --- |
| `README.md` | Cos'è il progetto e installazione manuale |
| `CLAUDE.md` | Istruzioni, metodo, limiti e backlog per Claude |
| `NOTEBOOK.md` | Diario di tutti gli esperimenti, con le misure |
| `docs/programma-ricerca.md` | I 17 filoni di ricerca, Parte II compresa |
| `docs/hardware.md` | Upgrade, overclock e firmware (coreboot, 1vyrain, Skulls, Heads) |

La parte hardware (pasta termica, CPU, flash del BIOS) resta tua: Claude prepara guide e script, ma non esegue mai il flash del firmware.
