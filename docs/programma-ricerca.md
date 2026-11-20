# Programma di ricerca — il T430 studiato fino al bit

Obiettivo: conoscere questa macchina meglio di chi l'ha progettata (per quanto è possibile da software),
documentarla in modo riproducibile e usare quella conoscenza per customizzazioni che nessuno ha fatto
in modo così sistematico. Ogni filone produce **dati grezzi versionati**, **un'analisi** e **una modifica
al sistema** (oppure la dimostrazione che una modifica non serve).

Ordine consigliato: 1 → 2 → 3 → 4 in parallelo agli altri; 5–10 quando la base è solida. La Parte II
(11–17) può partire subito: la scatola nera è già attiva e l'archeologia è indipendente dal resto.

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

# Parte II — Sperimentazione pionieristica

I filoni 1–10 studiano e ottimizzano la macchina. Quelli che seguono provano a fare cose che, per quanto
ne sappiamo, nessuno ha fatto in modo sistematico su un portatile. Ognuno ha una domanda, un metodo
riproducibile e un criterio per dire se ha funzionato.

## 11. Archeologia del software
**Domanda:** sullo stesso identico hardware, cosa hanno dato e cosa hanno tolto nove anni di evoluzione del software?

- **Fattibilità verificata (2026-11-20):** il Nix del 2026 valuta ancora nixpkgs release-17.09 (kernel 4.9.86).
  Punto di partenza in `archeologia/era.nix`.
- **Epoche:** 17.09 · 19.09 · 21.11 · 23.11 · 25.11 · unstable 2026. Per ognuna due varianti: il commit del
  rilascio ("com'era quando è uscita") e la fine del ramo ("con tutte le patch"). Per la 17.09 è un taglio
  storico: il rilascio è prima di Spectre e Meltdown, la fine del ramo è dopo.
- **Avvio:** ogni epoca è un'immagine netboot (tutto in RAM), lanciata con kexec dal sistema del laboratorio.
  Il disco non viene toccato. I risultati vanno sulla partizione EFI, perché un sistema del 2017 non apre LUKS2.
- **Due assi di misura:**
  - *sistema dell'epoca*: kernel e programmi dell'epoca (compressione, Python, SQLite, compilazione C, avvio);
  - *solo il kernel*: lo stesso benchmark statico moderno su ogni kernel, per isolare l'evoluzione di
    scheduler, gestione energetica e mitigazioni.
- **Metriche:** tempo di avvio, RAM a riposo, consumo a riposo a batteria, prestazioni, latenza.
- **Rischi:** binari dell'epoca non più in cache (si ricompilano su un builder remoto) e sorgenti scomparsi
  (tarballs.nixos.org, Software Heritage).
- **Prodotto:** grafici "anno di rilascio → metrica" sullo stesso hardware, e una risposta misurata alla domanda
  "il software è diventato più lento?".

## 12. Un sistema che cambia personalità da solo
**Domanda:** un sistema che riconosce cosa stai facendo e si riconfigura al volo batte i profili fissi?

- **Riconoscimento dell'attività:** processi attivi, pressione PSI, I/O, rete, schermo; eventualmente un
  piccolo classificatore addestrato sui dati della scatola nera (filone 14).
- **Leve a caldo, senza riavvio:** scheduler sched_ext (si sostituisce mentre il sistema gira, con `scxctl`),
  governor ed EPB, frequenze della GPU, curva della ventola (filone 4), priorità dei processi.
