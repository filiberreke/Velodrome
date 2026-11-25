# Validatie standaardlocatie Vélodrome

Uitgevoerd op 25 november 2026 met **Godot 4.7.2 stable**, Compatibility-project, headless uitvoering. Vergelijkingsbasis: `v0.4` / `13c952320324317b72b7b680860dce386f828532`.

## Resultaten

| Controle | Resultaat | Dekking |
|---|---|---|
| `test_venue_configuration.gd` | Geslaagd | Naam/default-id, onafhankelijke geneste configuraties, expliciete bouwers/assetpaden, onbekende venue niet beschikbaar, validatie van ongeldige waarden; gesloten korte testgeometrie |
| `test_track_bowl.gd` | Geslaagd | Bestaande 250 m-lus, constante oppervlakbreedte, banking, continue raaklijnen en bovengrens op helling |
| `test_graphics_settings.gd` | Geslaagd | Volledige arena én eenvoudige graphics; instellingen opslaan/herladen, tribunes, boxen, publiek, podium, official en intro |
| `test_commentary_box.gd` | Geslaagd | Tv-boxplaatsing, 14 meshes, 43 oppervlakken, 321.212 driehoeken, twee onafhankelijk geanimeerde monden, twee praktische lichten |
| `test_official_ready.gd` | Geslaagd | Vier clips, 21 botten, pistool/flash/bel/vlag, actieovergangen en reset |
| `test_gameplay_headless.gd` | Geslaagd | Productieraceloop, 8 renners/10 ronden en 12 renners/50 ronden; finite toestand, energiegrenzen, AI-start en eindsprint |
| `test_finish_line_race.gd` | Geslaagd | 16 renners, puntenkoers van 20 ronden; start, fysieke meetlijn, sprints, official, foto's en geïsoleerde CSV-uitvoer; 2.582 controles |
| Defaultgeometrie versus originele bron | Exact gelijk | 20.000 posities, headings en bend-waarden, ook over negatieve afstanden en rondenaad; maximale afwijking **0,0** |
| Gameplay-snapshots versus originele branch | Byte voor byte gelijk | JSON-snapshots van dezelfde twee race-scenario's |
| `git diff --check` | Geslaagd | Geen whitespacefouten |

De nieuwe korte geometriecontrole gebruikt **166,66 m, radius 12 m, overgang 24 m** als synthetische test. Dat bewijst geslotenheid van het geometriescript bij een niet op 5 cm afgeronde halve rondelengte. Het bewijst geen correcte Gent-wedstrijdlogica, een opgemeten Gent-piste of definitieve Gent-inrichting.

### Gemeten bestaande baan

- Banking: circa **12,0000°–42,0000°**.
- Grootste helling op de gecontroleerde buitenste rijlijn: **13,5583%**.
- Grootste verandering van de raaklijn per 5 cm: **0,16032°**.

## Bestaande testopstellingen aangepast

Drie fouten kwamen ook op de ongewijzigde uitgangsversie voor. Eerst is die baseline gecontroleerd; daarna zijn uitsluitend de testopstellingen hersteld:

1. De graphicstest verwachtte nog zes rennersboxen en hield geen rekening met de ingestelde publieksdichtheid. De actuele productielocatie heeft negen boxen en schaalt de publieksaantallen met `crowd_density`.
2. De official-fixture miste `race_mode`, dat de huidige productielogica nodig heeft. De fixture gebruikt nu expliciet puntenkoers voor de gecontroleerde individuele lead/tail-afstanden.
3. De headless gameplay-fixture sloeg de normale initialisatie van `ride_navigation` over, terwijl de toetsenbordhandler die inmiddels gebruikt. De fixture maakt nu die productiemodule aan.

De productiewerking is hiervoor niet veranderd.

## Reproduceerbaarheid

Importeer eerst de bestaande game-assets met de bij het project passende Godot-versie. Headless machines zonder ingestelde Blender-installatie moeten voor de import lokaal Blender configureren of de rechtstreekse `.blend`-import lokaal uitschakelen. De game gebruikt de reeds aanwezige GLB's. Deze machine-instelling is niet als projectwijziging opgenomen.

Voer de bovenstaande scripts uit met:

```sh
godot --headless --path game --script res://tests/test_venue_configuration.gd
```

Vervang de scriptnaam voor de andere controles. Geef tests die instellingen of ritten schrijven een eigen lege Godot-userdirectory, bijvoorbeeld via `XDG_DATA_HOME` onder Linux. Zo worden testgegevens niet met persoonlijke spelgegevens vermengd.

## Grenzen

Geen visuele GPU-regressie of hardware-FPS-benchmark uitgevoerd. De geometrische vergelijking, scène-/assetcontroles en productiesimulaties slagen; de Gent-afbeelding bij de bouwbrief is een eigen geometrisch ontwerpschema, geen gerenderd spelmodel. Een echte Gent-bouw, camera-controle en performancevergelijking volgen na ontwerpgoedkeuring.
