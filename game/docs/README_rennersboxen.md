# Zes landenboxen en verdiepte keldertrap

De vier oude materiaalposten zijn vervangen door zes zesdaagseboxen langs het
rechte stuk tegenover start/finish. De goedgekeurde ontwerpen zijn uitgevoerd
als Godot-meshes, met elf nationale materiaalsets en geplooide schuifgordijnen.
Iedere box bevat een bed, een plank met helmen en drinkbussen, een wielrek,
een rollenfiets en twee reservefietsen. Fietsen en losse wielen gebruiken de
werkelijke `Bike`-mesh uit `assets/riders/velodrome_rider.glb`: dezelfde
Blender-export als de koers, met oranje/wit frame, dicht achterwiel en driespaaks
voorwiel. Bij achtervolging gebruiken de boxen de `Bike`-mesh uit
`assets/riders/velodrome_pursuit.glb`, inclusief het tijdritstuur. De rigbestanden
blijven ongewijzigd. Alleen de skinning is uit de geparkeerde kopie weggelaten;
vertices, driehoeken, materialen en schaal zijn overgenomen.

De oudere losse `assets/bikes/track_bike.glb` wordt hier niet meer gebruikt.

## Opstelling

- Boxmaten: 2,60 × 2,50 m; bovenrail 2,10 m; materiaalplank 1,50 m.
- Materiaalzone inclusief dranghekken: 8,60 × 3,80 m.
- Centra: x = -14,60 m; z = -25, -15, -5, 5, 15, 25 m.
- Materiaalzones beslaan x = -16,50 tot -12,70 m en samen 58,60 m van het
  rechte stuk. Tussen de zones blijft 1,40 m vrij. Openingen wijzen naar de baan.
- De oude tenten zijn verwijderd. Dranghekken scheiden materiaal en publiek.
  De doorgang voor het midden van elke box blijft vrij.

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

## Bezetting van de materiaalzone

Een gesloten box heeft buiten geen fietsen, rollenbank, materiaal- of wielvoorraad
en geen bijbehorende staf of supporters. Het gordijn sluit; de box en vaste
dranghekken blijven staan. De hele buitenzone wordt direct bij de sluitopdracht
verborgen, ook tijdens de gordijnanimatie.

Bij elke open box staan twee mecaniciens met gereedschap, een gewone verzorger
met twee bidons en een trainer met stopwatch (soms met klembord). Per land staan
drie tot zes supporters in losse, ongelijke groepjes: minstens twee leunen op
de echte glazen boarding, anderen klappen, juichen, praten of drinken.
Hun handpositie ligt op de bestaande leuning, buiten het materiaalvak maar
achter het glas; zij houden de centrale toegang vrij. Landen hebben verschillende
werkposities, kijkrichtingen, mannen/vrouwen, lichaamsbouw en kledingnuances.
Een vaste seed per land voorkomt verspringen bij rosterupdates of heropenen.
Alle personen gebruiken bestaande Blender-crowdmodellen met de gedeelde crowd-shader. De maximaal 60
boxpersonages gebruiken het gedetailleerde mesh zonder afstandsonderbreking.
Hun kledingkleur verandert mee met het toegewezen land. De oude altijd zichtbare
mecanicien is verwijderd uit de losse middenterrein-MultiMeshes.

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

`res://tests/test_box_occupation.gd` vergelijkt alle fietssurfaces met beide
actuele koersrigs, inclusief vertices, indices en materiaalwaarden. De test
controleert ook de vereiste rollen en gevarieerde bezetting per open box, landenkleuren,
bidons, de positie aan het glas en een lege buitenzone tijdens en na sluiten.

De controles voor spelverloop, spelersoutfit, achtervolging en ploegenachtervolging
slagen op deze wijziging. De oudere `test_north_infield.gd` meldt twee bestaande
verwachtingsverschillen bij de interviewfiguur en het aantal pizzaterrasstoelen;
dezelfde twee meldingen zijn bevestigd op de ongewijzigde basiscommit.
