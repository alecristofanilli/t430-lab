# t430-lab — istruzioni per Claude sulla macchina

Questo repo È il sistema operativo del ThinkPad T430 di Alessandro. È una **macchina di test**:
hai accesso completo e il mandato di spingere su customizzazione, ottimizzazione e ricerca.
Non serve prudenza sul software: serve **metodo**. Ogni modifica è un esperimento con
ipotesi, misura e conclusione, e deve restare reversibile.

## Hardware (da completare al primo avvio: `lscpu`, `lshw -short`, `lsblk`, `tlp-stat -b`)
- ThinkPad T430, Intel Ivy Bridge (Gen 3), grafica Intel HD 4000, socket rPGA988B
- CPU: ?  RAM: ?  Disco: ?  Wi-Fi: ?  Batteria (salute %): ?
- Firmware: BIOS Lenovo (coreboot = fase hardware, la decide ed esegue Alessandro — vedi docs/hardware.md)

## Architettura del repo
- `hosts/t430/` — ciò che dipende da questa macchina (disco con disko, hardware)
- `modules/base.nix` — boot (GRUB UEFI+legacy), nix, rete, utente, snapper, zram
- `modules/impermanence.nix` — root azzerata a ogni boot; stato ammesso solo se dichiarato
- `modules/performance.nix` — tuning dietro `lab.tuning.enable`
- `modules/experiments.nix` — specialisations: vanilla (controllo), perf, battery
- `modules/agent.nix` — sudo senza password, turno notturno opzionale (`lab.agent.nightly`)
- `modules/deep.nix` — strumenti di analisi a basso livello + voce GRUB `deep` (iomem=relaxed, ec_sys)
- `modules/blackbox.nix` — scatola nera sempre attiva (bench/lab-blackbox.py)
- `archeologia/` — sistemi NixOS di altre epoche avviabili in RAM (filone 11)
- `modules/home.nix` — dotfile con home-manager
- `pkgs/` + `bench/` — strumenti del laboratorio
- `shells/` — ambienti di ricerca (`nix develop .#datascience` ecc.)

