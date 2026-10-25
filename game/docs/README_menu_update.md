# Velodrome 250 X — nieuwe openingsmenu's

23 oktober 2026. Bouwt voort op `velodrome_250_X_zuinig_wielvolgen_2310.zip`.
Compleet Godot-bronproject; open `project.godot` met Godot 4.7.2.

## Nieuwe opening

**Pagina 1 — spelkeuze.** Zes grote beeldkaarten, in deze volgorde:
Scratch, Achtervolging, Ploegenachtervolging, Puntenkoers, Ploegkoers en Keirin.
Klik op een kaart om door te gaan. Muis, Tab en Enter worden ondersteund.

Iedere afbeelding is een eigen 3D-compositie met de bestaande renner-/fietsrig,
kleding en houten baantextuur van het spel. De achtervolging toont tegenstanders,
de ploegenachtervolging twee treinen, de puntenkoers een sprint aan de lijn,
de ploegkoers duo's en keirin een trein achter een gangmaker. De gangmaker gebruikt
het bestaande fiets-/rennermodel met een klein motorblok; er is geen nieuw gedetailleerd
dernymodel toegevoegd. De beelden worden eenmaal in afzonderlijke viewports gerenderd.

**Pagina 2 — wedstrijdinstellingen.** Bij Scratch kies je deelnemers, ronden,
AI-sterkte en het demo-startvermogen. Met ‘Spelvormen’ of Escape ga je terug.
De ingevulde waarden blijven bewaard. ‘Start wedstrijd’ opent de bestaande
trainer-/stilstandscontrole en aftelling.

Alleen **Scratch is momenteel speelbaar**, zoals in de vorige versie. De andere
kaarten geven een korte uitleg met ‘Binnenkort’ en hebben geen actieve startknop.
Deze update voegt hun wedstrijdregels niet toe en start niet stilzwijgend een
Scratch wanneer je een andere kaart kiest.

## Achtergrond

Tijdens de menukeuze staat de camera op een vast overzicht van het stadion.
Renners, tribune- en middenterreinpubliek, vlagofficial, dynamisch scorebord en
wedstrijd-HUD zijn verborgen. Stoelen, tribunes, baan, dak en middenterreinprops
blijven staan: het is het bestaande stadion, nu leeg tijdens de menu's.
Na het bevestigen van Scratch worden renners en publiek hersteld. R reset terug
naar de nieuwe spelkeuzepagina. De beeldinstellingen blijven via F10 beschikbaar.

## Installeren

1. Pak de ZIP uit in een nieuwe map.
2. Importeer `project.godot` in Godot 4.7.2 en wacht op de assetimport.
3. Start het project met F5. Kies Scratch, stel de wedstrijd in en druk Start.
4. Kopieer eventueel je bestaande persoonlijke `riders_config.cfg` en
   `strava_config.cfg` naar deze map. Ze zijn niet meegeleverd of overschreven.

De trainerbridge blijft apart nodig. Zonder trainer kun je demo rijden; het
startvermogen stel je nu op pagina 2 in. Tijdens de rit blijven de bestaande
toetsen werken: pijlen omhoog/omlaag voor demovermogen, A/D voor rijlijn,
C voor camera, B ingedrukt voor achteruitkijken en R voor reset.

## Bestanden

- `race_menu.gd`: beeldkaarten, navigatie, vervolgpagina en invoervelden.
- `mode_preview.gd`: zes illustraties uit bestaande game-assets.
- `main.gd`: koppeling van de menu's, verborgen race-HUD, stadioncamera en start/reset.
- `crowd_kit.gd` en `infield_details.gd`: markering van mensen om ze tijdens menu's
  te verbergen en daarna te herstellen.
- `tests/test_menu.gd`: controle van navigatie, schermgrenzen, invoer en start/reset.

Het zuinige wielvolgen uit de vorige update is behouden. `x_scratch_ai.gd`,
`scratch_lap_rules.gd`, de fysica-/draftingfuncties en bestaande assets zijn
ongewijzigd ten opzichte van die update. Er zijn geen AI- of balanswijzigingen.
De instellingen behouden de bestaande grenzen: 6–12 deelnemers, 1–30 ronden,
30–100% AI en 0–900 W demo-startvermogen.

