# Afvalling — tests op Godot

De implementatie is gecombineerd met de actuele main-versie. Godot-tests
controleren echte muisklikken op Start wedstrijd voor 4/12/16 deelnemers,
de aftelling, een eerste eliminatie, vaste rennerprofielen en de menuvolgorde.
De spelvormafbeeldingen zijn gerenderd en visueel gecontroleerd.

## Test starten

Vanaf de map met de Git-clone:

```bash
git fetch origin
git switch codex/player-lanes-11
godot --headless --path game --script res://tests/test_elimination_menu_fix.gd
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
- De volledige visuele fotofinish en de complete uitrijroute blijven handmatige controlepunten; de automatische integratietest controleert de eerste eliminatie en het aanmaken van de uitrijstatus.

## Architectuur

- `elimination_race_rules.gd`: jury voor achterwielpassages.
- `elimination_traffic.gd`: gezamenlijke voorrangs-/botsingscontrole.
- `elimination_ai.gd`: eigen eliminatiestrategie met dezelfde CP/W′-fysiologie.
- `main.gd`: alleen de branch race_mode=2 voor afvalling; bestaande events blijven beschikbaar.
- `infinity_scoreboard.gd`: tijdelijk screenshot op bestaande stadionscherm.
- `race_menu.gd`: wedstrijdselectie en deelnemeraantal.


## Speelbaarheidscorrecties (bijgewerkt 2 november 2026)

De bestaande feature/elimination-race is al opgenomen in main op 7d195ea.
De vervolgcorrecties zijn boven op die integratie gebouwd.

- De speler stuurt handmatig zoals in puntenkoers: elf rijlijnen met 0,60 m
  per nieuwe druk, met hetzelfde totale bereik van 1,18 tot 7,18 m.
  Automatische inhaalhulp en de bijbehorende menu-optie zijn verwijderd.
- Blokkeringsmeldingen blijven beschikbaar wanneer de fysieke botsingscontrole
  daadwerkelijk de voortgang beperkt; gewoon slipstreamen geeft geen waarschuwing.
- TOT LAATSTE toont de afstand tot de laatste actieve tegenstander. Wanneer
  de speler zelf laatste ligt, is dit de negatieve afstand tot de volgende
  actieve renner. Afvallers tellen niet mee; de positienoemer toont actieve renners.
- De AI start twee-aan-twee op de lage banking, volgt stabieler een wiel en
  laat de kop tijdens rustig rijden temporiseren. Positionering voor afvalling
  begint in de laatste 200 m. De startvraag gebruikt exact de bestaande
  scratch/puntenkoers-envelope (350–450 W, 14 s, <11 m/s, <170 m), via CP/W′.
- Botsingsafhandeling bewaart fysieke baansnelheid in buitenbanen. Jurytijden
  voor toekomstige lijnen blijven bewaard wanneer de vorige beslissing op
  een ver achterliggende renner wacht. Normaal finishen kan pas met twee finalisten.
- AFGEVALLEN-tekst, zichtbaarheid, timers en blokkadestatus worden
  gewist bij herstart, menuterugkeer en nieuwe wedstrijd.

Nieuwe gerichte tests:

```bash
godot --headless --path game --script res://tests/test_player_lanes.gd
godot --headless --path game --script res://tests/test_elimination_corrections.gd
godot --headless --path game --script res://tests/test_elimination_gameplay.gd
godot --headless --path game --script res://tests/test_elimination_rules.gd
godot --headless --path game --script res://tests/test_elimination_traffic.gd
godot --path game --rendering-method gl_compatibility --script res://tests/capture_elimination_corrections.gd
```

Alle 16 uitgevoerde headless suites slaagden; zie
`verification/elimination_corrections/validation.json` voor scripts, meetwaarden
en beperkingen. De volledige afvallingssimulaties gebruiken een stap van 0,1 s.
Scratch, puntenkoers, individuele/ploegenachtervolging, menu, profielen, records
en intro zijn als regressie gecontroleerd. De puntenmelding-test gebruikt nu een
vrije tijdelijke UDP-poort om een bestaande game/bridge niet te blokkeren.

De instelling is op 1920×1080 gerenderd en bekeken. Geen fysieke Zwift Ride/KICKR
getest; alleen de stuurprotocolhandlers. Geen volledige visuele beoordeling van
inhaalbewegingen, afvallersroutes of fotofinish. Lokale certificaat-/UID-waarschuwingen
en bestaande null-material-meldingen bij het opruimen staan in het validatiebestand.
De bestaande importcache is hergebruikt. De headless editor meldt dat Blender
niet ingesteld is; een volledige nieuwe import van bron-.blend-bestanden is
hier niet gecontroleerd.


## Invoegen en naast elkaar rijden (1 november 2026)

Onveilig invoegen wordt nu vóór de lengtebotsingscontrole tegengehouden,
zowel bij handmatig sturen als bij AI. De invoegende renner
wacht naast de bestaande rijlijn; de aanwezige renner wordt niet abrupt
afgeremd om de invoeger ruimte te geven. Zodra het gat veilig is, wordt
de aangevraagde rijlijnwissel alsnog voltooid. De HUD toont tijdens het wachten
`GEEN RUIMTE OM IN TE VOEGEN · HOUD JE RIJLIJN`.

De zijafstand gebruikt 0,65 m fysieke afstand tussen de fietscentra en rekent
de banking om naar horizontale rijlijnoffsets. De oude brede strook van 0,88 m
is vervallen voor botsingen. Daarmee kunnen renners zichtbaar naast elkaar
rijden zonder onterecht op de snelheid van de andere rijlijn begrensd te worden.
De botsingscontrole en AI-blokkadeherkenning gebruiken dezelfde maat.

```bash
godot --headless --path game --script res://tests/test_elimination_merging.gd
```

Acht relevante headless suites slaagden opnieuw, inclusief volledige afvalling
met 4/12/16 deelnemers en scratch-/puntenkoersregressies. De nieuwe test dekt
in-/uitwaarts invoegen, omgekeerde rennerindices, gelijktijdige wissels,
achteropkomend verkeer, grensafronding, naast elkaar rijden op banking en
de daadwerkelijke main.gd-integratie. Zie `verification/elimination_blocking/validation.json`.
Dit zijn gereconstrueerde situaties; geen replay van de exacte screenshotstand,
geen fysieke Ride/KICKR-test en geen nieuwe visuele rijtest op de baan.
