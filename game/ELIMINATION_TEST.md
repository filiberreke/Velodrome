# Afvalling: gedeelde rijlijnen en inhalen

Gebouwd op GitHub main `8d894fb28e9c5a90396048e153c2c500479b30fe` (2 november 2026), inclusief de elf spelersrijlijnen van PR #18.

Afvalling gebruikt dezelfde handmatige rijlijnbeweging als scratch en puntenkoers.
De bestaande AI-verkeersanticipatie en rijlijnkeuze staan nu eenmaal in
`x_scratch_ai.gd`: `_traffic_power` en `_update_rider_line`. Scratch, puntenkoers
en afvalling roepen deze geërfde routines aan. De puntsprint behoudt zijn eigen
positioneringssignaal; afvalling gebruikt de volgende jurylijn.

`elimination_traffic.gd` en `elimination_assist.gd` zijn verwijderd. Er is geen
aparte afvallingscontrole meer die posities terugzet, snelheid begrenst na de
fysicastap of handmatig invoegen tegenhoudt. De ongebruikte inhaalhulpstatus en
blokkeringsmeldingen zijn weg. De menuknop was op deze main al verwijderd.
De algemene vereenvoudigingen van scratch/puntenkoers gelden ook voor afvalling:
dit is geen harde botsingssimulatie; fietsen kunnen tijdelijk visueel overlappen.

Behouden: achterwieljurering, jurylijntijden, fotofinishaanroep en camera,
eliminaties, finalisten, HUD, meldingen bij afvallen en de volledige terugrijroute.
De eigen vermogensvraag, startvraag, CP/W′ en vermoeidheid van de afvallings-AI
blijven behouden; alleen de verkeersafhandeling is gedeeld.

## Gerichte tests

```sh
godot --headless --path game --script res://tests/test_shared_race_traffic.gd
godot --headless --path game --script res://tests/test_elimination_gameplay.gd
godot --headless --path game --script res://tests/test_elimination_rules.gd
godot --headless --path game --script res://tests/test_elimination_corrections.gd
godot --headless --path game --script res://tests/test_player_lanes.gd
godot --headless --path game --script res://tests/test_elimination_menu_fix.gd
```

De nieuwe integratietest vergelijkt bij gelijk vermogen de fysieke beweging in
alle drie de disciplines: dicht volgen/inhalen, vrij sturen naast een renner,
banking, een rondeverschil en gelijke beginposities. Ook getest: alle AI-renners
passeren een stilstaande speler bij 4/12/16 deelnemers, achterwielbeslissing,
fotoaanroep, HUD-melding en volledig uitrijden tot stilstand bij boxen/toegangszone.

Volledige afvalling met 4/12/16 deelnemers eindigt correct, met precies N−2
eliminaties en twee finalisten. De oude grens van 65 m voor pelotonspreiding is
geen vereiste meer van de gedeelde verkeerslogica. De test blijft spreiding
meten en controleert finish, eindige fysica, energiegrenzen en startvermogen.
De gemeten AI-spreiding tijdens rustig rijden is 18,4 / 72,3 / 95,4 m; de
vermogensvraag is in 480 verkeersvrije vergelijkingen exact gelijk aan main.

## Werkelijk uitgevoerde verificatie

Zie `verification/shared_traffic/validation.json` voor de afzonderlijke suites.
18 suites halen hun assertions. De bestaande binnenbocht-A/B-test, menutest en
startlijsttest falen ook op de oorspronkelijke code. De acht scratch/puntenkoers-
A/B-races leveren exact dezelfde meetrapporten voor en na de refactor; het
binnenbochtcriterium faalt dus identiek. De menutest heeft dezelfde zeven fouten;
de startlijsttest dezelfde twee verouderde verwachtingen over de tijdritcategorie.
Deze tests zijn niet aangepast om die fouten te verbergen.

Godot 4.7.2 is headless gebruikt met een bestaande assetimportcache. De eerste
editorimport meldde ontbrekende Blenderconfiguratie; verse .blend-import is niet
gevalideerd. De ontbrekende woordmerkcache is aangevuld uit de bestaande lokale
cache. Certificaatstore-/asset-UID-meldingen blijven zichtbaar. Intro/startlijst
geven bestaande null-material-meldingen bij opruimen. Geen handmatige visuele
speeltest, pixelcontrole van de finishfoto of fysieke trainer/Ride-test uitgevoerd.
