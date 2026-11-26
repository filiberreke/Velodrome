# Gent in Godot — ontwerpweergave

De nominale lengte is **1000/6 m**: zes ronden zijn exact één kilometer. De scène gebruikt Godot, de gedeelde geometrieberekeningen en de bestaande renners, official en tv-box.

## Openen

Kies in het hoofdmenu **Gent — bekijk het nieuwe stadion**, of voer `res://venues/gent/gent_preview.tscn` uit.

- `1`–`4`: foto-overzicht, jury/finish, rennerzone, tv-box.
- `C` of pijltjestoetsen: volgend/vorig standpunt.
- `H`: bediening verbergen.
- `Esc` of Terug: hoofdmenu.

Dit is een ontwerpweergave met demonstratierenners. Wedstrijdformats zijn nog niet omgezet naar de korte baan; de speelbare standaardlocatie blijft Vélodrome.

## Indeling volgens de aangeleverde overzichtsfoto

De correctie van 26 november 2026 volgt de foto en toelichting van de projecteigenaar. De eerste camera kijkt vanuit dezelfde nabije bocht: **finish links, rennerzone rechts, pers en medische post vooraan**. De uitsnede is 16:9. Het grote scorebord staat aan de verre zaalwand en blokkeert het beeld niet.

| Plaats in het foto-overzicht | Godot-inrichting |
|---|---|
| Links naast de finish | Met dranghekken afgeschermde juryzone, werktafel/laptop, official, bel en een kleine tweezijdige rondenteller op een uitkragende arm bij de binnenrand van de piste |
| Rechts, tegenover de finish | Twaalf lage open rennerboxen, rustbanken, dekens, flesplanken, stoelen en verhoogde fietsenrekken; technische strook met werkbanken, koffers, rollers, fietsen en medewerkers |
| Nabije bocht, links en rechts | Twee open perswerkplekken met zwarte tafelrokken, laptops, notities, stoelen en journalisten |
| Tussen de perswerkplekken | Mixed zone met camera's op statieven, interviewfiguren en de **bestaande tweezijdige wit/blauwe Vélodrome-backdrop**, rechtstreeks gebouwd door `podium_sponsor_wall.gd` |
| Centraal vooraan in de bocht | Medische post met herkenbaar groen kruis, behandeltafel, materiaal en medewerkers in fluorescerende kledij |
| Overige bruikbare binnenvloer | Publiekszone, met enkele kleine statafels; geen grote centrale bareilanden |

De eerdere hoge grijze cabines met zittende figuren zijn vervangen door lage open servicevakken. De figuren in die cabines zijn verwijderd. De grote centrale bareilanden uit het vorige ontwerp zijn eveneens verwijderd.

In wereldcoördinaten ligt de finish op +X, de rennerzone op -X en de nabije bocht op -Z. De jurypositie en uitkragende rondenteller zijn afgeleid van de echte baanpositie van de finish, niet los op zicht geplaatst. De rondenteller toont in deze ontwerpweergave het voorbeeldcijfer 6.

## Branding en overige bouw

De rode sponsorvlakken gebruiken een aparte, vooraf uitgewerkte **PNG van het witte Vélodrome-logo op rood**: `game/assets/boarding/velodrome-boarding-rood.png` (2172 × 724). De oorspronkelijke meerkleurige 3D-woordmerktextuur wordt hiervoor niet meer tijdens het renderen ontleed. De PNG wordt verliesvrij geïmporteerd, met mipmaps en anisotrope filtering. Lettervormen behouden hun verhouding en antialiasing. De rode bannerachtergrond en de boarding gebruiken dezelfde materiaalwaarde **#D82632**, ruwheid en specular; de subtiele achtergrondvariatie van de PNG wordt niet overgenomen op de boarding.

Alle twintig pistevakken bevatten nu onze eigen sponsorafbeeldingen. De hoofdkleur is gekozen op basis van de aangeleverde foto; dit is een kleurbenadering binnen de spelgeometrie, geen opgemeten kopie van de foto.

