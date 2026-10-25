# Velodrome 250 Python Bridge v0.15

Uitbreiding van v0.14, oorspronkelijk gebaseerd op `velodrome_bridge_v0131_udp_gear.zip`. Eén proces voor KICKR CORE
FTMS, Zwift Ride left-master, Garmin ANT+ via bestaande Dynastream/libusb0 en
Godot-communicatie. **Softwarematig getest; hardwarewerking van v0.15 wacht op de usertest.**

## Blijft wachten en opnieuw verbinden

De bridge mag starten voordat KICKR of linker Zwift Ride aanstaan. Hij blijft
scannen en wacht na een ontbrekend apparaat of verbindingsfout 5 seconden voor
de volgende poging. Elke scan duurt maximaal de ingestelde 8 seconden; een
verbindingspoging heeft daarnaast zijn eigen timeout. KICKR en Ride worden
onafhankelijk gezocht. Een tijdelijk onbeschikbare Bluetooth-adapter beëindigt
de bridge niet. Na de eerste keuze wordt hetzelfde BLE-adres opnieuw gezocht.

Ook een open KICKR-link zonder verse data/power gedurende meer dan 3 seconden
wordt gesloten en opnieuw gezocht. Metingen hervatten automatisch. Bij uitval
worden oude belasting, helling en UDP-eigendom gewist; na herstel wacht de trainer
vrijgegeven op een nieuwe opdracht. Start in het bijgewerkte spel een nieuwe
wedstrijd, of gebruik `sim` in de console zodra verse data beschikbaar is.
De bridge hoeft daarvoor niet opnieuw te starten. STOP, verlopen UDP-lease en
echte FTMS-protocolfouten blijven een bewuste blokkering van sturing; de
verbindings-/meetlus blijft ook dan werken. Zie [herstelprotocol](RECOVERY.md).

## Nieuw: echte FTMS-hellingsimulatie

Godot kan `set_grade` sturen met `grade_pct` van -20.00 t/m 20.00 (maximaal twee decimalen).
Dit activeert in SIM het echte FTMS-simulatiecommando 0x11. De trainer moet deze functie
adverteren; anders volgt een fout. Helling en virtuele versnelling worden samen in
één wegmodel verwerkt. De defaultversnelling 4 is neutraal; lichter/zwaarder schakelen
verandert de gemodelleerde belasting. Er worden geen 0x04-weerstandsniveaus tussendoor gestuurd.

`set_grade 0` betekent vlakke weg, met rol-/luchtweerstand en actieve versnelling.
Dit is geen vrijgave. `set_target_power 0` blijft wél vrijgave. Expliciet `sim` of
UDP `set_mode SIM` verlaat de hellingregeling en herstelt de oorspronkelijke vaste
weerstandstabel. Startgedrag blijft die oorspronkelijke SIM-regeling.

Helling wordt in ERG geweigerd (wrong_mode); schakel eerst bewust naar SIM. Dezelfde
5s-lease/heartbeat en 3s-feedbackbeveiliging gelden ook voor hellingregeling, inclusief
0%. Lees [SIMULATION.md](SIMULATION.md) voor het versnellingsmodel, de aannames,
de effectieve trainerhelling en de grenzen van de fysieke simulatie.

## Starten

1. Bewaar v0.14 als back-up. Pak deze ZIP in een nieuwe map uit.
2. Sluit oude bridges, ANT+-tests, Garmin Express en andere trainerapps.
3. Zet eerst de LINKER Zwift Ride aan, daarna de rechter. Activeer Garmin Broadcast Heart Rate.
4. Gebruik Python 3.12 en dubbelklik het enige startbestand `start_windows.bat`.
   Dit maakt `.venv` en installeert `requirements.txt`; internet is nodig bij installatie.
5. Start Godot apart. Alle bridgebediening blijft in één venster.

Geen driverwijziging, Zadig, WinUSB, meegeleverde DLL, EXE of apart ANT+-startvenster.
Opties: `--no-ant`, `--list`, `--trainer KICKR`, `--ride <linker-BLE-adres>` en
`--erg-ramp-w-per-s 1500`. Geef opties vanuit een opdrachtvenster aan `start_windows.bat` mee.

## Console

Start in SIM: 12 versnellingen, aanvankelijk versnelling 4, weerstandsniveaus
1.5..5.0 volgens `gear_config.json`. Bestaande Ride-knoppen blijven werken.

| Opdracht | Gedrag |
| --- | --- |
| `sim` | Reset vorige regeling, vraag controle opnieuw en herstel virtuele versnellingen. |
| `grade 5.25` | Activeer echte hellingsimulatie van 5.25% binnen SIM. |
| `grade -3 4` | Afdaling -3%, hellingsovergang maximaal 4 procentpunt/s vóór versnellingsfactor. |
| `target 500` | Stel geheel ERG-doel 0..1300 W in. Positief doel in SIM wordt alleen klaargezet. |
| `target 1300 1500` | Doel 1300 W, overgang 1500 W/s. Geen vaste 10W-limiet per stap. |
| `erg` | Schakel expliciet naar ERG met ingesteld doel; standaarddoel 100 W. |
| `target 0` | Vrijgave via FTMS Reset, ook vanuit SIM; toestand RELEASED. |
| `status` | Gewenst/bevestigd doel, bereik, lease en eventuele fout. |
| `stop` / `x` | Blokkeer sturing en probeer Reset; herstart nodig voor nieuwe sturing. |

Console en UDP wijzigen alleen de gewenste toestand. Uitsluitend de trainer-loop
verstuurt FTMS-opdrachten; een lock beschermt elke write/indication-transactie.
Een expliciete consolewijziging neemt bediening over van Godot; `status` neemt niets over.

