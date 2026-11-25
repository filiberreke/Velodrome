# Meerdere velodrooms — issue #59

Branch: `feature/multiple-venues`, gebaseerd op `v0.4` / `13c952320324317b72b7b680860dce386f828532`.

## Wat deze branch oplevert

- De bestaande speelbare locatie heet **Vélodrome** en staat expliciet in `game/venues/velodrome.tres`.
- Het spel, de pistegeometrie en de huidige arena lezen deze standaardconfiguratie. De bestaande maten, kleurwaarden, tribunes, verlichting en aankleding blijven behouden.
- Iedere spelinstantie krijgt een eigen kopie van de configuratie, inclusief geneste tabellen.
- Het geometriescript accepteert een profiel en bouwt ook voor een kortere, niet op 5 cm afgeronde baanlengte een gesloten piste. Een synthetisch profiel controleert dit; dit is geen goedgekeurde reconstructie van Gent.
- **Gent is een ontwerpvoorstel**, zie [ontwerp en bouwbrief](gent/ontwerp.md), [referenties](gent/referenties.md), [technische taken](taken.md) en [validatie](validatie.md).

Gent wordt pas als speelbare locatie geregistreerd nadat de ontwerpkeuze is goedgekeurd, de eigen inrichting is gebouwd en alle wedstrijdsystemen de gekozen baanlengte gebruiken. De catalogus geeft voor een onbekend id `null`; zo kan een ontbrekende locatie nooit onbedoeld de aankleding van Vélodrome krijgen.

## Grenzen van deze eerste implementatie

Dit is de standaardconfiguratie en de voorbereiding van meerdere locaties. Er is nog geen stadionkeuzescherm of persistent opgeslagen stadionkeuze. Gent is nog niet speelbaar. Onder meer wedstrijdregels, minimap, trainingsomgevingen, records en cameratrajecten bevatten nog aannames over de huidige baan. Die worden concreet behandeld in de takenlijst, niet stilzwijgend als opgelost beschouwd.

## Structuur

| Bestand | Verantwoordelijkheid |
|---|---|
| `venue_definition.gd` | Configuratieschema met maten, bankings, arena/infield-bouwers, kleuren, licht en eigendom van aankleding |
| `velodrome.tres` | Huidige locatie, standaard-id `velodrome`, zichtbare naam `Vélodrome` |
| `venue_catalog.gd` | Alleen goedgekeurde speelbare locaties; huidige standaard en onafhankelijke kopieën |
| `track_geometry.gd` | Gemeenschappelijke parametrische referentielijn; stapgrootte sluit exact op een halve ronde |
| `arena.gd` | Bestaande locatiebouwer; leest tribunes, kleuren, licht en expliciete infield-bouwer |

`scenery` en `shared_actors` zijn een expliciet eigendomsmanifest, geen generieke automatische loader. De bestaande official- en tv-box-bouwers blijven in deze fase intact. Bij Gent worden die afzonderlijk aangesloten; de bestaande infield-bouwer wordt niet als fallback gebruikt.

## Vervolgorde

1. Ontwerp Gent beoordelen en goedkeuren.
2. Kortebaan-geometrie en plaatsingspunten als grijs model controleren.
3. Wedstrijdregels en registratie locatiebewust maken.
4. Eigen Gent-hal en aankleding bouwen; gedeelde acteurs aansluiten.
5. Menu, persistentie, omnium en trainingsmodi aansluiten.
6. Regressies, prestaties en visuele controle afronden; daarna Gent registreren.
