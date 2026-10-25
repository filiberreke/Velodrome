# Velodrome

Een wielerspel op de piste, ontwikkeld met **Godot**, met AI-tegenstanders en ondersteuning voor indoorfietshardware via een aparte bridge.

> **Status:** actieve ontwikkeling; deze repository is voorlopig privé. Het doel is om het project later gratis en open source te delen.

## Projectstructuur

- `game/` — Godot-project: wedstrijden, renners, AI en interface.
- `bridge/` — hardwarekoppeling, waaronder Zwift Ride; communicatie met Godot via UDP.
- `docs/` — technische afspraken, spelontwerp en ontwikkelnotities.

## Ontwikkeling

Het project onderzoekt onder meer AI-rennerprofielen, groepsdynamiek en drafting, racevormen en UDP-gegevensuitwisseling met de bridge (inclusief geselecteerde versnelling en geplande ERG-aansturing).

## Releases (gepland)

- Windows-versie met geïntegreerde bridge.
- Spelversie zonder meegeleverde bridge, voor wie een eigen bridge wil gebruiken.

De code en bouwinstructies van de bestaande lokale projecten moeten nog worden toegevoegd.

## Licentie

Een open-sourcelicentie wordt gekozen vóór de publieke release. Er is momenteel nog geen expliciete licentie voor hergebruik.
