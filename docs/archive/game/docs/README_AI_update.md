# Velodrome 250 X — zuinig wielvolgen voor sprinters

De actuele AI heeft ook een [voorkeur voor de binnenbaan](README_inside_lane.md): zonder bruikbaar wiel of andere tactische reden voor een hogere lijn gaat een renner naar binnen zodra de route vrij is, ook tijdens het optrekken. De onderstaande historische wielvolgupdate blijft van toepassing.

Update van 23 oktober 2026, gebaseerd op `velodrome_export_2310.zip` en
`velodrome_250_X_simulator_sprinters_zuinig_wielvolgen_100x50.zip`.
Dit is een compleet Godot-bronproject, geen gecompileerde Windows-game.

## Starten

1. Pak deze ZIP uit in een **nieuwe map**. Bewaar je huidige speelbare versie.
2. Importeer `project.godot` in Godot 4.7.2 en laat de assets importeren.
3. Start `main.tscn` met F6 of het project met F5. Kies Scratch.
4. Neem desgewenst je eigen `riders_config.cfg` en `strava_config.cfg` over uit je
   bestaande project. Persoonlijke configuraties zitten niet in dit pakket.
5. Zonder trainer kun je de bestaande demomodus gebruiken; pijltjes omhoog/omlaag
   wijzigen het demovermogen. A/D of links/rechts wisselen rijlijn, C wisselt camera,
   B ingedrukt houden kijkt achteruit, R reset. De bestaande trainerbridge is apart nodig.

## Wat is veranderd

De productieaanpassing staat uitsluitend in `x_scratch_ai.gd`:

- Een sprinter in gewone volgmodus onthoudt zijn voorganger. Hij behoudt een
  actief, goed uitgelijnd wiel op 1,4–8 m; anders krijgen nabije beschutte wielen
  voorrang boven een iets dichter wiel op een andere lijn. Kandidaten zijn binnen 21 m.
- Kleine correcties richten zich op circa 2,7 m met een rustige sluitingsregeling
  `0,18 × (gat − 2,7)`. Vanaf een gat groter dan 5,5 m mag hij duidelijker bijtrekken.
- Het extra vermogen boven CP hangt af van de actuele W'-reserve en het gat:

| Gat | Reserve >28% | Reserve >13% t/m 28% | Reserve ≤13% |
|---|---:|---:|---:|
| ≤4 m | +60 W | +25 W | +0 W |
| >4 t/m 6 m | +115 W | +75 W | +20 W |
| >6 m | +165 W | +90 W | +0 W |

Deze bedragen zijn grenzen voor de aanvraag bij 80% AI-moeilijkheid. De bestaande
moeilijkheidsschaal, vermogenscurve, vermoeidheid en W'-fysica worden daarna toegepast.
Er komt geen gratis snelheid of energie bij. Bij een klein gat mag het vermogen
ook verder zakken dan de oude ondergrens van 65% CP.

- Uitlijnen achter een wiel mag voor deze sprinters vanaf 1,55 m in plaats van 2,1 m.
  De bestaande lokale conflictdetectie heeft voorrang. Een lopende aflosbeweging
  naar boven wordt niet door de laatste uitlijncontrole ongedaan gemaakt.
- De aanvallerbasis is gelijkgetrokken met de simulator en de opdracht: **CP 250 W**.
  In het aangeleverde Godot-script stond nog **224,37 W**. Sprinter-CP blijft 235 W;
  W', piekvermogen en de vormfactor blijven behouden.

De zuinige regeling geldt voor sprinters in `MODE_DRAFT` vóór hun sprint, niet
voor demarrages, actieve achtervolgingen, solo-inspanningen of kopbeurten. De
bestaande FINAL_750-positionering en sprintaanvraag houden hun prioriteit.
Voor ontwikkelaars: `economical_sprinter_wheels = false` schakelt alleen de nieuwe
sprinterregeling uit; CP 250 W blijft ook dan actief. Dit is geen nieuwe menuoptie.

## Behouden en vergeleken

