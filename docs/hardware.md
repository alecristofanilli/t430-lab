# Hardware e firmware del T430

La parte che solo Alessandro può fare: cacciavite, saldatore metaforico e programmatore SPI.
Claude può preparare script, verificare compatibilità e misurare gli effetti, ma non esegue flash.

## Livello 1 — upgrade senza rischi
| Componente | Scelta | Perché |
|---|---|---|
| RAM | 2 × 8 GB DDR3L 1600 (16 GB è il massimo) | build Nix, VM, zram più efficace |
| Disco | SSD SATA nella baia principale (SATA III) | la baia mSATA è SATA II: va bene per un secondo disco |
| Wi-Fi | Atheros AR9462 (ath9k) | driver e firmware completamente liberi. Con il BIOS Lenovo funzionano solo le schede in whitelist |
| Termica | pasta termica nuova + pulizia ventola | dopo 12 anni fa la differenza più grande, misurabile con `lab-snapshot` |
| Batteria | 9 celle (70++) | autonomia; misura la salute con `tlp-stat -b` |

## Livello 2 — CPU
Socket rPGA988B. Gli upgrade quad-core più comuni:
- **i7-3632QM** (35 W): la scelta più sicura per il dissipatore originale.
- **i7-3840QM / 3940XM** (45–55 W): la scelta spinta. Scalda parecchio; aiuta il dissipatore della versione
  con grafica dedicata, e il TDP si può limitare via firmware (1vyrain).

Esperimento naturale: confronto prima/dopo con `lab-snapshot`, `stress-ng` e `s-tui` (prestazioni per watt).

## Livello 3 — firmware libero
Il T430 ha **due chip SPI** (8 MB + 4 MB) sotto il palmrest. Strade possibili, in ordine di difficoltà:

1. **1vyrain** — jailbreak software del BIOS Lenovo (richiede una versione specifica del BIOS, eventualmente
   da ripristinare con un downgrade). Sblocca la whitelist Wi-Fi e il menu avanzato, e permette di flashare
   coreboot senza smontare.
2. **Skulls** — immagini coreboot già pronte con payload SeaBIOS, pensate per il T430. Si installa via
   programmatore esterno sui due chip, oppure partendo da 1vyrain. Gli aggiornamenti successivi si fanno da Linux.
   Il disco di questo repo ha già la partizione BIOS boot e GRUB legacy installato: dopo Skulls il sistema si avvia lo stesso.
3. **Heads** — coreboot + Linux come payload, con boot misurato via TPM: all'avvio il portatile dimostra di
   non essere stato manomesso. Va flashato esternamente, non tramite 1vyrain, se si vuole ME neutralizzato
   e lo spazio completo.
4. **coreboot compilato su misura** — la vera R&D: config propria, `me_cleaner`, payload a scelta
   (SeaBIOS, GRUB, edk2/UEFI). Claude può preparare toolchain e config in un devShell.

Occorrente: programmatore CH341A (meglio con adattatore a 3,3 V) o un Raspberry Pi, pinza SOIC8.
**Prima di tutto: dump dei chip originali, letti due volte e confrontati con l'hash.** È il backup che
permette di tornare indietro da qualsiasi errore.

## Livello 4 — mod
- **Tastiera classica a 7 righe** (dalla T420): serve la patch del firmware dell'embedded controller
  (progetto thinkpad-ec), applicabile anche tramite 1vyrain.
- **Schermo**: il pannello HD+ 1600×900 è un upgrade diretto; il Full HD richiede kit di conversione.

## Progetti di riferimento
- nixos-hardware (profilo `lenovo/thinkpad/t430`) — github.com/NixOS/nixos-hardware
- Skulls — github.com/merge/skulls
- 1vyrain — github.com/n4ru/1vyrain
- thinkpad-ec — github.com/hamishcoleman/thinkpad-ec
- Heads — github.com/linuxboot/heads (wiki: osresearch.net)
- me_cleaner — github.com/corna/me_cleaner
- coreboot — coreboot.org