- **Valutazione:** carichi registrati e rigiocati (compilazione + navigazione + video) con profilo adattivo
  contro ogni profilo fisso. Metriche: latenza percepita (tempo di risposta dell'input), throughput, watt.
- **Prodotto:** un demone come modulo NixOS, con il confronto che dice se vale la complessità.

## 13. Il gemello digitale del T430
**Domanda:** si può prevedere temperatura, consumo e autonomia di un carico prima di eseguirlo?

- Unisce i modelli dei filoni 3 (energia) e 4 (termica) e la mappa dell'atlas in un simulatore: in ingresso un
  profilo di carico (CPU, GPU, I/O, schermo), in uscita le curve previste di temperatura, watt e batteria.
- **Validazione:** prima la previsione, poi la misura reale; l'errore medio è il punteggio del modello.
- **Uso:** domande "what-if" (quanta autonomia con questo lavoro? quale profilo tiene la CPU sotto 80 °C?)
  e un banco di prova per il filone 12, che può provare strategie sul gemello prima che sulla macchina.

## 14. La scatola nera
**Domanda:** si può diagnosticare ogni rallentamento il giorno dopo, senza doverlo riprodurre?

- **Fatto:** `lab-blackbox` è già nel sistema e parte all'avvio. Tiene in memoria 30 minuti di campioni
  (PSI, temperature, frequenza, watt, throttling, processi più attivi e bloccati in I/O). Si apre da sola
  quando il kernel segnala uno stallo tramite i trigger PSI o quando la CPU va in throttling. Le registrazioni
  finiscono in ~/lab/blackbox (prima, dopo, processi, log del kernel). Apertura manuale: `lab-blackbox-dump`.
  Collaudata il 2026-11-20: il kernel la sveglia entro pochi secondi da uno stallo di CPU indotto.
- **Prossimi passi:** sonde eBPF (bpftrace) attivate solo durante l'apertura, per vedere *dove* il kernel
  aspettava (latenza dello scheduler, I/O a blocchi, page fault); analisi automatica la mattina dopo,
  con una voce in NOTEBOOK.md per ogni evento.

## 15. Il record d'avvio
**Domanda:** quanto può essere veloce, dall'accensione al desktop, un portatile del 2012?

- **Fase software:** `systemd-analyze` (blame, critical-chain, plot) e bootchart; ogni millisecondo attribuito.
  Leve: initrd minimo, compressione del kernel, servizi in parallelo, avvio diretto senza GRUB (EFI stub).
- **Fase firmware** (dopo coreboot, decide Alessandro): cache dell'inizializzazione della RAM, payload minimo,
  oppure Linux come payload, che salta del tutto il bootloader.
- **Prodotto:** la cronologia di ogni tentativo, da "accensione → desktop" com'è oggi fino al record finale,
  con il budget di tempo per ogni fase.

## 16. Evoluzione del kernel
**Domanda:** un algoritmo genetico trova una configurazione del kernel migliore di quelle scritte a mano?

- **Genoma:** un sottoinsieme di opzioni Kconfig rilevanti (scheduler, preemption, timer, frequenza di tick,
  compressione, mitigazioni, moduli presenti). Ogni individuo è un kernel costruito da Nix, quindi riproducibile al bit.
- **Fitness:** tempo di avvio, RAM, latenza (`cyclictest`), throughput, watt a riposo, misurati sulla macchina vera.
- **Pratica:** si compila su un builder remoto più potente; il T430 avvia e misura una generazione dopo l'altra
  (`nixos-rebuild boot` + riavvio automatico), con il turno notturno che fa girare il ciclo.
- **Prodotto:** il kernel "evoluto", la storia dell'evoluzione e quali opzioni si sono rivelate davvero decisive.

## 17. Il paper
**Domanda:** tutto questo regge come lavoro scientifico?

- Alla fine di ogni grande filone, un capitolo scritto da Claude con metodo, dati, grafici e limiti.
- Il risultato finale è un rapporto unico, "Ottimizzare un ThinkPad del 2012 nel 2027", pubblicato come sito
  statico generato dal repo, con ogni grafico rigenerabile dai dati.

---

## Regole del programma
- Dati grezzi in ~/lab (atlas, ec, power, results, blackbox), analisi e conclusioni nel repo (`docs/`, `NOTEBOOK.md`).
- **Il repo è pubblico.** Gli atlas contengono numeri di serie, indirizzi MAC e il firmware Lenovo (proprietario):
  i dati grezzi non entrano mai nel repo. Nel repo vanno solo risultati aggregati e anonimizzati.
- Ogni affermazione nei documenti rimanda ai dati che la sostengono. "Sembra" non è un risultato.
- Lettura libera di qualsiasi registro. Scrittura su EC e MSR solo nei filoni 2 e 4, con watchdog attivo.
  Scrittura sulla flash SPI mai (vedi docs/hardware.md: la fa Alessandro, con dump di backup).
