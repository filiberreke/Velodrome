# Velodrome 250 X — compacte wedstrijd-HUD

Update van 23 oktober 2026, bovenop de versie met de nieuwe openingsmenu's.
Compleet Godot-bronproject. Open `project.godot` in Godot 4.7.2 en start met F5.
De nieuwe menu's en het zuinige wielvolgen zijn behouden.

## Standaardweergave

De race heeft nu drie rustige, donkerblauwe, semi-doorzichtige vlakken met
afgeronde hoeken, wit hoofdschrift en dezelfde turquoise accenten als de menu's.

- **Onderaan:** één brede balk. Links de actuele ronde/totaal, centraal de
  wedstrijdtijd met daarnaast de afstand tot de koppositie in meters, rechts
  jouw positie/totaal. Wanneer jij leidt, wordt jouw voorsprong op de volgende
  renner getoond. De klok stopt bij jouw eigen finish.
- **Linksboven:** jouw wattage in groot, daaronder hartslag en versnelling.
  Hartslag is voorlopig `— bpm`, zoals gevraagd.
- **Rechtsboven:** de miniatuurpiste met alle renners en daaronder maximaal
  zes plaatsen rond jouw positie in het klassement, inclusief jezelf.
  Jouw regel is turquoise gemarkeerd; jouw stip op de piste heeft een witte rand.
  De stipkleuren volgen de ingestelde truitjes waar die kleur beschikbaar is.

Het lijstje toont maximaal twee plaatsen vóór je en drie achter je; aan de kop
of staart schuift het venster op zodat er maximaal zes renners blijven staan.
`+12 m` betekent twaalf meter vóór jou, `-12 m` twaalf meter achter jou.
Bij een verschillende rondecredit staat de rondevoorsprong/-achterstand in de rij.
De positie volgt dezelfde officiële scratch-rangschikking als de uitslag.

Afstanden zijn gebaseerd op de al cumulatieve wedstrijdafstand. Rondecredits
worden niet nogmaals als 250 meter bijgeteld. Als credits verschillen, staat dat
ook apart naast de afstand tot de koppositie.

Alleen noodzakelijke start- of verbindingsmeldingen verschijnen nog in een kleine
balk bovenaan in het midden. Tijdens gewoon rijden is die verborgen. Zo blijft
zichtbaar wanneer je moet stilstaan of wanneer de trainerverbinding de rit pauzeert.

## Developer-HUD

Druk op **X** om het developerpaneel te tonen en nogmaals op **X** om het te sluiten.
Je kunt ook het kleine **X-knopje** in het vermogensvak gebruiken of de sluitknop
in het developerpaneel. Ingedrukt houden herhaalt de omschakeling niet.

Het scrollbare paneel bevat de eerdere uitgebreide uitlezingen: trainerstatus,
vermogens- en snelheidsgegevens, cadans, rijlijn, drafting, afstand tot finish,
rondemeldingen, volledige ranglijst, laatste rondetijden, AI-reserves en vermogens,
boost- en opname-informatie. De compacte HUD blijft eromheen staan.

De developerweergave staat standaard uit, is verborgen in de menu's en bij de
uitslag, en wordt bij een nieuwe race weer uitgezet. X verandert geen racegegevens.

## Versnelling

De aangeleverde game heeft nog geen eigen versnellingswaarde of schakelsysteem.
Daarom wordt **geen versnelling verzonnen**. Zonder beschikbare waarde staat er `—`.

De HUD kan de gekozen versnelling uit geldige trainertelemetrie lezen via
`gear` (bijvoorbeeld `12`) of `gear_label` (bijvoorbeeld `50×15`). Als beide bestaan,
heeft `gear_label` voorrang. De bridge moet deze waarde daadwerkelijk meesturen;
deze update voegt geen schakelsysteem of wijzigingen aan de losse bridge toe.
Bij ontbrekende gegevens of een verbroken verbinding staat er opnieuw `—`.
Hartslag blijft een placeholder, ook als andere telemetrie actief is.

## Installeren en proberen

1. Pak de ZIP uit in een nieuwe map en importeer `project.godot` in Godot 4.7.2.
2. Wacht op de assetimport en start met F5.
3. Kies Scratch en start een wedstrijd. De gewone HUD verschijnt na het menu.
4. Gebruik X een paar keer, ook met ingedrukte toets en met het X-knopje.
5. Controleer de zes omliggende plaatsen terwijl je naar voren of achteren rijdt.
6. Controleer de onderbalk bij een rondepassage, koppositie en jouw finish.
7. Controleer dat R de menu's heropent en de developerweergave weer uitstaat.

