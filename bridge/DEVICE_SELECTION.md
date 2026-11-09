# Apparaten kiezen in Godot

Werk **spel en bridge samen bij**. Start de Python-bridge via `start_windows.bat`.
Een eerder gebouwde VelodromeBridge.exe bevat deze uitbreiding pas na opnieuw
bouwen; deze featurebranch levert broncode, geen nieuwe releasebinary.

Wanneer de commandobridge bereikbaar is, verschijnt Apparaten eenmalig vóór
interactie met het hoofdmenu. Ook een later gestarte bridge wordt ontdekt zodra
het spel in SETUP staat. Tijdens een wedstrijd wordt geen onverwachte pagina
geopend. Apparaten staat rechtsboven naast Instellingen en blijft tijdens pauze
bereikbaar. Openen tijdens een lopende wedstrijd pauzeert deze via de bestaande
vrijgaveflow; sluiten hervat niet automatisch. Hervat via het pauzemenu.

Per rol verschijnen alleen werkelijk waargenomen, ondersteunde apparaten:

- Trainer / rollen: advertenties met FTMS-service 1826. De bestaande FTMS-
  featurecontrole blijft bepalen welke belastingopdrachten de trainer aankan.
- Besturing: linker Zwift Ride met fabrikant-ID 094A en rolmarker 8. De bestaande
  RideOn-handshake en de huidige knoppendecoder blijven behouden. Rechter Ride,
  hoofdtelefoons en andere niet-ondersteunde controllers worden niet aangeboden.
- Hartslag: BLE Heart Rate Service 180D, notificaties op 2A37 (8/16-bit BPM).
  De bestaande ANT+-ontvanger verschijnt alleen na echte hartslagdata, als één
  actieve stream. Deze backend meldt geen sensor-ID en scant geen sensorlijst;
  individueel kiezen tussen meerdere ANT+-zenders wordt niet ondersteund.

Geen / overslaan schakelt die rol expliciet uit. De afsluitknop heet Overslaan
zolang geen apparaat verbonden is en Kies deze setup zodra minstens een apparaat
verbonden is. De knop sluit de pagina zonder bestaande keuzes te veranderen.
Bij bridge-uitval wordt de knop opnieuw Overslaan. Expliciete keuzes worden atomair
opgeslagen in `device_selections.json` naast de bridgesource of bridge-executable.
Deze persoonlijke file staat in .gitignore. Opslagfouten worden gemeld en wijzigen
de selectie niet. Zonder opgeslagen keuze behoudt de bridge zijn bestaande
automatische KICKR/left-Ride/ANT+-startgedrag. Selecties worden nooit stilzwijgend
vervangen door een ander apparaat als het gekozen apparaat ontbreekt.

De lijst scant periodiek; een scan duurt maximaal 8 seconden. Advertenties blijven
30 seconden bruikbaar en verbonden apparaten blijven zichtbaar. Een verdwenen
opgeslagen keuze blijft expliciet als niet beschikbaar vermeld. BLE-selecties
verbinden onafhankelijk opnieuw. Een rolwissel wacht tot de oude verbinding en
trainer-Reset afgehandeld zijn. ACK bevestigt selectie/opslag, geen hardwarelink.
De pagina vermeldt afzonderlijk welke verbindingen actief zijn.

Na een besturingskeuze verschijnt direct onder Besturing de subtiele link
**Knoptoewijzing aanpassen**, met een instellingenicoon en een verwijspijl. Die
opent **Instellingen > Besturing > Knoptoewijzing**. Een groen Verbonden-label
verschijnt alleen bij een actuele besturingsverbinding. De sluitknop heet dan Terug naar apparaten; Escape en Ride Z
brengen je ook terug. In de testmodus blijft invoer voor knopvastlegging bestemd;
er ontsnappen geen wedstrijdacties. Wedstrijdklok, afstand en positie blijven bij
alle overlaywissels bewaard.

## UDP-uitbreiding (v=1, 127.0.0.1:51725)

De bestaande envelope, validatie, rate limit en deduplicatie blijven gelden:

```json
{"type":"command","v":1,"id":"devices-1","command":"devices"}
{"type":"command","v":1,"id":"devices-2","command":"select_device","role":"trainer","address":"BLE-adres"}
```

Rollen: `trainer`, `controller`, `heart_rate`; leeg adres schakelt uit.
`state` in de ACK bevat `device_selection_v:1`, `devices`, `selected`, `connected`
en `scan_error`. Apparaten bevatten `address`, `name`, `roles`, `transport` en
`available`. `selected` null betekent de oorspronkelijke automatische keuze;
leeg betekent uit. Selecteren vereist een actueel beschikbaar apparaat met de
gevraagde rol. Verzoeken creëren geen trainerlease en verlengen die ook niet.
Godot gebruikt een aparte socket, pollt iedere seconde en meldt uitval na 3 s.
Onbevestigde keuzes krijgen na 4 s een melding; de volgende poll haalt de echte
bridgestatus op. Een oude bridge geeft een expliciete bijwerkmelding.

## Protocolbronnen

- [BleakScanner: advertenties en service UUID's](https://bleak.readthedocs.io/en/stable/api/scanner.html)
- [Bluetooth SIG Assigned Numbers](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Assigned_Numbers/out/en/index-en.html)
- [Bluetooth Heart Rate Service](https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0/)
- Bestaande Ride-implementatie en protocolverwijzingen in `README.md`,
  `selection.py`, `ride_ble.py` en `docs/README_ride_button_bits.md`.

## Verificatie

Python: `python -m unittest discover -s bridge/tests -q`.
Godot 4.7: headless scripts `test_bridge_devices.gd`,
`test_bridge_navigation.gd`, `test_exit_pause.gd`, `test_bridge_protocol.gd` en
`test_bridge_steering.gd` in `game/tests`.

De nieuwe tests gebruiken waargenomen advertentiefixtures, BLE-notificaties en
echte lokale UDP-datagrammen zonder fietsapparatuur. Een fysieke Windows-test met
trainer, linker Ride, BLE-HR en ANT+-dongle blijft nodig voor radioverbindingen,
gelijktijdig scannen/verbinden en de bevestiging van werkelijke weerstand.

### Resultaat van deze featurebranch

- Basis: `origin/v0.2` op `a3117a27e7717004c1de66bde086d735df3fafb4`.
- Python: 99 tests, 92 geslaagd, 7 bestaande optionele tests overgeslagen.
- Godot 4.7.2: alle vijf bovenstaande scripts geslaagd; nieuwe apparatenflow
  omvat een echte loopback UDP-uitwisseling, rolfiltering, automatisch openen,
  overslaan, pauze met behoud van klok/baan, knoptoewijzing/terug, afwijzingen,
  ontbrekende opgeslagen apparaten en bridge-uitval.
- De bestaande navigatietest opent nu expliciet de wedstrijdgalerij vanuit de
  huidige starthub en is afgeschermd van een eventueel draaiende lokale bridge.
- Apparatenpagina ook met Windows-rendering getest en op 1280x720 visueel nagekeken.
- De testomgeving meldt een bestaande fout bij het lezen van de Windows-
  certificaatopslag; de lokale tests voltooien met exitcode 0. Geïmporteerde
  bronassets geven bestaande UID-waarschuwingen. Geen nieuwe scriptfouten.
- Geen fysieke BLE/ANT+-verificatie of nieuwe gebundelde bridge-EXE uitgevoerd.
