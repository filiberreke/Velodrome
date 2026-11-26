# Meerdere velodrooms — issue #59

Branch: `feature/multiple-venues`, gebaseerd op `v0.4` / `13c952320324317b72b7b680860dce386f828532`.

## Wat deze branch oplevert

- De bestaande speelbare locatie heet **Vélodrome** en staat expliciet in `game/venues/velodrome.tres`.
- Het spel, de pistegeometrie en de huidige arena lezen deze standaardconfiguratie. De bestaande maten, kleurwaarden, tribunes, verlichting en aankleding blijven behouden.
- Iedere spelinstantie krijgt een eigen kopie van de configuratie, inclusief geneste tabellen.
- Het geometriescript accepteert een profiel en bouwt ook voor een kortere, niet op 5 cm afgeronde baanlengte een gesloten piste. Een synthetisch profiel controleert dit; dit is geen goedgekeurde reconstructie van Gent.
- **Gent heeft nu een interactieve Godot-ontwerpweergave**, zie [openen en inrichting](gent/GODOT.md). De oorspronkelijke analyse staat in [ontwerp en bouwbrief](gent/ontwerp.md), [referenties](gent/referenties.md), [technische taken](taken.md) en [validatie](validatie.md).
- De [gerenderde FPS-vergelijking](PERFORMANCE.md) bevat een herhaalbaar protocol, ruwe metingen en gecontroleerde camerabeelden van beide stadions; de beschikbare meetmachine gebruikt software-rendering.

Gent wordt pas als speelbare locatie geregistreerd nadat de ontwerpkeuze is goedgekeurd, de eigen inrichting is gebouwd en alle wedstrijdsystemen de gekozen baanlengte gebruiken. De catalogus geeft voor een onbekend id `null`; zo kan een ontbrekende locatie nooit onbedoeld de aankleding van Vélodrome krijgen.

## Grenzen van deze eerste implementatie

Dit is de standaardconfiguratie en de voorbereiding van meerdere locaties. Er is nog geen stadionkeuze voor wedstrijden of persistent opgeslagen wedstrijdlocatie. Gent kan als ontwerpweergave vanuit het hoofdmenu worden bekeken; wedstrijden op Gent zijn nog niet ingeschakeld. Onder meer wedstrijdregels, minimap, trainingsomgevingen, records en cameratrajecten bevatten nog aannames over de huidige baan. Die worden concreet behandeld in de takenlijst, niet stilzwijgend als opgelost beschouwd.

## Structuur

| Bestand | Verantwoordelijkheid |
|---|---|
| `venue_definition.gd` | Configuratieschema met maten, bankings, arena/infield-bouwers, kleuren, licht en eigendom van aankleding |
| `velodrome.tres` | Huidige locatie, standaard-id `velodrome`, zichtbare naam `Vélodrome` |
| `venue_catalog.gd` | Alleen goedgekeurde speelbare locaties; huidige standaard en onafhankelijke kopieën |
| `track_geometry.gd` | Gemeenschappelijke parametrische referentielijn; stapgrootte sluit exact op een halve ronde |
| `arena.gd` | Bestaande locatiebouwer; leest tribunes, kleuren, licht en expliciete infield-bouwer |

`scenery` en `shared_actors` zijn een expliciet eigendomsmanifest, geen generieke automatische loader. De official is nu als gedeelde controller uit de infield-bouwer gehaald; Gent sluit hem afzonderlijk aan. De tv-box behoudt zijn GLB en controller, met een eigen Gent-plaatsing. De bestaande Vélodrome-infield-bouwer wordt niet als fallback gebruikt.

## Vervolgorde

1. Ontwerp Gent goedgekeurd; Godot-inrichting beoordelen via de ontwerpweergave.
2. Kortebaan-geometrie en plaatsingspunten als grijs model controleren.
3. Wedstrijdregels en registratie locatiebewust maken.
4. Gebouwde Gent-hal en aankleding bijsturen op basis van de screenshots; gedeelde acteurs zijn aangesloten.
5. Menu, persistentie, omnium en trainingsmodi aansluiten.
6. Regressies, prestaties en visuele controle afronden; daarna Gent registreren.