Neem eventuele persoonlijke `riders_config.cfg` en `strava_config.cfg` over uit
je bestaande project. Ze zijn niet in de ZIP opgenomen. De bestaande bediening
voor rijlijnen, camera, achteruitkijken, demo en trainer is behouden.

## Gewijzigde bestanden

- `race_hud.gd`: nieuwe standaard-HUD, miniatuurpiste/lijst en developerpaneel.
- `main.gd`: koppeling, X-bediening, presentatiegegevens en optionele versnellingsuitlezing.
- `minimap.gd`: leesbaardere piste/stippen en kleuren passend bij de renners.
- `tests/test_hud.gd`: HUD-regressies.
- `tests/test_menu.gd`: controleert nu dat de compacte HUD na Start verschijnt.

De AI, wedstrijdregels, draftingberekening, bankingsfysica en bestaande grafische
assets zijn niet aangepast. De vorige documentatie staat in `docs/README_menu_update.md`
en `docs/README_AI_update.md`. Oudere verificatiemappen horen bij die eerdere updates.

## Wat is getest

Met Godot 4.7.2 stable, headless:

- Schone assetimport en parsecontrole van `main.gd` met afhankelijkheden: geslaagd.
- Nieuwe HUD-test: geslaagd. Controle van ronde `2/6`, positie `6/12`, voor- en
  achterstand, tijdnotatie en minuutovergang, finishklok, zes omliggende renners,
  rondeprioriteit, minimapgegevens, placeholderwaarden en optionele versnelling.
- X aan/uit, negeren van toetsherhaling, aanwezigheid van oude debuggegevens,
  verbergen bij uitslag/menu en reset van developerstatus: geslaagd.
- Berekende HUD-grenzen passen binnen de logische 1920×1080-weergave; het
  rennerslijstje overlapt de onderbalk niet.
- Menunavigatie/start/reset, bestaande AI-, wielvolg-, scratch-/puntenregels en
  sprinterregressies: geslaagd.
- De echte wedstrijdlus opnieuw uitgevoerd met 8 deelnemers over 10 ronden en
  12 deelnemers over 50 ronden: geslaagd met dezelfde resultaten als vóór de HUD-update.
- Gewone hoofdscene met assets headless geladen: geslaagd.

Verschilpatch, behoudcontroles en logs staan in `hud_verification/`.

## Niet getest

**Geen visuele speeltest uitgevoerd.** De headless controles testen gegevens,
zichtbaarheidsstatus en berekende elementgrenzen, maar beoordelen geen gerenderd
beeld, daadwerkelijke leesbaarheid op jouw scherm of grafische prestaties.
Echte trainer-/Bluetoothgegevens, een live versnellingsbron, Strava en exports
zijn niet getest. Hartslag is bewust een placeholder.

Godot meldde hier een onleesbare systeemcertificaatstore en tijdens de scenetests
een niet beschikbare UDP-poort. De offline controles slagen; een live verbinding
is daarmee niet aangetoond.

## Automatische tests herhalen

Vanuit de projectmap in PowerShell, met zo nodig aangepast enginepad:

```powershell
$taskGodot = 'C:\Users\romboti\OneDrive - Cronos\Documenten\Priv\godot\Godot.exe'
& $taskGodot --headless --editor --path . --import
& $taskGodot --headless --path . --check-only --script res://main.gd
& $taskGodot --headless --path . --script res://tests/test_hud.gd --quit-after 200
& $taskGodot --headless --path . --script res://tests/test_menu.gd --quit-after 200
& $taskGodot --headless --path . --script res://tests/test_sprinter_economy.gd --quit-after 200
& $taskGodot --headless --path . --script res://test_x_scratch_ai.gd --quit-after 200
& $taskGodot --headless --path . --script res://test_x_wheel_follow.gd --quit-after 200
& $taskGodot --headless --path . --script res://test_scratch_lap_rules.gd --quit-after 200
& $taskGodot --headless --path . --script res://tests/test_race_rules.gd --quit-after 200
& $taskGodot --headless --path . --script res://tests/test_gameplay_headless.gd --quit-after 200
```

Zoek naar onder meer `RACE_HUD_OK`, `MENU_FLOW_OK` en `GAMEPLAY_HEADLESS_OK`, en
controleer de logs op eventuele scriptfouten. De scenetests verwachten een schoon
project zonder persoonlijke rennersconfiguratie.
