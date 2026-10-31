# Zes landenboxen en verdiepte keldertrap

De vier oude materiaalposten zijn vervangen door zes zesdaagseboxen langs het
rechte stuk tegenover start/finish. De goedgekeurde ontwerpen zijn uitgevoerd
als Godot-meshes, met elf nationale materiaalsets en geplooide schuifgordijnen.
Iedere box bevat een bed, een plank met helmen en drinkbussen, een wielrek,
een rollenfiets en twee reservefietsen. Fietsen en losse wielen hergebruiken
`assets/bikes/track_bike.glb`; dat bestaande model is niet gewijzigd.

## Opstelling

- Boxmaten: 2,60 × 2,50 m; bovenrail 2,10 m; materiaalplank 1,50 m.
- Materiaalzone inclusief dranghekken: 8,60 × 3,80 m.
- Centra: x = -14,60 m; z = -25, -15, -5, 5, 15, 25 m.
- Materiaalzones beslaan x = -16,50 tot -12,70 m en samen 58,60 m van het
  rechte stuk. Tussen de zones blijft 1,40 m vrij. Openingen wijzen naar de baan.
- De oude tenten zijn verwijderd. Publiek langs het glas wordt niet meer in
  de toegangszone van de boxen geplaatst. Dranghekken scheiden materiaal en publiek.

## Landen en wedstrijden

`main.gd` zendt `infield_riders_changed` na een nieuw startveld en bij een
gewijzigde spelersoutfit. De boxen werken hun toewijzing daarop bij, zonder
iedere frame de meshes te herbouwen.

- Andere wedstrijden: de zes meest vertegenwoordigde landen krijgen een
  open box. Het spelersland vervangt indien nodig het zesde land.
- Achtervolging en ploegenachtervolging: alleen de deelnemende landen openen.
  Alle ploegmaats delen de box van hun ploeg. Andere gordijnen blijven dicht.
- De selectie leest expliciet `country` in `riders_config.cfg` (land-ID of IOC-code)
  of de daadwerkelijk gebruikte nationale `skinsuit_png` / `country_kit`.
  De outfitkeuze van de speler heeft voorrang op de oorspronkelijke spelerconfig.
- Legacy-renners zonder land krijgen een stabiele standaard uit de bestaande
  landencatalogus. Standaardspelersland is België; standaardtegenploeg Nederland.
  De oorspronkelijke persoonlijke kleuren en custom PNG's worden niet aangepast.
- Bij minder dan zes landen vervolledigen landen met nul starters de rij;
  gelijke aantallen worden stabiel op ID gesorteerd. In andere wedstrijden
  blijven alle zes boxen open.

De landen: België, Nederland, Frankrijk, Italië, Duitsland, Groot-Brittannië,
Denemarken, Australië, Nieuw-Zeeland, Portugal, Verenigde Staten.

## Keldertrap

De capsulevorm van de vloer blijft identiek. Uit de echte vloermesh is een
opening van 4,55 × 9,40 m gesneden. Er ligt geen grondvlak of sokkel meer over
de opening. Vijftien treden dalen met een optrede van 18 cm en een aantrede van
28 cm af naar een bordes 2,70 m onder het vloerniveau. Zijwanden, afdalende
leuningen en twee kleine praktische lichten laten de diepte zien.

## Onderhoud en controles

De schone PNG-artwork staat onder `rennersboxen/textures/`; `themes.gd` bevat
expliciete preloads voor export. `rennersboxen/source/build_themes.py` maakt de
artwork opnieuw met Pillow. De scriptgestuurde boxscènes zijn ook afzonderlijk
te gebruiken vanuit `rennersboxen/scenes/`.

`godot --headless --path game --script res://tests/test_infield_boxes.gd`
controleert de echte game-opbouw, landenrangschikking, live outfitwissel,
beide achtervolgingsmodi, terugschakelen naar andere wedstrijden, de
vloeroppervlakte en de ondergrondse treden. De gewone race- en middenterreintests
blijven van toepassing.

De controles voor spelverloop, spelersoutfit, achtervolging en ploegenachtervolging
slagen op deze wijziging. De oudere `test_north_infield.gd` meldt twee bestaande
verwachtingsverschillen bij de interviewfiguur en het aantal pizzaterrasstoelen;
dezelfde twee meldingen zijn bevestigd op de ongewijzigde basiscommit.