| Kleurfamilie in de foto | Gekozen bestaande spelbanners | Aantal pistevakken |
|---|---|---|
| Rood met witte opdruk | Nieuwe witte Vélodrome-PNG | 6 |
| Wit / licht / ivoor | Eerlijke Stef licht, Vélodrome licht, Sjampanje ivoor | 6 |
| Geel met donkere opdruk | Tour d’Ambiance, Chasse Patate | 3 |
| Groen met lichte opdruk | Sjampanje groen | 2 |
| Blauw | PelotonPredictor, Wielerpraat | 2 |
| Donker | Eerlijke Stef donker | 1 |

De expliciete volgorde staat in `gent_sponsors.gd`. De afbeeldingen worden zonder uitrekken in de gebogen baanvlakken geplaatst. Op de buitenboarding blijven 28 witte Vélodrome-opdrukken staan, met leesbare opdruk aan beide zijden. De 24 opdrukken bij het middenplein liggen vlak op de rode/oranje binnenstrook, zoals op de foto. Er hangen geen reclamevlakken in de middenpleinomheining; daar blijven alleen de leuning en palen over. De vloeropdruk gebruikt hetzelfde oranje als de onderliggende strook, zodat de witte letters rechtstreeks geschilderd lijken. De overige sponsorassets zijn ongewijzigd hergebruikt.

De zwevende zonebenamingen **Renners/techniek** en **Mixed zone** zijn verwijderd. Alleen tekst die zichtbaar op een fysiek paneel, bord of display hoort te staan, blijft behouden (zoals de boxnummers, pers-/jurybordjes, medische post en rondenteller).

De baan blijft 166⅔ m met maximaal 52° banking en zeven meter houtoppervlak, een blauwe strook en een oranje binnenzone. De eigen gele tribunes, rechthoekige hal, vlak plafond en wanddecoratie blijven onderdeel van Gent. De bestaande official behoudt zijn vier animaties en attributen; de tv-box behoudt beide presentatoren op zijn eigen platform bij de aankomsttribune. Er worden geen Vélodrome-tenten of nationale rennerhuisjes overgenomen.

Bij standaarddichtheid bevat de bruikbare publieksvloer 1.388 bezoekers, in de eenvoudige uitvoering 604. Medewerkers en tribunes staan los van die telling. Publiek wordt per sector met afstandsafhankelijke detailniveaus weergegeven. De bezetting respecteert de medische, pers-, interview-, jury- en rennerzones.

## Referentie en maatvoering

De door de projecteigenaar aangeleverde overzichtsfoto en diens expliciete aanwijzingen hebben voor de middenpleinindeling voorrang op de eerdere schetsen. De foto is niet gedateerd en bewijst geen precieze afmetingen. Aantal rennerboxen, exacte maten en coördinaten blijven een reconstructie voor het spel. Eerdere fotobronnen staan in [referenties.md](referenties.md); de oudere ontwerpschetsen zijn geen actuele plaatsingsplattegrond.

Alles is procedureel opgebouwd. De backdrop gebruikt dezelfde bouwer en dezelfde logo's als Vélodrome; er is hiervoor geen nieuw Blender-model nodig.

## Screenshots en reproductie

De vier bestanden onder `screenshots/` zijn echte Godot-frames van deze scène, opgenomen op 1600 × 900 met OpenGL Compatibility/Mesa llvmpipe.

```sh
godot --path game --script res://tests/capture_gent.gd
```

Een werkend display/renderapparaat is nodig; `--headless` levert geen bruikbare screenshots op. Vaste camera's en stilgezette demonstratierenners maken vergelijking mogelijk. Dit is geen hardware-FPS-benchmark. Zie ook [de validatie](VALIDATIE.md).

![Foto-overzicht, finish links en rennerzone rechts](screenshots/01-overzicht.jpg)

![Jury, bel en uitkragende rondenteller naast de finish](screenshots/02-piste.jpg)

![Open rennerboxen en technische strook](screenshots/03-rennersboxen.jpg)

![Gedeelde tv-box met presentatoren](screenshots/04-tv-box.jpg)
