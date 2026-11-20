# Da dove vengono le idee

Non esiste un progetto unico che faccia tutto questo, ma ogni pezzo poggia su lavoro altrui.

| Pezzo di t430-lab | Ispirazione / dipendenza |
|---|---|
| Root effimera | "Erase your darlings" di Graham Christensen (grahamc.com/blog/erase-your-darlings) · nix-community/impermanence |
| Rollback btrfs nell'initrd | pattern diffuso nelle config della community (wiki NixOS "Impermanence") |
| Disco dichiarativo | nix-community/disko |
| Installazione remota/assistita | nix-community/nixos-anywhere (alternativa all'Opzione A del README) |
| Quirk hardware T430 | NixOS/nixos-hardware |
| Dotfile | nix-community/home-manager |
| Scheduler sched_ext | sched-ext/scx · modulo `services.scx-loader` di nixpkgs |
| Regole di priorità dei processi | ananicy-cpp + regole CachyOS |
| Valori sysctl per zram | tuning di Pop!_OS / CachyOS per zram |
| Kernel alternativo (backlog) | CachyOS · xddxdd/nix-cachyos-kernel · chaotic-cx/nyx |
| Firmware | coreboot · Skulls · Heads · 1vyrain · me_cleaner |

Config personali da leggere per idee (non da copiare alla cieca):
- github.com/Misterio77/nix-config — struttura pulita con impermanence
- github.com/byronogis/nix-config — impermanence + disko + home-manager
- github.com/yvan-sraka/X230 — NixOS su un parente stretto del T430 (X230, stessa generazione)

**La parte originale di t430-lab** è il metodo: esperimenti come specialisations confrontabili, dead man's
switch per applicare modifiche rischiose, misure in JSON con diario di laboratorio, e un agente che lavora
sulla macchina seguendo queste regole.
