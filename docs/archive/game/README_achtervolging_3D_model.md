# Velodrome 250 X — apart achtervolgingsmodel

## Installeren
Deze patch bouwt voort op de laatste versie met de halve-ronde-HUD en segmentgemiddelden. Pak uit in de projectmap waar project.godot staat; vervang main.gd en rider_visual.gd en voeg de nieuwe bestanden toe. Dit is een patch met uitsluitend gewijzigde/nieuwe bestanden, geen compleet Godot-project. Laat Godot de nieuwe GLB importeren.

## Het model
In Blender 5.2.2 LTS gemaakt op basis van de eigen bewerkbare rennermodelbron en de aangeleverde referentiefoto. Een gestileerde interpretatie passend bij de bestaande spelgraphics, geen exacte replica van het merkmodel op de foto.
- Lagere romp, smaller geplaatste onderarmen, gebogen ellebogen en handen op de tijdritopzetsturen.
- Apart achtervolgingscockpit met elleboogkussens, steunen en opzetsturen; steviger frameprofiel en twee dichte wielen.
- Helm met vizier, skinsuit, pedalen en geanimeerde benen en wielen.
- Nieuwe gesloten lichaamsgeometrie voor de compacte heup-/romphouding; bestaande zes lichaamsbouwinstellingen en kledingmaterialen blijven ondersteund.
- De eigen kleuren van de renner blijven door het spel bepaald. De meegeleverde Blender-preview gebruikt een blauwe voorbeeldoutfit; de spelkleuren kunnen verschillen.

Alleen bij achtervolging gebruikt main.gd dit model, voor zowel speler als tegenstander (AI of opgeslagen rit). De trapfase blijft door de cadans bepaald. Bij hoge vermogens en na de finish blijft de achtervolgingsrenner in de aerohouding. De overige spelvormen behouden hun oorspronkelijke model en sprint-/overwinningsanimaties. De racefysica, lijnkeuze, HUD en ritbestanden zijn niet gewijzigd door deze patch.

## Bewerken in Blender
Open assets/source_blender/velodrome_pursuit_rig.blend. Dit is de bewerkbare IK-rig; voeten volgen de pedalen en handen het cockpitdoel. De texturen zijn in het .blend-bestand ingepakt.
assets/source_blender/build_pursuit_rider.py genereert het model opnieuw. Blender kan dit via Scripting uitvoeren, of via een achtergrondopdracht met -b -P en het scriptpad. Stel de omgevingsvariabele RIDER_OUT in voor de uitvoermap; anders komt de uitvoer in source_blender/out. Het script maakt het .blend-bestand, de GLB en twee previewrenders. Kopieer een opnieuw geëxporteerde GLB naar assets/riders/velodrome_pursuit.glb en laat Godot opnieuw importeren.
De GLB bevat twee meshes (Rider en Bike), één skelet en vier compatibele animatieclips. Alle vier houden de aero-bovenlichaamshouding aan. source_blender wordt door de bestaande .gdignore uitgesloten van Godot-import; Godot gebruikt de GLB, niet de .blend. Blender is dus niet nodig om de patch te spelen.

## Gecontroleerd
- Twee daadwerkelijke Blender-renders bekeken: zijaanzicht en driekwartaanzicht. Dit zijn renders van het model, geen gegenereerde conceptafbeeldingen.
- Het opgeslagen .blend-bestand opnieuw geopend en gecontroleerd: bewerkbare rig, ingepakte texturen, zes shape keys en hand-/voetdoelen op frames 0, 6, 15, 22 en 30. De grootste gemeten afstand van de betreffende botuiteinden tot hun IK-doelen is circa 0,00000012 meter. Dit meet rigcontact, geen volledige botsingscontrole van huid en kleding.
- Godot 4.7.2 headless: import, scriptcontrole, modeltest, achtervolgingstest, HUD-test, menutest en hoofdscene laden: alle zeven geslaagd zonder scriptfouten.
- Modeltest controleert de aparte scène voor beide achtervolgingsrenners, beschikbare animaties, cadansfase, behoud van aero bij 1200 W en na finish, en terugkeer naar het oorspronkelijke scratch-model met staande sprint.
- Achtervolgingstest omvat 1 en 4 km tegen AI en opgeslagen rit. Het oorspronkelijke rennerbestand en de fysica-/HUD-scripts zijn byte voor byte ongewijzigd.

Niet getest: een visuele Godot-speeltest met de werkelijke camera's en GPU, prestaties op jouw hardware, een fysieke trainer en alle kleding-/lichaamsbouwcombinaties. De renders bewijzen de Blender-weergave; Godot belichting en materialen kunnen anders ogen. De headless omgeving meldt nog dat de certificatenopslag niet gelezen kan worden. Netwerkfunctionaliteit is niet getest. De eerdere materiaalmeldingen van de losse proefopstelling komen niet voor in de uiteindelijke integratietest.

## Zelf proberen
1. Start 1 km achtervolging tegen AI: beide renners moeten twee dichte wielen, elleboogsteunen en de nieuwe houding hebben.
2. Controleer met verschillende camera's handen, ellebogen, knieën en voeten; varieer de cadans en probeer ook hoog vermogen. De houding blijft laag.
3. Probeer 4 km en een opgeslagen rit; de vorm van de tegenstander is dezelfde nieuwe achtervolgingsvariant.
4. Keer terug naar scratch: oorspronkelijke fiets/houdingen terug, met staande sprint bij hoog vermogen.

De nieuwe Godot-test staat in tests/test_pursuit_model.gd en is vanuit Godot headless met --script res://tests/test_pursuit_model.gd uitvoerbaar. De bestaande achtervolgings-, HUD- en menutests blijven bruikbaar.