## Strumenti del laboratorio
| comando | a cosa serve |
|---|---|
| `lab-snapshot <etichetta>` | misura (consumo, CPU, temperature, mitigazioni, generazione) → ~/lab/results/*.json |
| `lab-compare a.json b.json` | tabella prima/dopo con delta percentuali |
| `lab-try [minuti]` | applica la config in prova con **revert automatico** (default 5 min) |
| `lab-keep` | conferma la config in prova e la rende permanente |
| `lab-fs-diff` | file scritti nella root effimera da questo avvio (stato non dichiarato) |
| `lab-atlas <etichetta>` | fotografia completa fino ai registri: SMBIOS, CPUID, MSR, PCI config space, ACPI, EC, EDID, SPD, RAPL; con la voce `deep` anche flash SPI, chipset, ME, chipsec |
| `lab-atlas-diff A B` | differenze tra due atlas, binari compresi (byte e bit cambiati) |
| `lab-ec-watch [s] [durata]` | registra ogni byte della RAM dell'EC che cambia (voce `deep`) |
| `lab-power-trace [s] [durata]` | CSV di consumo: batteria + RAPL package/core/GPU + resto stimato |
| `lab-limits` | decodifica PL1/PL2 (MSR e MMIO), lock del BIOS, moltiplicatori turbo, TjMax, PROCHOT, frequenze GPU |
| `lab-blackbox-dump` | apre la scatola nera a mano (si apre già da sola su stalli e throttling) → ~/lab/blackbox |
| `nix develop .#re` | reverse engineering: Ghidra, radare2, rizin, ImHex, UEFITool, binwalk |
| `nvd diff /run/booted-system /run/current-system` | cosa è cambiato tra generazioni |

## Metodo (obbligatorio)
1. **Baseline**: `lab-snapshot <tema>-before`. Per i consumi: a batteria, luminosità fissa, 5 min di riposo,
   ripeti 3 volte. Un numero solo non è un dato.
2. **Una variabile alla volta**, nel modulo giusto. `nix flake check` deve passare.
3. **Applica con `lab-try`**, mai direttamente con `switch`. Se perdi la sessione, il revert ti salva.
   Per kernel, initrd e bootloader: `nixos-rebuild boot` + riavvio (lo stato precedente resta in GRUB).
4. **Rimisura**: `lab-snapshot <tema>-after`, poi `lab-compare`.
5. **Decidi**: beneficio misurabile → `lab-keep`, commit e voce in NOTEBOOK.md.
   Nessun beneficio → revert, voce in NOTEBOOK.md comunque (anche i risultati negativi sono risultati).

## Programma di ricerca
Il backlog qui sotto è la parte "sistema". La parte "analisi profonda" è in **docs/programma-ricerca.md**:
atlante hardware differenziale, mappa dell'EC, modello energetico, controllo predittivo della ventola,
kernel su misura, ottimizzazione automatica, audit del firmware, DRAM, overclock, sistema per Ivy Bridge.
La **Parte II** è la sperimentazione pionieristica ed è la vera priorità del progetto: archeologia del
software, sistema adattivo, gemello digitale, scatola nera, record d'avvio, evoluzione del kernel, paper.

## Limiti (gli unici)
- Non toccare partizioni, LUKS, `/persist/secrets` e i dati in `/home` senza chiedere ad Alessandro.
- Firmware e hardware: solo lui. Puoi leggere la flash SPI (`flashrom -r`), mai scriverla.
- Overclock e limiti (filone 9): scrivere PL1/PL2, moltiplicatori turbo e frequenze GPU è permesso, sempre con
  `lab-limits` prima e dopo, con un watchdog termico attivo e con valori che tornano di default al riavvio
  (mai persistenti finché non sono validati da almeno 1 ora di stress-ng senza throttling anomalo).
- Scritture su altri registri EC o MSR: solo per i filoni 2 e 4 del programma, solo con un watchdog che ripristina
  il controllo automatico della ventola e una soglia termica (es. 90 °C) che interrompe l'esperimento.
  Prima di scrivere un MSR mai provato, annota in NOTEBOOK.md cosa ti aspetti e come torni indietro.
- **Il repo è pubblico**: mai committare dati grezzi (~/lab), dump di firmware, numeri di serie, MAC, chiavi.
  Solo risultati aggregati e anonimizzati.
- Niente stato imperativo fuori dal repo (`nix-env -i`, file a mano in /etc): se serve, è Nix.
- Prima di disattivare la rete o SSH in modo permanente, chiedi.

## Backlog di ricerca
- [ ] Completare la sezione Hardware; baseline completa a corrente e a batteria (3 ripetizioni)
- [ ] Confronto default / vanilla / perf / battery: costo reale delle mitigazioni su Ivy Bridge
- [ ] Scheduler sched_ext: scx_lavd vs scx_bpfland vs scx_rustland vs EEVDF (latenza interattiva + build)
- [ ] Kernel: linuxPackages_latest vs CachyOS (xddxdd/nix-cachyos-kernel) vs custom `-march=ivybridge`
      con config ridotta (localmodconfig); misurare boot, RAM, prestazioni
- [ ] Tempo di boot: `systemd-analyze blame/critical-chain/plot`, obiettivo dichiarato e misurato
- [ ] Soglie batteria (`tlp-stat -b`), curva thinkfan sotto stress-ng, profilo termico con s-tui
- [ ] Ridurre il persistito al minimo con `lab-fs-diff`
- [ ] Hardening: lynis, sysctl kernel, AppArmor, kernel lockdown; specialisation "seclab" con tool offensivi
- [ ] Osservabilità: bpftrace/perf, flamegraph di boot e workload tipici
- [ ] Tema coerente (stylix) e waybar con metriche del laboratorio (W, °C, scheduler attivo)
- [ ] Integrazione col cluster Kubernetes su Raspberry (kubectl, k9s, WireGuard)
- [ ] `lab-limits` alla prima accensione: PL1/PL2 sono bloccati? La CPU è una XM con turbo programmabile?
- [ ] Generatore di report: dai JSON di ~/lab/results a grafici e a una pagina riassuntiva
