# Programma di ricerca — il T430 studiato fino al bit

Obiettivo: conoscere questa macchina meglio di chi l'ha progettata (per quanto è possibile da software),
documentarla in modo riproducibile e usare quella conoscenza per customizzazioni che nessuno ha fatto
in modo così sistematico. Ogni filone produce **dati grezzi versionati**, **un'analisi** e **una modifica
al sistema** (oppure la dimostrazione che una modifica non serve).

Ordine consigliato: 1 → 2 → 3 → 4 in parallelo agli altri; 5–10 quando la base è solida.

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

## 9. Overclock, limiti di potenza e frequenze
**Domanda:** quanta prestazione c'è davvero nel T430 oltre i limiti di fabbrica, e a che costo termico ed energetico?

Cosa si può e non si può fare su Ivy Bridge mobile:
- **Moltiplicatore**: bloccato sulle CPU normali (i5, i7 QM). Sbloccato solo sulle **XM** (i7-3920XM, 3940XM):
  con quelle i moltiplicatori turbo (MSR 0x1AD) si alzano da software. `lab-limits` dice se la tua è programmabile.
- **Limiti di potenza (PL1/PL2)**: si alzano da software (MSR 0x610 e registro MMIO in MCHBAR) **se il BIOS non li
  ha bloccati** (bit 63). Il BIOS Lenovo di solito li blocca; 1vyrain o coreboot li sbloccano. Con limiti più
  alti il turbo dura di più sotto carico prolungato: è il guadagno più concreto anche su CPU non XM.
- **Undervolt**: in pratica non disponibile da software su Ivy Bridge (l'offset di tensione via MSR arriva con Haswell).
- **GPU HD 4000**: si può fissare la frequenza minima e massima fino al massimo hardware (RP0), non oltre.
- **RAM**: il BIOS Lenovo arriva a DDR3-1600. Frequenze e timing più spinti passano da coreboot (raminit nativo),
  quindi dalla fase hardware.
- **Il vero limite è termico ed elettrico**: dissipatore e pasta (filone 4), alimentatore da 90 W (con quello da
  65 W una quad-core va in PROCHOT sotto carico), batteria in buono stato.

Metodo: `lab-limits` → alzare un parametro alla volta (non persistente) → stress-ng + `lab-power-trace` + s-tui per
almeno un'ora → frequenza sostenuta, temperatura, watt e prestazioni per watt rispetto al default.
Prodotto: un profilo "oc" come specialisation, con la curva prestazioni/temperatura/consumo che lo giustifica.

## 10. Tutto il sistema compilato per Ivy Bridge
**Domanda:** cosa cambia se ogni singolo binario del sistema è compilato per questa CPU?

- NixOS permette di ricompilare l'intero sistema con `-march=ivybridge` impostando l'architettura della piattaforma
  (`nixpkgs.hostPlatform = { system = "x86_64-linux"; gcc.arch = "ivybridge"; gcc.tune = "ivybridge"; }`, più
  `gccarch-ivybridge` in `nix.settings.system-features` sulla macchina che compila). Nessuna cache binaria:
  si ricompila tutto, dal compilatore in su.
- Sul T430 servirebbero giorni: si delega a una macchina più potente come remote builder di Nix (o a una VM),
  e il T430 scarica solo i risultati.
- Varianti da confrontare: generico x86-64 (riferimento), `-march=ivybridge`, `-march=ivybridge` + LTO, e solo per
  i pacchetti caldi (kernel, compilatori, Python/numpy, compressori, Mesa).
- Prodotto: misure su benchmark reali (build, compressione, calcolo scientifico, tempo di avvio) che dicono se
  ricompilare tutto vale davvero la pena, cosa raramente misurato in modo così pulito perché di solito
  cambiano più variabili insieme. Qui cambia solo il flag del compilatore, con tutto il resto identico al bit.

---

## Regole del programma
- Dati grezzi in ~/lab (atlas, ec, power, results), analisi e conclusioni nel repo (`docs/`, `NOTEBOOK.md`).
- Ogni affermazione nei documenti rimanda ai dati che la sostengono. "Sembra" non è un risultato.
- Lettura libera di qualsiasi registro. Scrittura su EC e MSR solo nei filoni 2 e 4, con watchdog attivo.
  Scrittura sulla flash SPI mai (vedi docs/hardware.md: la fa Alessandro, con dump di backup).
