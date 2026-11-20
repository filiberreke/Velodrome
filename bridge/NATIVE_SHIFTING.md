# Experimentele native trainershifting

Deze versie staat in de branch `bridge/native-virtual-shifting`, gebaseerd op
`v0.3` commit `1a4b869`. Start op Windows met:

```bat
start_windows.bat --native-shifting
```

Op andere platformen, met de bestaande bridgeafhankelijkheden:

```sh
python bridge.py --native-shifting
```

Sluit de andere bridge, Zwift en andere trainerapps voordat je deze start. Ze
gebruiken dezelfde apparaten en UDP-poort. Het spel en de Ride-knoppen gebruiken
de bestaande koppeling.

## Twee trainerprotocollen

Trainers met native virtual shifting spreken een van twee varianten. De bridge
kiest automatisch op basis van de geadverteerde BLE-services:

| | Zwift hub | Wahoo FC82 |
|---|---|---|
| Service | `00000001-19ca-4651-86e5-fa29dcdd09d1` | `0xFC82` |
| Typische trainers | Zwift Hub en trainers die het Zwift-hubprotocol volgen | Wahoo KICKR-familie (o.a. KICKR CORE 2, waarschijnlijk KICKR CORE en KICKR v5+) |
| Handshake | `RideOn 02`, wacht op een `RideOn`-antwoord | `RideOn 02 03`, geen antwoord |
| Versnelling | `0x04` protobuf, veld 5 → 2 = ratio × 10000 | `0x3F` protobuf `{1: 1, 2: volgnummer, 4: {7: ratio × 10000}}` |
| Bevestiging ratio | `0x3C`-respons met data-object 520 | Alleen BLE-writebevestiging |
| Helling, Crr, Cw | `0x04` protobuf veld 4 (native) | FTMS Indoor Bike Simulation `0x11` |
| Bevestiging helling | Alleen BLE-writebevestiging | FTMS Control Point-indication |

`--native-protocol auto` (standaard) kiest Zwift hub als die service aanwezig is,
anders FC82. Forceer een variant met `--native-protocol zwift-hub` of
`--native-protocol wahoo-fc82`, bijvoorbeeld als een trainer beide adverteert.

Vind de bridge geen bruikbare service, dan toont hij de gevonden service-UUID's
voordat FTMS-control wordt aangevraagd. Hij schakelt de besturing uit en blijft
telemetry doorsturen zonder opnieuw te verbinden. Herstart daarna zonder
`--native-shifting`. FC82 vereist daarnaast dat de trainer FTMS-simulatie meldt,
omdat de helling via FTMS gaat.

## Gedrag

De helling blijft in beide varianten onafhankelijk van de gekozen versnelling; de
trainer rekent de overbrenging zelf door. Slipstream schaalt de
luchtweerstandscoëfficiënt. De bestaande hellingsramp en luchtweerstandsfilter
blijven actief.

De bestaande 12 versnellingen en startversnelling 4 zijn behouden. De ratio is
`24000 × gear_factor` uit `simulation_config.json`, waarbij 24000 een overbrenging
van 2,4 voorstelt (bereik 20151–38252 met de standaardconfiguratie). Dit is een
gekozen startconfiguratie, geen meting van de fysieke overbrenging en geen kopie
van Zwifts 24-versnellingentabel. Het protocol accepteert 7500–54899.

ERG, telemetry, Reset, UDP-eigendom, feedbackbewaking en herstel na
verbindingsverlies gebruiken de bestaande FTMS-infrastructuur. Alle trainerwrites
lopen via dezelfde trainerloop. Na een FTMS Reset (ERG, stop, watchdog) stuurt de
bridge bij terugkeer naar SIM opnieuw de handshake en de huidige ratio.

Robuustheid:

- Elke native write heeft, net als FTMS, een timeout van 5 seconden.
- Zwift hub: elk antwoord dat met `RideOn` begint geldt als handshake. De
  ratiorespons mag maximaal 2 eenheden afwijken, omdat Zwifts eigen tabel
  float-afgekapte waarden bevat (26099, 42399, 54899). Een ontbrekende of
  afwijkende respons onderbreekt de besturing.
- FC82: het volgnummer loopt per verbinding op. De bridge abonneert zich op de
  notify/indicate-kanalen van de FC82-service en logt de eerste 12 berichten,
  zodat een hardwaretest laat zien wat de trainer terugstuurt.
- Schrijven gebeurt met response als de characteristic dat ondersteunt, anders
  zonder.

## Status

`shifting_backend=zwift-native-experimental` en `native_protocol` (`zwift-hub` of
`wahoo-fc82`, leeg tot de eerste native tick). Verder `native_ratio_written`,
`native_ratio_confirmed` (alleen Zwift hub) en `native_grade_written_pct`.
`confirmed_simulation` is gevuld voor FC82 (FTMS-indication) en leeg voor Zwift
hub. Een geaccepteerde revisie bewijst geen fysiek gemeten weerstand.

## Hardwarevalidatie

Software getest; op hardware nog te bevestigen:

- welke service elke trainer adverteert (de bridge logt de lijst bij een mismatch);
- schakelgevoel en ratiobereik;
- Zwift hub: of de ratiorespons ongevraagd komt na elke ratio-write;
- FC82: of de trainer de ratio combineert met FTMS-simulatie van dezelfde client;
- ERG-overgangen en vrijgave via FTMS Reset na native commando's.

Meld bij een hardwaretest het trainermodel, de firmware, `native_protocol` en de
gelogde `Native ... notify`-regels.

## Terug naar de standaardbridge

Start zonder `--native-shifting`. De standaardroute blijft de oorspronkelijke
FTMS-besturing met het eigen versnellingsmodel.

## Protocolonderzoek

De encoder en koppeling zijn voor deze bridge geschreven. De geraadpleegde bronnen
beschrijven service-UUID's, protobufvelden, handshakes en de ratiorespons:

- [VirtualGears protocolbeschrijving en codec](https://github.com/sbroenne/VirtualGears/blob/8c960c90e1063e25990de54a21d5fc0b603b293d/Sources/VirtualGearsCore/ZwiftTrainerProtocol.swift)
  (Zwift hub). VirtualGears emuleert de trainerkant voor Zwift; het beschrijft
  wat Zwift verwacht, geen meting van een echte trainer.
- [FreeWheel Shift](https://github.com/pgmcgee/freewheel-shift/tree/bea2430d55cb0121d9247207ea868aaa06d9f3ab)
  (Wahoo FC82, getest op KICKR CORE 2).
- [Wahoo over native virtual shifting en ondersteunde trainers](https://support.wahoofitness.com/hc/en-us/articles/16865097915666-Virtual-shifting-with-Wahoo-smart-trainers).

Er is geen externe implementatie of gegenereerde protocolcode overgenomen.

## Softwaretests

```sh
PYTHONPATH=bridge:bridge/tests python -m unittest discover -s bridge/tests
```

De native tests controleren vaste wirevoorbeelden voor beide protocollen,
protocolkeuze, schakelen, ratiorespons (ook float-afgekapt), handshakevarianten,
timeouts, ontbrekende service zonder reconnect-lus, vrijgave, ERG en reconnect.
