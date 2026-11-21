# SjampanjeBar, PursoetBar en noordbocht

## Project en installatie

De basis is de actieve projectmap `C:/Users/romboti/OneDrive - Cronos/Documenten/Priv/godot/velodrome`, met de nieuwste journaliste in regenboogtrui, Wielerpraat-dakmicrofoons, pizza-oven en eerdere sponsorboarding. Er is eerst een werkkopie gemaakt; oudere export-/testkopieën zijn niet als basis gebruikt. De bestaande hoofd-/racecode is met hashes gecontroleerd.

De patch-ZIP bevat uitsluitend gewijzigde en nieuwe bestanden. Uitpakken in de bestaande projectmap met `project.godot`, met behoud van de mappenstructuur. Er is geen Blender of Python nodig om de bars te gebruiken. De scènes en hun materialen zijn volledig opgeslagen in Godot-bronnen.

## Indeling na de laatste aanpassing

- **SjampanjeBar** staat noordelijk op X −5,8 / Z 37, aan de westkant van de grote gele tent, tegenover de pizza-oven. De voorkant wijst naar −Z, het middenplein in. De noordelijke gele tent heet in deze projectversie nog Bier/Trust No One; de bestaande naam en branding zijn behouden.
- **PursoetBar** vervangt het wafelkraam aan de zuidzijde, op X −8,5 / Z −16. De scene is −90° rond Y gedraaid, zodat de verkoopopening naar het middenplein wijst. Het oude wafelkraam wordt niet meer opgebouwd. Een vuilnisbak is naar de zijkant verplaatst om de balie vrij te houden.
- Bij de noordelijke bar staan **vijf tafeltjes en twintig expliciet geplaatste supporters**. De steunpunten voor willekeurig publiek houden die tafels en de bar vrij.

## Herbruikbare scènes

`scenes/bars/SjampanjeBar.tscn` en `scenes/bars/PursoetBar.tscn` zijn gewone Node3D-scenes met oorsprong op de grond in het midden, Y omhoog, voorzijde −Z en achterzijde +Z. Ze kunnen rechtstreeks in een andere Godot-scène worden geplaatst en gedraaid.

Sjampanje volgt de bouwbrief: twaalfzijdige basis van 4 m, rechte wand tot 2,4 m, flesschouders van 4,2 m naar 1,05 m diameter tot 3,25 m en een gouden hals/dop tot 4,4 m. Drie voorste facetten vormen de verkoopopening; balie rond 1,05 m. Er zijn groene en ivoorkleurige merkpanelen met klassieke rechtopstaande serifletters, het S-monogram, de mascotte en de spreuk. De achterzijde heeft een gesloten decoratieve deur met gouden klink en een apart naar buiten gericht etiket. Deze deur is niet geanimeerd of toegankelijk. Het interieur heeft ivoorkleurige wanden, planken, enkele flessen en opaque flutes.

Pursoet heeft een footprint van 3 × 3 m, petroleumkleurige hoekstaanders, een dakrand op 2,2 m en punt op 3,1 m. Het dak is 3,2 m breed; volant 0,25 m. Balie circa 2,65 × 1,0 × 0,5 m. Het originele scriptwoordmerk staat voor én achter op de volant, op de balie en groot op de achterwand; de gesloten zijwand draagt het fles/citrusbeeldmerk. De rechterzijde blijft open voor personeel.

Beide scènes hebben aparte groepen voor constructie, balie, opdruk, interieur/props en eenvoudige box-collisions. Opaque StandardMaterial3D-materialen; geen glasbreking of transparante buitenwanden. Kleine flessen en flutes verdwijnen op afstand. Er zijn geen nieuwe lampen toegevoegd.

De bronbuilder is `tools/build_bars.gd`. Opnieuw genereren: Godot `--headless --path . --script res://tools/build_bars.gd`. De plaatsing staat in `north_bars.gd`; de bestaande infield-builders roepen deze module aan. Het gebruikte beeldprompt en de herkomst van de vlakke etiketten staan in `assets/bars/README_textures.md`.

## Twee uitbaters naar de aangeleverde referentie

