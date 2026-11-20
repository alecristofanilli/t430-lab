# Diario di laboratorio — t430-lab

Formato di ogni voce:

```
## AAAA-MM-GG — titolo
Ipotesi:     cosa mi aspetto e perché
Modifica:    file / opzioni cambiate (commit)
Misure:      before → after (file in ~/lab/results)
Conclusione: tenuta / revertita, e cosa ho imparato
```

---

## 2026-11-20 — Fattibilità dell'archeologia del software (filone 11)
Ipotesi:     un Nix moderno (2.34) riesce ancora a valutare un NixOS di nove anni fa.
Modifica:    archeologia/era.nix (immagine netboot da un checkout qualsiasi di nixpkgs).
Misure:      nixpkgs release-17.09 → valutazione completa in ~1,5 s, kernel 4.9.86, versione 17.09.git.3ba3d8d.
             Disponibilità dei binari su cache.nixos.org non verificabile dall'ambiente di sviluppo (cache bloccata).
Conclusione: fattibile a livello di valutazione. Da verificare sul T430: binari in cache, build, avvio via kexec.

## 2026-11-20 — Collaudo della scatola nera (filone 14)
Ipotesi:     i trigger PSI svegliano lab-blackbox entro pochi secondi da uno stallo di CPU.
Modifica:    bench/lab-blackbox.py, modules/blackbox.nix.
Misure:      2 core saturati da 8 processi → apertura "stallo-cpu" con PSI cpu avg10 = 13,8%.
             4 processi su 2 core → top_cpu corretto (4 × ~50%), PSI cpu 40–50%.
Scoperte:    (1) dal kernel 6.5 i processi senza CAP_SYS_RESOURCE accettano solo finestre PSI multiple di 2 s
             (EINVAL con 1 s): tutte le soglie ora usano finestre da 2 s.
             (2) i processi nati dopo il campione precedente risultavano allo 0% di CPU, cioè proprio il colpevole
             di uno stallo improvviso: corretto contando da zero i loro tick.
Conclusione: tenuta, attiva di default.