## Trainergrenzen, vrijgave en ramping

Bij verbinden leest de bridge Target Power-ondersteuning (0x2ACC) en, indien
aanwezig, Supported Power Range (0x2AD8: minimum, maximum, increment).
Een positief doel moet zowel binnen 1..1300 W als het gemelde bereik vallen en
op het rooster `minimum + n * increment` liggen. Geen stille begrenzing/afronding.
Ontbreekt 0x2AD8, dan blijven aanvragen van 1..1300 W mogelijk met expliciet
onbekend trainerbereik; de trainer kan ze weigeren. Een aanwezige maar onleesbare
of ongeldige characteristic blokkeert positieve ERG, terwijl SIM beschikbaar blijft.
Zonder Target Power-feature is positieve ERG niet beschikbaar.

0 W is een apart vrijgaveverzoek. De bridge verstuurt **geen Set Target Power 0**,
maar gebruikt FTMS Reset (0x01), de al bestaande vrijgavefunctie. Daarna volgen
geen belastingcommando's tot een nieuwe positieve ERG-opdracht of `sim`.
Reset brengt de trainer naar zijn standaardtoestand en garandeert geen mechanische
nulweerstand of noodstop. Een niet bevestigde Reset wordt als fout gemeld.

Ramping is instelbaar van 1..10000 W/s, standaard 300. De eerste positieve
ERG-opdracht is het kleinste positieve geldige trainerdoel (1 W bij onbekend bereik).
Een hoge trainerminimumwaarde kan dus een eerste sprong vereisen. Daarna tellen
fractionele stappen op tot een geldig trainerincrement. Na een BLE-stagnatie wordt
maximaal 0.35 seconde rampbudget gebruikt, zonder grote inhaalsprong. De ingestelde
snelheid is een bovengrens bij normale ticks; incrementen en BLE-latentie kunnen
de overgang vertragen. Het aangevraagde einddoel wordt niet gewijzigd. Fysieke
haalbaarheid hangt ook van trainer, snelheid en cadans af.

## UDP en veiligheid

- Bestaande telemetrie: `127.0.0.1:51723`, iedere 100 ms.
- Interne ANT+-hartslag: `127.0.0.1:51724`.
- Nieuwe commandoserver: uitsluitend IPv4 `127.0.0.1:51725`; antwoord naar bronpoort.
- Volledig protocol: [UDP_PROTOCOL.md](UDP_PROTOCOL.md). Overdracht: [GODOT_HANDOFF.md](GODOT_HANDOFF.md).

ACK betekent gewenste toestand geaccepteerd, geen voltooide hardwareactie.
Vraag verse `status` op voor bevestigingen/fouten. Een nieuwere gewenste toestand
kan een nog niet uitgevoerde opdracht vervangen.

Bij positieve UDP-ERG of actieve UDP-hellingregeling moet Godot elke seconde een nieuwe `heartbeat` sturen.
Na vijf seconden zonder heartbeat/geldige nieuwe besturingsopdracht: sturing uit,
Reset geprobeerd, bewuste herstart nodig. Retries en status verlengen de lease niet.
Meer dan drie seconden zonder trainerdata/powerfeedback en BLE-verlies wissen
de doelen en starten de tijdelijke wacht-/herverbindingsroute. De verbinding en
metingen herstellen automatisch; oude belasting wordt niet teruggezet. Een
nieuwe wedstrijd/opdracht kan daarna sturen zonder bridgeherstart. Een echte
FTMS-protocolfout blijft wel een terminale blokkering van sturing.
Een FTMS-transactie heeft maximaal vijf seconden voor write plus indication;
een lopende transactie kan vrijgave vertragen. Cleanup-Reset kan daarna zelf nog
maximaal vijf seconden duren. Een bezette commandopoort voorkomt FTMS-start.

Stop met trappen bij onverwachte weerstand. Verbroken BLE of abrupt procesverlies
kan een laatste trainerinstelling achterlaten; software kan dan geen vrijgave
garanderen. Loopback beperkt toegang tot deze pc, zonder authenticatie tegen andere lokale processen.

## Behouden telemetrie

```json
{"type":"telemetry","valid":true,"power_w":170,"speed_kmh":39.0,"cadence_rpm":87,"sample_id":42,"heart_rate_bpm":143,"gear":4}
```

`valid` betreft KICKR-data. `gear` is de gekozen versnelling 1..12 in actieve SIM,
anders null; geen fysieke weerstandsbevestiging. Hartslag is integer of null en
vervalt na vijf seconden. `sample_id` en UDP-knopberichten blijven behouden.

## Diagnose en tests

`bridge.log` naast het script: maximaal drie bestanden van circa 1 MB, met
UDP-IDs/opdrachten, FTMS-write/indication, bereik en stopredenen. Bestaande BLE/ANT+
diagnose blijft in de console. Bij geen HR: controleer Broadcast Heart Rate,
USB-stick en conflicterende apps; probeer `--no-ant`. Bij geen Ride: zet eerst links aan.

Tests: `py -3.12 -m unittest discover -s tests -v`. Alleen standaardbibliotheek;
geen BLE/USB-pakketten of hardware nodig. Zie [VALIDATION.md](VALIDATION.md).

Bronnen: [Bluetooth SIG FTMS 1.0.1](https://www.bluetooth.com/specifications/specs/fitness-machine-service-1-0-1/)
en [GATT Specification Supplement](https://btprodspecificationrefs.blob.core.windows.net/gatt-specification-supplement/GATT_Specification_Supplement.pdf).