De herbruikbare Sjampanje-scène bevat twee afzonderlijke low-poly GLB-modellen in `Actors`. De stevige uitbater met olijfgroene jas, blauw/gele strepen, baard en hoge zwarte hoed staat achter de toog. De lange uitbater in oranje pak en pet, met witte halsdoek, staat naast de bar met een gedragen plateau en zeven champagneglazen. De glazen zijn bewust opaque en goedkoop te renderen. Het zijn vaste servicehoudingen, zonder loop- of bedienanimatie.

De Blender-bron staat in `assets/source_blender/crowd/build_sjampanje_hosts.py` en gebruikt de bestaande `people.py` en `vlib.py` van het project. Blender 5.2.2 is alleen nodig om de modellen opnieuw op te bouwen; Godot importeert de meegeleverde GLB's rechtstreeks. De figuren zijn naar de cartoonreferentie vertaald in de bestaande publieksstijl.

## Boarding noordbocht

De buitenboarding over de hele noordbocht krijgt het ritme van de beschikbare mockup: **Tour d’Ambiance → Sjampanje wit → Sjampanje groen → Tour d’Ambiance**, met het Tour-paneel als gedeelde separator tussen herhalingen. Vanuit het middenplein gelezen: Tour–wit–groen–Tour–wit–groen–Tour. Er staan geen twee Tour-panelen direct tegen elkaar.

Tour blijft vierkant; de Sjampanje-banners zijn circa 3:1. De fysieke paneelbreedtes volgen die verhouding. De oorspronkelijke hoogte van 1,2 m en de bestaande gebogen boardingpositie blijven behouden. Teksten zijn aan de pistezijde leesbaar; oude kleine panelen in die bocht worden onderdrukt. De bestaande eerste bocht en laatste rechte lijn behouden hun sponsorpatroon.

## Uitgevoerde controles

Geslaagd met Godot 4.7.2:

- Headless import en hoofdscriptcontrole.
- Scènes genereren en opnieuw laden; hoogtes, materiaaltypen, front-/achteropdruk, beide uitbaters met plateau en eenvoudige collisions controleren.
- Raycasts door beide verkoopsopeningen en de open personeelstoegang van Pursoet: geen blokkerende collision.
- Plaatsing in de echte hoofdscène: Sjampanje noordelijk, Pursoet op de oude wafelplek, twintig supporters/vijf tafeltjes en de bestaande gele tent/pizza-oven behouden.
- Boardingtest: volledige noordbocht gedekt, de gevraagde leesvolgorde, aansluitende paneelgrenzen, behoud van verhouding vierkant/breed, volledige UV-bereiken en drie gebatchte sponsormeshes.
- Bestaande boarding-variantcontrole geslaagd.
- Hoofdscène twintig frames laten draaien zonder nieuwe scriptfouten.
- **Echte Godot GPU-screenshots**, met OpenGL Compatibility op Intel Iris Xe, van beide bars voor/achter, de noordelijke en zuidelijke spelomgeving en de noordbocht. De galerijbeelden tonen links de achterzijde en rechts de voorzijde. Dit zijn viewportcaptures van de spelrenderer, geen AI-mockups of Blender-renders. UI is verborgen voor deze screenshots.

De bestaande melding over de Windows-rootcertificaten kan op deze computer in de Godot-log staan; de nieuwe scripts geven geen fouten.

Niet uitgevoerd: een volledige interactieve wedstrijd, FPS-benchmark onder alle camera's en instellingen, of een nieuwe Windows-export. Trainer-, FIT- en Strava-code zijn niet gewijzigd en zijn niet opnieuw hardwarematig getest.

## Zelf testen

1. Open het actieve project en wacht op import van de nieuwe textures/scènes.
2. Open beide `.tscn`-bestanden afzonderlijk: controleer maat, woordmerk, voor- en achterzijde.
3. Start de game en bekijk Sjampanje op het noordplein en Pursoet op de oude wafelplek. Bekijk ook de verkoopopeningen en de route langs de tafelgroepen.
4. Rijd door de noordbocht: Tour / wit / groen / Tour, zonder lege stukken of oude overlappende affiches.
5. Optioneel vanuit de projectmap:

```powershell
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_bars.gd
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_north_boarding.gd
```

Verwachte eindmeldingen: `BARS_OK` en `NORTH_BOARDING_OK`.
