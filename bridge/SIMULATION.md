# Echte helling en virtuele versnellingen — v0.15

## Gebruik

Startgedrag blijft de oorspronkelijke SIM-regeling met vaste weerstandsniveaus.
Stuur binnen SIM via 127.0.0.1:51725:

```json
{"type":"command","v":1,"id":"ride-1","command":"set_grade","grade_pct":5.25,"ramp_pct_per_s":2}
```

Dit schakelt na Reset + Request Control over naar FTMS Indoor Bike Simulation
Parameters (opcode 0x11). Helling is dus een echte wegmodelparameter, geen optelling
bij een arbitrair weerstandsniveau. De bridge controleert eerst ondersteuning via
target-feature bit 13. Tijdens de simulatie wordt geen Set Target Resistance 0x04
verstuurd. Alle transacties blijven geserialiseerd in dezelfde trainer-loop.

Console-equivalent: `grade 5.25`, optioneel `grade 5.25 2` met ramp in procentpunt/s.
Vraag `status` op voor het gewenste en bevestigde resultaat. `sim` / set_mode SIM
herstelt de oude weerstandstabel. Helling in ERG wordt geweigerd; ERG blijft op watts sturen.

## Hoe de versnellingen werken

FTMS 0x11 bevat wegparameters, geen gestandaardiseerd virtueel versnellingsnummer.
Daarom gebruikt de bridge een expliciet benaderingsmodel voor de gewenste pedaalbelasting.
Dit is geen native Wahoo/Zwift-virtuele overbrenging. De Ride-knoppen en de gekozen
versnelling 1..12 blijven hetzelfde; hun effect in de hellingregeling verandert.

`simulation_config.json` bevat de twaalf factoren, rolweerstand, luchtweerstand en ramps.
Standaard is versnelling 4 neutraal (factor k=1); de factoren lopen van circa 0.84
tot 1.59, ongeveer 6% verschil per versnelling. De oorspronkelijke `gear_config.json`
blijft uitsluitend voor de oude regeling met vaste weerstandsniveaus gelden.

Neem virtuele snelheid `v_virtual = k * v_trainer`. Het model vraagt voor eenzelfde
fysieke trainersnelheid wegkrachten maal k en aerodynamische belasting maal k³,
om het verschil in benodigd vermogen bij virtueel zwaarder/lighter schakelen te benaderen.
Daaruit worden effectieve FTMS-parameters berekend:

```text
theta = atan(game_grade_pct / 100)
theta_effective = asin(k * sin(theta))
trainer_grade_pct = 100 * tan(theta_effective)
trainer_Crr = Crr * k * cos(theta) / cos(theta_effective)
trainer_Cw = Cw * k^3
wind_speed = 0
```

Bij de neutrale versnelling 4 gaat de spelhelling ongewijzigd naar de trainer;
bij andere versnellingen wijken effectieve helling en coëfficiënten af. Bijvoorbeeld
5% met k=1.06 wordt circa 5.30% effectieve trainerhelling, plus aangepaste Crr/Cw.
`state.grade_pct` houdt altijd de gevraagde spelhelling. `effective_grade_pct` toont
het berekende einddoel. `confirmed_simulation` toont exact de door FTMS bevestigde,
gekwantiseerde parameters. Er wordt geen trainerhelling boven de softwarelimiet stil begrensd.

Dit model veronderstelt dat de trainer deze FTMS-wegparameters volgens een normaal
wegweerstandsmodel gebruikt. Massa, snelheidsinterpretatie en interne firmwarelogica
zijn niet gekalibreerd. De Godot-snelheid wordt niet door deze bridge aangepast;
voor een fysiek consistent spelmodel moet Godot dezelfde betekenis van virtuele
versnelling/snelheid hanteren. Dit document definieert geen HUD of spelvorm.

## Grenzen en overgang

De inkomende spelhelling is softwarematig begrensd tot -20..20%, met maximaal twee
decimalen. Dit is geen claim over de maximale fysieke KICKR-helling. Door de
versnellingsfactor kan de effectieve trainerhelling buiten -20..20% vallen (tot
circa 33% bij de standaard hoogste factor). Ze blijft binnen de FTMS-encoding.
De trainer kan zo'n aanvraag weigeren of fysiek niet realiseren. Er is geen
stilzwijgende omzetting naar een door de bridge verondersteld trainermaximum.
Een FTMS-weigering veroorzaakt een terminale fout en Reset-poging. Een ACK bewijst
niet dat de helling fysiek gerealiseerd wordt. 0x2AD5 wordt niet als 0x11-grens gebruikt.

Bij negatieve helling kan de weerstand afnemen. De bridge kan de trainer niet
verplichten actief aan te drijven; een afdaling is geen garantie van motoraandrijving.
Op 0% blijven rol-/luchtweerstand en het versnellingsmodel actief: 0% is niet vrijgave.
Gebruik `set_target_power` met 0 W of `stop` voor de al gedocumenteerde Reset-vrijgave.

Weghelling verandert standaard met maximaal 2 procentpunt/s; instelbaar per set_grade
van 0.1..100 via ramp_pct_per_s. De factor verandert standaard met maximaal 0.5/s
(configuratie gear_factor_per_s, bereik 0.01..5). Dit voorkomt directe sprongen bij
schakelen. De effectieve trainerhelling kan sneller veranderen door de factor;
de opgegeven weghellingsramp is dus geen bovengrens van de effectieve trainerhelling.
De beginreferentie bij inschakelen is 0% en factor 1. Maximaal 0.35 s rampbudget
per tick voorkomt een inhaalsprong na BLE-stagnatie. Encodingresoluties worden
toegepast op effectieve parameters, niet op de aangevraagde spelhelling.

Ongeldige configuraties die buiten het FTMS-bytebereik zouden vallen worden bij
start geweigerd, zonder clamp. Standaardwaarden Crr=0.004, Cw=0.51 zijn modelaannames,
geen meting of calibratie van jouw KICKR/fiets.

## Veiligheid en status

UDP-hellingregeling vereist elke seconde een nieuwe heartbeat, ook bij 0% of
constante helling. Na vijf seconden leaseverlies, drie seconden zonder trainer-
of powerfeedback, BLE-verlies of FTMS-fout stopt de sturing met Reset-poging en
herstartverplichting. Ride-drukken, status en retries verlengen de lease niet.
Console kan expliciet overnemen. Een lopende FTMS-transactie kan de vrijgave
vertragen zoals beschreven in UDP_PROTOCOL.md. Mechanische vrijgave kan niet gegarandeerd worden.

Referentie: [Bluetooth SIG FTMS 1.0.1](https://www.bluetooth.com/specifications/specs/fitness-machine-service-1-0-1/)
en [FTMS-test suite: procedure 0x11 / target-feature bit 13](https://files.bluetooth.com/wp-content/uploads/dlm_uploads/2024/10/FTMS.TS_.p6.pdf).
Het versnellingsmodel hierboven is een implementatiekeuze van deze bridge.
Hardwarewerking en rijgevoel van v0.15 zijn nog niet getest.
