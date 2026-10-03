# ForeverInvite

Ett litet WoW-addon för att bjuda in folk snabbt.

## Installation

1. Kopiera mappen `ForeverInvite` till `World of Warcraft/<klient>/Interface/AddOns/`
   (t.ex. `_classic_era_` eller den mapp WoW Forever-klienten använder).
2. Starta om spelet. Om addonet inte syns i listan: bocka i **"Load out of date AddOns"**
   eller ändra `## Interface:` i `ForeverInvite.toc` till klientens version
   (skriv `/dump select(4, GetBuildInfo())` i spelet för att se den).

## Användning

- Någon whisprar dig `inv` (eller `invite` / `123`) → de bjuds in automatiskt.
- `/finv <namn>`: bjud in en spelare
- `/finv on` / `/finv off`: slå på/av auto-invite
- `/finv kw inv 123`: byt nyckelord
- `/finv guildonly`: auto-invita bara guildmedlemmar
- `/finv raid`: växla automatisk konvertering till raid när gruppen är full
- `/finv add <namn> [namn...]`, `/finv del <namn>`, `/finv list`, `/finv clear`: hantera en sparad lista
- `/finv all`: bjud in alla på listan (en i taget, med kort fördröjning)
- `/finv ginv <namn>`: skicka guild-invite
- `/finv status`: visa inställningar

Inställningar och listan sparas mellan sessioner (`ForeverInviteDB`).
