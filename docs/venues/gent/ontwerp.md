# Gent — ontwerpvoorstel en bouwbrief

**Status:** ter goedkeuring, geen opdracht om het definitieve model al te bouwen.
**Project:** Vélodrome, GitHub [issue #59](https://github.com/filiberreke/Velodrome/issues/59), branch `feature/multiple-venues`.
**Onderzocht:** 25 november 2026. Referentie-editie: Zesdaagse van 17–22 november 2026.
**Naam in het spel:** **Gent**; technisch id `gent`.

## 1. Voorgesteld resultaat

Een compacte, steile houten binnenpiste in een herkenbare oudere rechthoekige sporthal. Het karakter komt van de korte ronde, snelle opeenvolging van bochten, nabijheid van tribunes en een warm, druk zesdaagsegevoel. Het ontwerp heeft een eigen visuele identiteit: gele zitjes, warm hout, rode omranding, een lichte vlakke plafondafwerking en donkerblauwe constructieaccenten.

De piste en het stadion worden op eigen maat gebouwd. Fietsen, renners, official en tv-box behouden hun echte schaal. Het huidige stadion wordt niet in zijn geheel verkleind. De zichtbare naam, wandgrafiek en reclamevlakken worden specifiek voor Gent ontworpen.

**Aanbeveling: bouw de basis volledig procedureel in Godot.** Er is geen nieuw Blender-model noodzakelijk om de kenmerkende vorm, de baan, de hal, het plafond of de tribunes te realiseren. De bestaande geanimeerde official en tv-box met presentatoren blijven gedeelde GLB-assets. Eventueel maatwerk in Blender is een latere keuze voor enkele decorstukken, geen voorwaarde voor deze locatie.

Bij deze brief horen [de referenties](referenties.md), [de geometrische vergelijking en het palet](voorstel.png) en [de technische uitvoeringstaken](../taken.md).

## 2. Feiten, observaties en ontwerpkeuzes

### Bevestigde gegevens

| Gegeven | Waarde / betekenis | Bron en beperking |
|---|---|---|
| Gepubliceerde baanlengte | **166,66 m** | Technische sportfiche Stad Gent; geen landmeetkundige precisie opgegeven |
| Helling in de bochten | **52°** | Inventaris Onroerend Erfgoed; graden, niet procenten |
| Gebouwtype | Rechthoekige hal onder een plat dak | Inventaris Onroerend Erfgoed |
| Omvang dakconstructie | **86 × 68 m** | Indurium, dat de bestaande dakconstructie onderzocht; dit is niet automatisch de vrije binnenmaat |
| Middenplein | **800 m²** | Technische zaalfiche Stad Gent, januari 2024; bruikbare zaaloppervlakte niet zonder meer gelijk aan alle ruimte binnen de meetlijn |
| Recente visuele referenties | Officiële fotogalerijen dag 1 en dag 5 van 2026 | Beide galerijen daadwerkelijk visueel bekeken; andere jaren niet als actuele inrichting gepresenteerd |

De stadsbronnen noemen verschillende aantallen zitplaatsen en toegelaten capaciteiten, afhankelijk van gebruik en bron. Het ontwerp neemt daarom geen absoluut aantal zichtbare bezoekers als opgemeten waarheid over. De bouwopdracht gaat uit van visuele dichtheid en een renderbudget.

### Beknopte foto-observaties

In de bekeken beelden zien we geel/oker zitrijen dicht bij de baan, rood aan buitenrand en binnenzone, licht houten pistevlakken met blauwe markeringen en grote rechthoekige reclamevlakken. Het middenplein bevat eigen evenementinrichting en dicht publiek. Het plafond is licht en vlak leesbaar; grote wandpanelen en donkere verticale elementen geven de zaal ritme. Referenties A23/A36/A42/A44 en B12/B13 in het bronnenregister tonen deze onderdelen. B02/B20 tonen compacte functionele rennerzones.

Dit zijn visuele observaties uit foto's met perspectief en wisselende belichting. De onderstaande exacte kleuren, hoogtes en materiaalwaarden zijn onze ontwerpkeuzes, geen uit de foto's afgeleide meetresultaten.

## 3. Vergelijking met de huidige locatie Vélodrome

| Onderdeel | Huidige spelconfiguratie | Voorstel Gent |
|---|---|---|
| Baanlengte | 250 m | Nominaal zes ronden per kilometer; zie precisiebesluit hieronder |
| Grootste banking | 42° | 52° als uitgangspunt |
| Referentie-bochtstraal | 18 m | Startwaarde 12 m voor blockout; niet opgemeten |
| Overgangszone | 36 m | Startwaarde 24 m, afstemmen op rijgedrag en zicht |
| Houten breedte | 8,25 m over het oppervlak | Voorstel 7,00 m; visuele/proportionele keuze |
| Blauwe strook | 0,78 m in huidige geometrie | Voorstel 0,65 m; apart toetsen aan referenties en rijlijnen |
| Hellingshoek rechte stukken | 12° | Voorstel 12° in eerste blockout; niet bronbevestigd voor Gent |
| Baanbekleding | Hout, blauwe strook, vaste huidige branding | Eigen houtvariant, markeringen en merkneutrale panelen |
| Dak | Hoge centrale gefacetteerde kap met radiale structuur | Vlak leesbaar plafond en rechthoekig constructieritme |
| Tribune | Twee doorlopende concentrische tiers, bont gekleurde stoelen | Eigen geel/oker rijen in zaalvakken met nieuwe toegangen |
| Afwerking | Navy, turquoise, goud en oranje | Warm hout, geel/oker, rood, crème en donkerblauw |
| Middenterrein | Uitgebreide aankleding, negen nationale rennersboxen, horeca, centrale keldertrap en publiek | Eigen compacte indeling; geen automatische overname |
| Tv-box | Bestaande GLB, vaste plaats in tweede tribune | Zelfde model en presentatoren; eigen plaatsingspunt |
| Official | Geanimeerd model in bestaande infield-bouwer | Zelfde model/attributen; zelfstandige controller en nieuw meetpunt |
| Scorebord | Infinity-scherm in huidige dakstructuur | Voorstel één rechthoekig digitaal bord aan kopzijde |
| Intro | Traject langs huidige boxen, publiek en dak | Kort eigen zaal-/piste-/tv-box-traject |
| Trainingsomgeving | Eigen bestaande trainingsopstellingen | Per training expliciete Gent-keuze; geen automatische verhuis |

**Lengteprecisie, voorgesteld besluit:** gebruik voor de nominale spelbaan `1000.0 / 6.0` meter, toon **166,67 m** in het keuzescherm, en documenteer dat de publieke bron **166,66 m** vermeldt. Daarmee zijn 6/24 ronden exact 1/4 km. Dit is een spelontwerpkeuze; de bron bewijst niet dat de echte baan exact die breuk meet. Als we de letterlijke 166,66 m kiezen, moet een tijdrit van 1 km nog 0,04 m na zes ronden doorlopen. Dat mag niet via afronden van de uitslag verborgen worden. Mijn aanbeveling voor akkoord is de nominale zesrondenbaan.

### Aan te houden blockoutparameters

| Parameter | Startwaarde | Status |
|---|---:|---|
| `lap_length_m` | 1000 / 6 | Aanbevolen spelconventie |
| `bend_radius_m` | 12,0 m | Proportionele startwaarde |
| `transition_m` | 24,0 m | Proportionele startwaarde |
| `straight_bank_deg` | 12° | Voorstel |
| `corner_bank_deg` | 52° | Bronbevestigd als kenmerkende maximale hoek |
| `apron_width_m` | 0,65 m | Voorstel |
| Houten oppervlakbreedte | 7,0 m | Voorstel |
| Binnenste rode loop-/veiligheidszone | 1,8–2,4 m waar de ruimte het toelaat | Ontwerpbereik; buiten de berijdbare lijnen |
| Hoogte zichtbare plafondonderzijde | Eerste opzet 15 m boven middenplein | Artistieke startwaarde; zichtlijnen bepalen bijstelling |
| Halomtrek | Start met dakreferentie 86 × 68 m | Externe dakmaat als kader, niet als gemeten vrije binnenruimte |

De maatverhouding van de piste eerst als los grijs model controleren. Zet daarna de zaal eromheen. Een eigen kortebaanprofiel vraagt een nieuwe afweging van de binnenruimte; de huidige centrale keldertrap en de rechthoekige uitsparing in de ondervloer zijn geen Gent-uitgangspunt.

De huidige geometrie koppelt referentieafstand, oppervlaktebreedte, banking en werkelijke rijafstand aan elkaar via `_at` en `_path_metric`. Leg bij de blockout vast welke lijn de nominale rondelengte draagt en waar de geschilderde meetlijn ligt. Controleer dat een verschuiving van de blauwe strook de betekenis van een ronde niet onbedoeld verandert. Ook de 200 m-markering kan op deze korte baan niet simpelweg op de huidige plek 50 m na de meet blijven staan.

## 4. Ruimtelijk ontwerp

### Piste en tribunes

- Houd de baan als één parametrisch gegenereerd oppervlak, met doorlopende kromming en banking. De houtplanken lopen met de rijrichting mee; schilderingen volgen dezelfde normals.
- Bouw geel/oker zitrijen in afzonderlijke zaalvakken. De rijen mogen langs de baan lopen, maar de achterwand en draagstructuur blijven rechthoekig. Geen verkleinde kopie van beide huidige tiers.
- Leg trappen en toegangen vast als uitsparingen in de zitrijen. Gebruik geen fotobanner als vervanging van de tribunevorm.
- Ontwerp de afstand tussen renners, buitenboarding en eerste tribunerij in de grijze versie. Het compacte gevoel moet in POV én overzichtscamera zichtbaar zijn.

### Middenterrein

Begin Gent met een lege eigen vloer, boarding, toegang en de twee expliciet gedeelde onderdelen. Voeg nieuwe Gent-inrichting vervolgens afzonderlijk toe. Voorgestelde zones:

1. **Meet/juryzone:** official aan de binnenzijde van de start/finish, klein functioneel jurymeubel en vrij zicht op de naderende renners.
2. **Technische zone:** beperkte open ruimte voor onderhoud en klaarzetten; geen automatisch geladen nationale huisjes of tenten.
3. **Publiekszone:** later toe te voegen nieuw verdeelde bezoekers en eventueel een compacte neutrale bar. Leg eerst looproutes en een vrije buffer langs de piste vast.
4. **Resultatenplek:** eigen laag podium of neutrale interviewplek buiten de rij- en uitlooproutes. Een live race en een uitslagenpagina moeten ook zonder infieldpubliek correct werken.

De foto's mogen als sfeerreferentie dienen; dit wordt geen gedetailleerde reconstructie van de evenementlogistiek van één avond. Het geometrieschema vergelijkt de voorgestelde baanomvang met Vélodrome. De zonebeschrijving is een functioneel indelingsvoorstel, geen opgemeten stoelen- of veiligheidsplan.

### Zaal en plafond

Een lichte vlakke plafondlaag met een rustig raster van panelen en armaturen. Daarboven/erlangs een modulair rechthoekig balkenritme, met donkerblauwe verticale wandaccenten. De technische draagstructuur hoeft op normale speelcamera's niet tot elke klinknagel te worden uitgewerkt. Geen radialen naar een hoge centrale kroon, geen Infinity-ring uit het huidige stadion.

Grote wandvakken mogen een eigen originele wielergrafiek krijgen: abstracte snelheid, ritme en rennerfiguren in een nieuwe compositie. Behoud het idee van grote grafische vlakken zonder de bestaande muurschilderingen over te trekken. Zichtbare generieke bewegwijzering: **GENT**, **TRIBUNE**, **UITGANG**; wedstrijdinformatie via ons eigen HUD/scorebord.

## 5. Kleur, materiaal en licht

Onderstaande waarden zijn een samenhangend **voorstel** in sRGB, geïnspireerd door de foto's maar niet met een kleurkaart gemeten.

| Toepassing | Hex | Afwerking |
|---|---|---|
| Basiskleur pistehout | `#C6A87D` | Eigen planktextuur; roughness 0,78–0,88, geen hoogglans |
| Stoelen | `#D4A63D` | Mat geel/oker; kleine variatie per vak |
| Rode omranding / binnenzone | `#D82632` | Mat; grote egale vlakken met eigen typografie |
| Blauwe strook | `#3F88BC` | Duidelijk van hout te onderscheiden, niet emissief |
| Plafond | `#D8D1C4` | Licht warmgrijs; roughness circa 0,9 |
| Constructie-/wandaccenten | `#243B55` | Donkerblauw, weinig metaalglans |
| Binnenvloer / technische elementen | `#343638` | Donker mat, weinig ruis |
| Neutrale tekst en belijning | `#F2EDE2` | Gebroken wit |

**Wedstrijdlicht:** vrij neutraal/warm licht op hout en renners, donkerder achterwand en tribunezones. Eerste tuningbereik circa 4000–4500 K als artistieke referentie; gebruik geen onbevestigde Kelvinwaarde als werkelijk zaalspecificatie. Rood blijft rood onder het licht, niet oranje. Behoud huidkleur en de leesbaarheid van jerseys in de bocht.

**Trainingslicht:** gelijkmatiger en helderder, met dezelfde materialen. De bestaande optie om sfeerverlichting uit te schakelen blijft bruikbaar. De introshow mag tijdelijk kleur toevoegen, maar de race gebruikt geen voortdurende kleurwisselingen of rook die het zicht op de baan belemmert.

**Prestaties:** begin met dezelfde orde van grootte als nu: maximaal acht effectieve piste-lichten, zonder dynamische schaduwen; plafondarmaturen vooral via emissieve meshes. Presenteer en meet de uiteindelijke keuze op het doelapparaat. Deze aantallen zijn een startbudget, geen gemeten performancegarantie.

### Sponsorvrije vormgeving

Gebruik eigen panelen met geometrische strepen, nummers of de naam **Gent**. Geen echte sponsornamen, logo's, herkenbare lettermerken of letterlijk overgenomen reclamecomposities. Hout, kleurvlakken en ruimtelijke dichtheid leveren de sfeer; de echte advertentietexturen zijn geen productiemateriaal.

## 6. Wat verhuist wel en niet mee?

| Onderdeel | Besluit | Uitwerking |
|---|---|---|
| Official | **Hergebruiken** | Bestaande GLB en rig behouden; eigen plaatsingspunt bij de meet |
| Startpistool, bel, finishvlag en effecten | **Hergebruiken** | Vier bestaande animatieacties + props/controller/reset meenemen |
| Tv-zenderbox | **Hergebruiken** | Zelfde GLB; eigen plaats/oriëntatie in Gent, geen vast tweede-tiergetal |
| Twee presentatoren | **Hergebruiken** | Twee onafhankelijke spreek-/mondanimaties en bestaande bediening behouden |
| Gewone generieke mensmeshes | Optioneel later hergebruiken | Nieuwe Gent-verdeling en nieuwe look-/dichtheidskeuze; geen bestaande populatie kopiëren |
| Bestaande supporters en speciale figuren | **Niet automatisch** | Geen Wout-banner, Tour-details, hond, specifieke groepen of oude posities |
| Rennersboxen en teams | **Niet automatisch** | Geen negen nationale huisjes, teams of ingeladen boxbemanning als standaard Gent |
| Tenten, kiosken, horeca, parasols en slingers | **Niet automatisch** | Alleen nieuw ontworpen objecten die expliciet in Gent worden gekozen |
| Keldertrap, tunnel, mixed zone en sponsorwanden | **Niet automatisch** | Eigen toegang en eigen resultatenplek bepalen |
| Bestaand dak, Infinity-scherm, vlaggen en pistebranding | **Niet automatisch** | Nieuw zaal- en scorebordontwerp, eigen graphics |
| Trainingstechniek en trainingsmedewerkers | Per trainingsmodus beslissen | Functionele scripts blijven gedeeld; hun wereldobjecten krijgen eigen Gent-plaatsingen |

**Official-contract:** `VO_StartReady`, `VO_StartFire`, `VO_LastLapBell`, `VO_FinishFlag`; huidig skelet en propnamen behouden. Laat de controller dezelfde wedstrijdgebeurtenissen als de HUD gebruiken. De belgrens wordt één Gent-ronde en niet 250 m. Voeg geen tweede official-controller toe naast de bestaande.

**Tv-box-contract:** model `res://assets/broadcast/euromax_cycling_box.glb` met beide presentatoren, bestaande `commentary_box_controller.gd` en twee lokale praktische lichten. Het huidige model is in de test 14 meshes, 43 oppervlakken en 321.212 driehoeken; ontwerp dus geen onnodige duplicaten. De huidige plaatsingsreserve is circa 6,6 × 3,9 m; meet vóór plaatsing het werkelijke modelvolume. Niet schalen om een te klein balkon passend te maken.

## 7. Godot of Blender: bouwbesluit per onderdeel

| Onderdeel | Aanbevolen techniek | Nieuw Blender-model nodig? |
|---|---|---|
| Berijdbare piste, banking, blauwe strook, lijnen | Parametrisch `ArrayMesh`, één gedeeld geometrieprofiel | Nee; dit moet overeenkomen met de spelfysica |
| Rode randen, railingen, toegangshekken | Gegenereerde segmenten, instancing waar mogelijk | Nee |
| Tribunevloeren, trappen, vakken | Procedurele meshes per vak | Nee |
| Gele stoelen | Eenvoudige gedeelde stoelmesh + `MultiMesh` | Nee; bestaande geometrische kit kan technisch hergebruikt worden |
| Rechthoekige hal en vlak plafond | Modulair `BoxMesh`/`ArrayMesh`, panelen gebatcht | Nee |
| Repetitieve draagprofielen | Balken en verbindingen met `arena_steel.gd`-achtige batching | Nee |
| Wandpanelen / originele Gent-grafiek | Eigen 2D-texturen op eenvoudige vlakken | Nee; wel originele grafische uitwerking |
| Rechthoekig scorebord | Meshkader + dynamische Godot-textuur/UI | Nee |
| Official met attributen | Bestaand geanimeerd GLB + zelfstandige controller | Bestaand asset hergebruiken |
| Tv-box met presentatoren | Bestaand GLB + bestaande controller | Bestaand asset hergebruiken |
| Nieuwe markante decorstukken | Alleen na keuze en zichtbaarheidstoets | Optioneel: bijvoorbeeld een uitgewerkt jurymeubel of nieuwe bar |
| Nieuw publiek | Bestaande generieke meshes met nieuw plaatsingsplan | Nee; geen specifieke nieuwe persoon nodig voor de basis |
| Buitenaanzicht / bronzen gevelreliëfs | Buiten scope van deze speelbare binnenlocatie | Alleen bij latere expliciete opdracht; niet nabouwen voor deze fase |

Een volledig monolithisch stadion-GLB zou de parametrische baan, kwaliteitsinstellingen en plaatsing van geanimeerde objecten minder beheersbaar maken. Als een 3D-bouwer Blender gebruikt voor losse decorstukken, lever die modulair aan; de piste blijft bij de gezamenlijke Godot-geometrie.

## 8. Overdracht aan de bouwer

### Opleverstructuur

| Node onder `GentVenue` | Verantwoordelijkheid |
|---|---|
| `TrackRoot` | Gedeelde pistegenerator |
| `GentHall` | Eigen zaal, plafond, constructie en wandvakken |
| `GentStands` | Eigen vakken, trappen en stoelinstancing |
| `GentInfield` | Eigen vloer, toegang en expliciet gekozen objecten |
| `GentScoreboard` | Eigen schermvorm met gedeelde wedstrijdinformatie |
| `Anchors` | Benoemde `Marker3D`-plaatsingspunten; geen automatische acteurs |

Gebruik meters, +Y omhoog en dezelfde horizontale oriëntatie als de bestaande game: lange as Z, centrale oorsprong op het middenplein, baan volgt de rijrichting van `_at`. De naam van een Marker3D is het contract; hardcode actorposities niet nogmaals in een ander script.

| Plaatsingspunt | Betekenis |
|---|---|
| `FinishReference` | Raceafstand nul en zichtbare meetlijn uit dezelfde berekening |
| `OfficialAnchor` | Binnenzijde meet, voeten op middenvloer, kijkrichting naar naderende renners |
| `BroadcastAnchor` | Eigen balkon/positie met vrij zicht over de baan en ruimte voor heel model |
| `JuryAnchor` | Functionele juryplek buiten de actieve rijlijnen |
| `FinishCameraAnchor` | Finishfoto zonder rail/publiek in de zichtlijn |
| `ResultsAnchor` | Eigen uitslagen-/podiumplek |
| `AccessAnchor` | Toegang middenplein, niet in een actieve rijlijn |
| `IntroCamera_*` | Kort eigen cameratraject met gecontroleerde vrije ruimte |

Een in de baan liggend toegangsluik is hoogstens een gesloten visueel detail tijdens het rijden. Animeer geen opening in het berijdbare oppervlak terwijl een wedstrijd actief is.

### Mesh- en materiaalafspraken

- Artistieke Gent-assets onder `res://assets/venues/gent/`; locatiecode onder `res://venues/` of een aparte Gent-module.
- Herhaalde statische onderdelen in `MultiMesh` per mesh/materiaal/vak; geen duizenden losse licht- of stoel-nodes.
- Gescheiden materialen `Gent_Wood`, `Gent_Red`, `Gent_Seats`, `Gent_Ceiling`, `Gent_Structure`, `Gent_Floor`, `Gent_Graphics`.
- Correcte normals en UV's, geen negatieve schaal om tekst goed te draaien. Geen fotobanners met echte sponsors.
- Geen collision op decoratieve tv-box/tribunes als gameplay die niet gebruikt. Berijdbare geometrie en raceafstand blijven door de game bepaald.
- Geen nieuwe permanente schaduwwerpers of volumetrische effecten zonder meting; lage grafische stand moet het volledige parcours behouden.
- Bij losse Blender-assets: `.blend`-bron + `.glb`, transforms toegepast, 1 unit = 1 m, kleine textuurset, afzonderlijke verplaatsbare modules. Namen en bestaande animaties van gedeelde assets niet wijzigen.

### Fasen en beoordelingsbeelden

1. **Grijze piste en zaal:** bovenaanzicht, bochtprofiel, POV op rechte en in bocht. Controleer omvang, maten, meetlijn, bovenrand en bruikbare binnenruimte.
2. **Vorm en kleuren:** zitrijen, rode zones, plafond, wandritme, scorebord en eigen graphics. Nog geen supporters of oude props als vulling toevoegen.
3. **Functionele acteurs:** official, attributen, tv-box en beide presentatoren op hun eigen plaatsingspunten; camera's en animaties controleren.
4. **Expliciete Gent-aankleding:** nieuw gekozen publiek/technische zone/horeca toevoegen na indelingscontrole.
5. **Spelcontrole:** races en trainingen op beide locaties, NL/EN, normale/eenvoudige graphics, frametimevergelijking op echte hardware.

## 9. Goed te keuren ontwerpbesluiten

Dit voorstel kan na akkoord als bouwbrief dienen. Mijn aanbevolen pakket is:

- **Gent** als eigen compacte locatie met nominale baanlengte **1000/6 m**, getoond als **166,67 m**, en maximaal **52°** banking.
- De geometrische startwaarden uit §3 gebruiken voor de eerste blockout; geen pretentie van een exacte opmeting. Proporties en rijgedrag bepalen binnen deze brief de verdere tuning.
- Het rood/oker/hout/crème-palet en de rechthoekige hal met vlak leesbaar plafond volgen.
- De basis procedureel in Godot bouwen; geen nieuw verplicht Blender-stadionmodel.
- Alleen official/attributen en tv-box/presentatoren expliciet meenemen. Alle overige inrichting wordt nieuw en afzonderlijk gekozen.
- Eerst een grijze versie beoordelen voordat tijd naar gedetailleerde Gent-decorstukken gaat.

De volledige implementatie van de korte-baan-wedstrijdlogica en stadionkeuze staat als uitvoerbare checklist in [taken.md](../taken.md). Deze ontwerpgoedkeuring is nog geen verklaring dat Gent al in het spel beschikbaar is.