`main.gd`, `scratch_lap_rules.gd` en de bestaande grafische scripts/assets zijn
byte voor byte behouden ten opzichte van de aangeleverde Godot-ZIP. Daardoor blijven
zes rijlijnen, snelheidsafhankelijke drafting, AI-start, demarragereacties,
achteruitkijkcamera, sprintfysica, trainerbesturing en rondewinst/-verliesregels intact.
De bestaande Godot-regel voor rondecontact is behouden; de ruimere experimentele
Python-reüniezone is niet overgenomen.

De Godot-acquisitieondergrens van 1 m en de bestaande geometrische bescherming zijn
behouden; de Python-simulator laat sommige kandidaten al vanaf 0,35 m toe. Het is
dus een gerichte gedragsoverdracht naar de bestaande game, geen identieke simulator.

Drie bestaande testverwachtingen zijn gecorrigeerd: de binnenste rijlijn heet nu
1,18 m, en twee oudere puntentests verwachtten een onjuiste geïnterpoleerde
finishvolgorde respectievelijk een onjuiste rangschikking op punten. De bijbehorende
productieregels zijn niet veranderd. De oorspronkelijke documentatie staat in
`docs/README_voor_update.md`; overige meegeleverde oudere patchnotities zijn historisch.

## Wat daadwerkelijk getest is

Met de lokaal beschikbare **Godot 4.7.2 stable**:

- Import van een schone projectkopie zonder meegeleverde `.godot`-cache; geslaagd.
- GDScript-parsecontrole van `main.gd`, inclusief afhankelijkheden; geslaagd.
- Bestaande AI-, wielvolg- en scratch-rondecontroletests; geslaagd.
- De acht bestaande puntentests na bovenstaande verwachtingscorrecties; geslaagd.
- Nieuwe regressies voor wielbehoud, vermogensgrenzen, W'-verbruik, cirkelgeometrie,
  gefinishte voorgangers, conflicten, demarragereactie en sprintprioriteit; geslaagd.
- De echte `main.gd`-wedstrijdlus: **8 deelnemers × 10 ronden** en
  **12 deelnemers × 50 ronden**, stilstaande start, vaste vormfactor 1,0,
  80% moeilijkheid, constante demospeler op 300 W, stappen van 0,1 s.
  Alle deelnemers finishen; snelheden/afstanden blijven eindig en W' blijft begrensd.
  Ook de startcontrole, snelheidsafhankelijke draft en B-toetsstatus slagen.
  Positielijsten bij elke tien ronden van de leider staan in
  `tests/headless_snapshots.json`, `verification/peloton_snapshots.csv` en
  `verification/PELOTON_SNAPSHOTS.md`.
- De gewone hoofdscene is daarnaast headless geladen met de echte assets.

De wedstrijdtest onderdrukt alleen de opbouw van visuele renners, netwerkstart,
ritbestanden en finishfoto-opname; de race-update, rijlijnbeweging, drafting,
weerstand, banking en rondeadministratie komen uit de productiecode.

De **100 gepaarde Python-vergelijkingen** zijn opnieuw uitgevoerd: 100 baseline +
100 verbeterde races, seeds 1001–1100, telkens 50 ronden. De samenvatting is exact
gelijk aan de aangeleverde resultaten. Onder andere: sprinterdraft 46,99 → 51,48%,
W' bij eigen ronde 45 8,02 → 10,39%, gemiddelde vermogen 259,26 → 253,87 W.
Dit zijn Python-resultaten, geen Godot-balansstatistieken. Scripts en resultaten
staan in `verification/python_reference/` en `verification/python_100_rerun/`.

## Wat niet bewezen of niet getest is

- Geen visuele speeltest, camerabeeldbeoordeling, grafische prestatietest,
  echte KICKR/Bluetooth-sessie, Strava-upload of FIT-export uitgevoerd.
- De twee Godot-wedstrijden zijn functionele rooktests met een grotere tijdstap
  dan normaal spel; geen statistisch bewijs voor betere balans of dezelfde uitslagen
  als in Python. De 300 W-demospeler wint beide races en er ontstaat aanzienlijke
  spreiding. Visuele beoordeling en verdere balansafstelling blijven nodig.
