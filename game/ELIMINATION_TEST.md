# Afvalling — test op Godot (feature/elimination-race)

De implementatie staat bewust op de featurebranch. **Niet gemerged met main.**
Dit pakket is statisch gecontroleerd maar niet in een Godot-runtime uitgevoerd.

## Test starten

Vanaf de map met de Git-clone:

```bash
git fetch origin
git switch feature/elimination-race
godot --headless --path game --script res://tests/test_elimination_rules.gd
godot --headless --path game --script res://tests/test_elimination_traffic.gd
godot --path game
```

Bij een desktopinstallatie van Godot kan de laatste stap ook door `game/project.godot` te openen en F6/F5 te gebruiken.

## Spel

- Selecteer **Afvalling** op de wedstrijdselectie.
- Kies **4**, **12** of **16** deelnemers, inclusief speler.
- De rondetelling wordt automatisch gezet op respectievelijk 6, 22 of 30 ronden:
  - 4 deelnemers = 2 eliminaties en 2 ronden eindfinale;
  - 12 deelnemers = 10 eliminaties en 2 ronden eindfinale;
  - 16 deelnemers = 14 eliminaties en 2 ronden eindfinale.
- Iedere twee ronden moet precies één van de achterwielen als laatste passeren.
- Tijdens een eliminatie toont de HUD centraal `AFGEVALLEN · [NAAM]`.
- De afvallingscamera staat vóór de meetlijn, aan de aanrijzijde, en kijkt naar de achterwielen.
- De finishfoto wordt gedurende 5 seconden naar het bestaande Infinity-stadionscherm gestuurd.
- Afvaller bolt uit richting de andere rechte lijn en rijdt door de bestaande doorgang in de binnenboarding naar de toegangscorridor bij een landenbox.

## Controlepunten

1. Er zijn maximaal 4/12/16 starters en de menu-optie blijft beschikbaar na terugkeer.
2. De uitslag houdt de afvallers in omgekeerde eliminatievolgorde, de finalisten bovenaan.
3. Laatste achterwiel op de meet is beslissend, ook bij twee passages in één fysicatick.
4. Foto is genomen van vóór de meet, niet vanuit de scratch-camera ná de meet.
5. Foto verschijnt op de schermen, waarna het scorebord terugkeert.
6. Afvaller vertraagt en verlaat het circuit bij de doorgang op de tegenoverliggende rechte lijn.
7. Geen renners rijden door het gesloten boardinggedeelte.
8. Scratch en puntenkoers blijven werken zoals in main.

## Bekende beperkingen van deze eerste test

- `REAR_TRAILING_EDGE_M` is berekend uit de Blender-wielgeometrie, maar moet nog worden vergeleken met de geïmporteerde mesh. De juryinterpolatie zelf gebruikt dit punt.
- De gewone SubViewport-camera levert een visuele finishfoto, geen professionele lijnscancamera.
- Bij exact gelijke geïnterpoleerde tijden beslist een reproduceerbare tie-breaker. In een latere versie is een handmatige fotofinishjury mogelijk.
- Er zijn zes fysieke landenboxen. Wanneer de landenlijst van maximaal zestien deelnemers meer dan zes landen bevat, kan niet iedereen een eigen fysieke landenbox krijgen; rennners zonder eigen landenbox rijden door langs de grijze toegangszone en stoppen net voorbij de volledige boxenrij, op afzonderlijke plaatsen.
- De fotocamera, exitroute, AI en menu zijn nog NIET in een echte Godot-runtime getest. Vervang eventuele Godot-parsefouten niet met stilzwijgende aanpassingen in main: test eerst deze branch en meld de foutregel.

## Architectuur

- `elimination_race_rules.gd`: jury voor achterwielpassages.
- `elimination_traffic.gd`: gezamenlijke voorrangs-/botsingscontrole.
- `elimination_ai.gd`: eigen eliminatiestrategie met dezelfde CP/W′-fysiologie.
- `main.gd`: alleen de branch race_mode=2 voor afvalling; bestaande events blijven beschikbaar.
- `infinity_scoreboard.gd`: tijdelijk screenshot op bestaande stadionscherm.
- `race_menu.gd`: wedstrijdselectie en deelnemeraantal.
