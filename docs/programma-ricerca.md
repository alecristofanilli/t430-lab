# Programma di ricerca — il T430 studiato fino al bit

Obiettivo: conoscere questa macchina meglio di chi l'ha progettata (per quanto è possibile da software),
documentarla in modo riproducibile e usare quella conoscenza per customizzazioni che nessuno ha fatto
in modo così sistematico. Ogni filone produce **dati grezzi versionati**, **un'analisi** e **una modifica
al sistema** (oppure la dimostrazione che una modifica non serve).

Ordine consigliato: 1 → 2 → 3 → 4 in parallelo agli altri; 5–8 quando la base è solida.

---

## 1. Atlante hardware differenziale
**Domanda:** qual è lo stato completo della macchina, registro per registro, e cosa cambia tra una condizione e l'altra?

- `lab-atlas` in varie condizioni: `ac-idle`, `bat-idle`, `bat-load` (stress-ng), `lid-closed`, `suspend-resume`,
  e in futuro `coreboot`. Sempre dalla voce GRUB `deep`.
- `lab-atlas-diff` tra coppie di condizioni: quali MSR, registri PCI, bit dell'EC e GPIO cambiano.
- Prodotto: `atlas/ATLAS.md`, una mappa commentata di ciò che cambia e perché; i dump grezzi restano in ~/lab/atlas.
- Valore: è la base per tutti gli altri filoni, e diventerà il confronto "prima/dopo coreboot" più dettagliato
  che si possa fare su un T430.

## 2. La mappa dell'embedded controller
**Domanda:** cosa significa ogni byte dei 256 della RAM dell'EC?

- `lab-ec-watch` durante azioni scriptate e annotate: coperchio, alimentatore, Fn+tasti, LED, carico CPU,
  carica/scarica, ventola forzata a vari livelli.
- Correlazione automatica evento → offset/bit (script Python nel devShell `re`).
- Confronto con quello che è già documentato per l'EC dei ThinkPad (DSDT disassemblato in `atlas/acpi`,
  sorgenti `thinkpad_acpi` del kernel, progetto thinkpad-ec).
- Prodotto: `docs/ec-map.md`, la mappa dei registri con il grado di certezza per ciascuno.
- Livello successivo (solo con watchdog termico attivo, vedi CLAUDE.md): scrittura controllata di registri
  per verificarne la funzione.

## 3. Modello energetico del T430
**Domanda:** dove va ogni milliwatt?

- `lab-power-trace` a batteria in scenari controllati: schermo a diverse luminosità, Wi-Fi on/off, SSD in idle e
  sotto I/O, CPU per livello di frequenza e per C-state, grafica in idle e con video.
- RAPL dà package, core e grafica; la batteria dà il totale; la differenza stima il resto. Le variazioni
  controllate isolano schermo, Wi-Fi e SSD.
- Prodotto: un modello di regressione `W = f(componenti, stati)`, una tabella "costo di ogni componente"
  e un widget per waybar che mostra in tempo reale dove sta andando l'energia.
- Applicazione: un profilo di risparmio costruito sui numeri invece che su liste di consigli generiche.

## 4. Modello termico e controllo della ventola
**Domanda:** si può controllare la ventola meglio del firmware Lenovo e della curva a gradini di thinkfan?

- Identificazione di un modello termico a parametri concentrati (rete RC) dai dati temperatura/potenza/ventola
  raccolti sotto carichi a gradino.
- Controller predittivo (MPC) o PID in un piccolo demone: anticipa i picchi invece di reagire, a parità di
  temperatura massima minimizza rumore e cambi di velocità.
- Sicurezza: watchdog che restituisce la ventola al controllo automatico del firmware se il demone muore o se
  la temperatura supera una soglia; il firmware mantiene comunque il proprio spegnimento d'emergenza.
- Prodotto: il demone come modulo NixOS, con grafici confrontati con thinkfan e con la modalità automatica.

## 5. Kernel su misura, misurato
**Domanda:** quanto rende un kernel costruito solo per questa macchina?

- Varianti: `linuxPackages_latest` (riferimento), CachyOS (xddxdd/nix-cachyos-kernel), custom con
  `-march=ivybridge` e config ridotta ai soli moduli usati (ricavati da `lsmod` negli atlas), varianti
  PREEMPT_RT e con Clang/LTO.
- Metriche: tempo di avvio, RAM a riposo, latenza (`cyclictest` sotto carico), throughput (build Nix
  di riferimento), consumo a riposo.
- Compilazione: sul T430 di notte, oppure delegata a una macchina più potente come remote builder di Nix.

## 6. Scheduler e ottimizzazione automatica
**Domanda:** qual è la combinazione migliore di scheduler, sysctl e parametri del kernel per questa macchina,
e la può trovare un agente da solo?

- Spazio di ricerca: scheduler sched_ext (lavd, bpfland, rustland, flash...) × parametri chiave (swappiness,
  dirty ratio, governor, EPB, mitigazioni).
- Ogni prova è una generazione NixOS (riproducibile al bit), applicata con `lab-try` e misurata con un
  benchmark composito (latenza interattiva + throughput + watt).
- Ottimizzazione bayesiana guidata dal turno notturno: Claude propone, misura, aggiorna il modello, ripete.
- Prodotto: la configurazione ottima con l'intervallo di confidenza, e il registro completo dei tentativi.
  È la parte più vicina al "mai fatto": un agente che ottimizza un sistema operativo reale con esperimenti
  riproducibili al bit.

## 7. Audit di sicurezza del firmware
**Domanda:** quanto è protetto il firmware Lenovo del T430, bit per bit, e cosa cambia con coreboot?

- `chipsec` (helper linuxnative): protezione in scrittura della flash SPI, lock del BIOS, SMRR, SMM, configurazione
  del controller di memoria.
- Dump della flash SPI (sola lettura) analizzato con `ifdtool` e UEFITool: regioni, moduli UEFI, versione e
  stato dell'Intel ME (`me_cleaner -c`, `intelmetool`).
- `spectre-meltdown-checker` su ogni voce di GRUB: stato reale delle mitigazioni (la voce `perf` le spegne di proposito).
- Prodotto: un rapporto di audit nello stile di quelli professionali, rifatto dopo coreboot/Heads come confronto.

## 8. DRAM e affidabilità
**Domanda:** com'è fatta e quanto è affidabile la memoria di questa macchina?

- SPD dei moduli (`decode-dimms`): timing reali e dichiarati, produttore, data.
- Configurazione del controller di memoria (inteltool) e banda/latenza misurate.
- Test di affidabilità con `memtester` e con un passaggio completo di MemTest86 dalla chiavetta: base per un
  eventuale tuning dei timing con coreboot.

---

## Regole del programma
- Dati grezzi in ~/lab (atlas, ec, power, results), analisi e conclusioni nel repo (`docs/`, `NOTEBOOK.md`).
- Ogni affermazione nei documenti rimanda ai dati che la sostengono. "Sembra" non è un risultato.
- Lettura libera di qualsiasi registro. Scrittura su EC e MSR solo nei filoni 2 e 4, con watchdog attivo.
  Scrittura sulla flash SPI mai (vedi docs/hardware.md: la fa Alessandro, con dump di backup).
