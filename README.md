# Velodrome

Een wielerspel op de piste, ontwikkeld met **Godot**, met AI-tegenstanders en ondersteuning voor indoorfietshardware via een aparte bridge.

> **Status:** actieve ontwikkeling.

## Projectstructuur

- `game/` — Godot-project: wedstrijden, renners, AI en interface.
- `bridge/` — hardwarekoppeling, waaronder Zwift Ride; communicatie met Godot via UDP.
- `docs/` — technische afspraken, spelontwerp en ontwikkelnotities.

## Ontwikkeling

Het project onderzoekt onder meer AI-rennerprofielen, groepsdynamiek en drafting, racevormen en UDP-gegevensuitwisseling met de bridge (inclusief geselecteerde versnelling en ERG-aansturing).

## Hardwarebridge v0.15

De Python-bridge staat in [`bridge/`](bridge/README.md), inclusief Windows-startbestand, dependencies, documentatie en 43 hardwarevrije tests. Ondersteunt KICKR FTMS, Zwift Ride left-master en Garmin ANT+ via libusb0, lokale UDP-telemetrie, ERG-doelen van 0–1300 W en FTMS-hellingsimulatie met virtuele versnellingen.

- [Technisch UDP-protocol](bridge/UDP_PROTOCOL.md)
- [Godot-overdracht](bridge/GODOT_HANDOFF.md)
- [Hellingsimulatie en versnellingsmodel](bridge/SIMULATION.md)
- [Validatie en hardwaretestpunten](bridge/VALIDATION.md)

Softwaretests slagen; fysieke trainerwerking en rijgevoel moeten nog met hardware worden bevestigd.

## Releases (gepland)

- Windows-versie met geïntegreerde bridge.
- Spelversie zonder meegeleverde bridge, voor wie een eigen bridge wil gebruiken.


## Licentie