- In de Python-vergelijking stijgt de gemiddelde totale spreiding van 198,16 naar
  227,65 m. Zuinig volgen garandeert dus geen compacter peloton.
- De Python-rondecontroletests blijven **2/4 geslaagd**. `test_lap_gain_wins_race`
  en `test_rider_can_draft_after_lap_gain` falen bij hun seed omdat daar geen
  rondewinst ontstaat. Dit staat ook in de aangeleverde simulator-README. Deze
  bestaande fouten zijn niet gebruikt om de werkende Godot-regels te vervangen.
- Godot meldt in deze omgeving dat de systeemcertificaatstore niet leesbaar is.
  De offline tests slagen; netwerkfunctionaliteit is daarmee niet geverifieerd.
- De bestaande rondeadministratie kent per renner maximaal één winst-/verliescredit.
  Er is geen nieuw commissaris- of botsingssysteem toegevoegd.

## Tests zelf uitvoeren

Open PowerShell in de uitgepakte projectmap. Pas het enginepad eventueel aan:

```powershell
$taskGodot = 'C:\Users\romboti\OneDrive - Cronos\Documenten\Priv\godot\Godot.exe'
& $taskGodot --headless --editor --path . --import
& $taskGodot --headless --path . --check-only --script res://main.gd
& $taskGodot --headless --path . --script res://test_x_scratch_ai.gd --quit-after 200
& $taskGodot --headless --path . --script res://test_x_wheel_follow.gd --quit-after 200
& $taskGodot --headless --path . --script res://test_scratch_lap_rules.gd --quit-after 200
& $taskGodot --headless --path . --script res://tests/test_race_rules.gd --quit-after 200
& $taskGodot --headless --path . --script res://tests/test_sprinter_economy.gd --quit-after 200
& $taskGodot --headless --path . --script res://tests/test_gameplay_headless.gd --quit-after 200
& $taskGodot --headless --path . --quit-after 20
```

Controleer de succesmeldingen en eventuele `SCRIPT ERROR`/assertions, niet alleen
de exitcode: sommige oude Godot-tests stoppen na een fout met een misleidende exitcode.
De nieuwe wedstrijdtest overschrijft `tests/headless_snapshots.json`.

Python-controles, vanuit `verification/python_reference` met Python 3:

```powershell
python -m unittest -v test_lap_rules.py
python compare.py --races 100 --seed 1001 --workers 4 --out ../eigen_python_100
```

De eerste opdracht heeft de twee hierboven genoemde bekende fouten.

## Handmatige acceptatietest

1. Speel Scratch met 8 en 12 deelnemers, over 10 en 50 ronden, eerst op 80% AI.
   Controleer de stilstaande start: alle AI moet zelfstandig vertrekken.
2. Observeer sprinters vanuit de brede of zijcamera. Op korte gaten moet een
   bruikbaar wiel langer behouden blijven; grotere gaten mogen actief dichtgereden worden.
3. Demarreer vanuit het peloton en vanuit een andere rijlijn. Controleer of nabije
   capabele AI reageert en jouw wiel kan zoeken, zonder onmogelijke lijnwissels.
4. Houd B ingedrukt en laat los; controleer het achteruitbeeld en de terugkeer naar
   de gekozen camerastand. Probeer alle zes rijlijnen.
5. Controleer de laatste drie ronden en de eindsprint. Sprinters mogen hun
   spaargedrag verlaten zodra de bestaande individuele sprint begint.
6. Controleer bij een werkelijke rondewinst/-verlies de credit en eindrangschikking.
   Vergelijk niet alleen de aankomsttijd. Test de trainer en eventuele exports apart.

`verification/changes.patch` bevat de codeverschillen; `verification/manifest.json`
legt de bronhashes en het behoud van bestaande bestanden vast. Tijdelijke Godot-caches,
geneste export-ZIP's en persoonlijke configuraties zijn niet mee verpakt.