## Uitgevoerde controles

Met Godot 4.7.2 stable, zonder grafisch venster:

- Schone assetimport en GDScript-parsecontrole: geslaagd.
- Nieuw menutestscript: geslaagd. Alle zes kaarten en aparte 3D-werelden bestaan;
  de kaart- en navigatiegrenzen passen in de logische 1920×1080-weergave.
- Alle kaarten openen hun vervolgpagina; teruggaan bewaart de instellingen;
  onvoltooide spelvormen starten niet. Scratch geeft deelnemers, ronden,
  moeilijkheid en demo-startvermogen door aan de bestaande startprocedure.
- Achtergrondrenners, publiek en race-HUD zijn verborgen in het menu en worden
  hersteld bij Start. Reset opent opnieuw een schone spelkeuze.
- Bestaande AI-, wielvolg-, ronde- en puntentests en de sprinterregressies: geslaagd.
- Echte wedstrijdlus opnieuw uitgevoerd met 8 deelnemers over 10 ronden en
  12 deelnemers over 50 ronden; beide slagen met dezelfde resultaten als vóór
  de UI-wijziging. De 50-rondentest stelt dit programmatisch in; de menu-invoer
  behoudt de bestaande bovengrens van 30 ronden.
- Hoofdscene met assets headless geladen: geslaagd.

Logbestanden, verschilpatch en manifest staan in `ui_verification/`.
De oudere AI-documentatie staat in `docs/README_AI_update.md`; de oorspronkelijke
AI-testgegevens staan nog in `verification/` en betreffen de vorige update.

## Nog handmatig te beoordelen

**Er is geen visuele speeltest uitgevoerd.** Headless controle bevestigt de
menulogica en berekende elementgrenzen, maar niet de daadwerkelijk gerenderde
beelden, cameracompositie, leesbaarheid op verschillende schermen of GPU-prestaties.
Ook zijn geen echte trainer, Bluetooth, Strava-upload of exports getest.

Controleer na het openen:

1. Verschijnt een leeg stadion achter de zes kaartbeelden, zonder race-HUD?
2. Zijn de zes illustraties, namen en statussen duidelijk op jouw resolutie?
3. Kun je met muis en toetsenbord een kaart kiezen en teruggaan?
4. Start Scratch met jouw instellingen en keert het normale racebeeld terug?
5. Opent R na een rit opnieuw de spelkeuze, met het stadion weer leeg?
6. Werken F10, de racecamera en B-achteruitkijken nog zoals gewenst?

Godot meldde in deze omgeving een onleesbare systeemcertificaatstore en bij de
menutest een niet beschikbare UDP-poort. Dit verhinderde de offline controles niet;
een werkende live trainerverbinding is hiermee niet aangetoond.

## Tests herhalen

Open PowerShell in de uitgepakte projectmap en pas het enginepad zo nodig aan:

```powershell
$taskGodot = 'C:\Users\romboti\OneDrive - Cronos\Documenten\Priv\godot\Godot.exe'
& $taskGodot --headless --editor --path . --import
& $taskGodot --headless --path . --check-only --script res://main.gd
& $taskGodot --headless --path . --script res://tests/test_menu.gd --quit-after 200
& $taskGodot --headless --path . --script res://tests/test_sprinter_economy.gd --quit-after 200
& $taskGodot --headless --path . --script res://test_x_scratch_ai.gd --quit-after 200
& $taskGodot --headless --path . --script res://test_x_wheel_follow.gd --quit-after 200
& $taskGodot --headless --path . --script res://test_scratch_lap_rules.gd --quit-after 200
& $taskGodot --headless --path . --script res://tests/test_race_rules.gd --quit-after 200
& $taskGodot --headless --path . --script res://tests/test_gameplay_headless.gd --quit-after 200
```

De menutest verwacht de schone standaardprojectconfiguratie. Let op succesmeldingen
zoals `MENU_FLOW_OK` en `GAMEPLAY_HEADLESS_OK` en controleer ook eventuele scriptfouten.
