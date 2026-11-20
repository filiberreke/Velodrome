# Experimentele native trainerbesturing

Deze versie staat in de branch `bridge/native-virtual-shifting`, gebaseerd op
`v0.3` commit `1a4b869`. Start op Windows met:

```bat
start_windows.bat --native-shifting
```

Op andere platformen, met de bestaande bridgeafhankelijkheden:

```sh
python bridge.py --native-shifting
```

Sluit de andere bridge voordat je deze start. Beide gebruiken dezelfde apparaten
en UDP-poort. Het spel en de Ride-knoppen gebruiken de bestaande koppeling.

## Gedrag

De experimentele modus zoekt de Zwift-trainerservice
`00000001-19ca-4651-86e5-fa29dcdd09d1`, abonneert zich op de
indication/notification-kanalen en wacht op de RideOn-handshake.
Daarna gaat de overbrengingsverhouding via een native gear-ratio-commando naar de
trainer. De bridge wacht op een bijbehorende ratiorespons.

Helling, rolweerstand en luchtweerstand gaan via native simulatiecommando's naar
de trainer. De helling blijft onafhankelijk van de gekozen versnelling.
Slipstream schaalt de luchtweerstandscoëfficiënt. De bestaande hellingsramp en
luchtweerstandsfilter blijven actief.

De bestaande 12 versnellingen en startversnelling 4 zijn behouden om de hardwaretest
vergelijkbaar te houden. De ratio is `24000 × bestaande gear_factor`, waarbij
24000 een overbrenging van 2,4 voorstelt. Dit is een gekozen startconfiguratie,
geen meting van jouw fysieke overbrenging en geen kopie van Zwifts 24-versnellingentabel.

ERG, telemetry, Reset, UDP-eigendom, feedbackbewaking en herstel na verbindingsverlies
gebruiken de bestaande FTMS-infrastructuur. Alle trainerwrites lopen via dezelfde
trainerloop. Een ontbrekende service, geweigerde handshake of ontbrekende
ratiorespons onderbreekt de experimentele besturing.

## Ondersteuning en bevestiging

Dit is een softwarematig geteste eerste implementatie. De oudere FC82-service
heeft een andere handshake en commandostructuur en is nog niet ondersteund.
Op zo'n trainer toont de bridge een melding voordat FTMS-control wordt aangevraagd.

De ratiorespons bevestigt de door de trainer gemelde overbrenging.
Voor het simulatiecommando kennen we alleen de BLE-writebevestiging.
Daarom blijft `confirmed_simulation` leeg. Status toont
`native_ratio_confirmed`, `native_grade_written_pct` en
`shifting_backend=zwift-native-experimental`. Een geaccepteerde revisie bewijst
geen fysiek gemeten weerstand.

Test op de echte KICKR blijft nodig voor serviceondersteuning, schakelgevoel,
helling, ERG-overgangen en vrijgave via FTMS Reset.

## Terug naar de backup

Gebruik je bestaande v0.3-bridge, of start deze checkout zonder
`--native-shifting`. De standaardroute blijft de oorspronkelijke FTMS-besturing.

## Protocolonderzoek

De encoder en koppeling zijn voor deze bridge geschreven. De geraadpleegde bronnen
beschrijven de service-UUID's, protobufvelden, handshake en ratiorespons:

- [VirtualGears protocolbeschrijving en codec](https://github.com/sbroenne/VirtualGears/blob/8c960c90e1063e25990de54a21d5fc0b603b293d/Sources/VirtualGearsCore/ZwiftTrainerProtocol.swift).
- [FreeWheel Shift voor de afwijkende FC82-protocolvariant](https://github.com/pgmcgee/freewheel-shift/tree/bea2430d55cb0121d9247207ea868aaa06d9f3ab).
- [Wahoo over native virtual shifting en ondersteunde trainers](https://support.wahoofitness.com/hc/en-us/articles/16865097915666-Virtual-shifting-with-Wahoo-smart-trainers).

Er is geen externe implementatie of gegenereerde protocolcode overgenomen.

## Softwaretests

```sh
PYTHONPATH=bridge:bridge/tests python -m unittest discover -s bridge/tests
```

De native tests controleren vaste wirevoorbeelden, afzonderlijke ratio en helling,
handshake, ratiorespons, ontbrekende service, timeout, vrijgave, ERG en reconnect.
