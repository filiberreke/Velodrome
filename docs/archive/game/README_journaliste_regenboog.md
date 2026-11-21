# Velodrome — journaliste in regenboogtrui

Deze patch hoort bovenop de vorige Wielerpraat-opdrukpatch. Pak de bestanden uit in de bestaande projectmap met `project.godot`, met behoud van de mappenstructuur. Alleen nieuwe en gewijzigde bestanden zijn opgenomen. Blender is niet nodig om het spel te starten.

## Uiterlijk

De journaliste in de mixed-zone krijgt een eigen 3D-model in de bestaande cartoonstijl, gebaseerd op de opgegeven kenmerken uit de foto:

- Kort, honingblond/lichtbruin bobkapsel tot bij de kaak, met lichte haaraccenten.
- Donkere zonnebril boven op het haar, met zichtbaar montuur, glazen en brilpoten.
- Witte trui met vijf banen op de romp en beide korte mouwen. De volgorde is op verzoek **blauw, rood, zwart, geel, groen** van boven naar beneden. Ook het smalle kraagdetail gebruikt die volgorde.
- Korte blauwe jeansshort met lichtere omslagen, blote benen en lichte schoenen.
- Een opgeheven hand gericht naar de bestaande interviewmicrofoon.

Het model vervangt uitsluitend de journaliste. Haar bestaande positie en oriëntatie in de tent blijven behouden. De andere bezoekers en medewerkers gebruiken hun bestaande modellen. De eerdere woordmerk- en dakopdruk, het podium, de biertent en het pizzaterras blijven behouden.

Het geïmporteerde model is `assets/people/journaliste_regenboog.glb`. De meshes en kleuren zijn zelfstandig in het GLB opgenomen: geen fototextuur en geen extra kledingshader. Het model is een vaste interviewpose, zonder nieuwe animatie of automatische interviewsequentie.

## Controles

Geslaagd met Godot 4.7.2 headless:

- Project/model importeren.
- `tests/test_journalist.gd`: modelafmetingen, materiaal voor haar en bril, korte jeans, vijf kleurbanen en hun daadwerkelijk gemeten volgorde op de romp, plus gebruik van het nieuwe model op de juiste plek in de echte hoofdscène.
- `tests/test_north_infield.gd`: bestaande controles voor mixed-zone, opdruk, loper, podium, bier en pizza.
- Hoofdscript parsen en de hoofdscène twintig frames laten draaien.

Daarnaast visueel gecontroleerd met een Blender CPU-render van het daadwerkelijke GLB-model. Dit is geen screenshot van de draaiende Godot-game. Niet getest: interactieve Godot GPU-run, zichtbaarheid vanuit alle spelcamera's en FPS. Er is geen wedstrijd-, HUD-, trainer- of exportcode gewijzigd. De bestaande lokale Godot-melding over de Windows-rootcertificaten staat los van deze wijziging.

## Zelf testen

1. Laat Godot het nieuwe GLB-model importeren en start het spel.
2. Bekijk de journaliste in de Wielerpraat-tent: haar, bril op het hoofd, regenboogbanen en korte jeans.
3. Controleer de vijf banen op de romp van boven naar beneden: blauw, rood, zwart, geel, groen.
4. Controleer vanaf de zijkant de plaatsing bij de microfoon.

Optioneel vanuit de projectmap:

```powershell
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_journalist.gd
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_north_infield.gd
```

Verwachte eindmeldingen: `JOURNALIST_OK` en `NORTH_INFIELD_OK`.

## Model opnieuw opbouwen

Het nieuwe bronbestand staat onder `assets/source_blender/crowd/build_journalist.py` en gebruikt de bestaande `people.py` en `vlib.py` uit dezelfde map. Getest met Blender 5.2.2 LTS. Uitvoeren met Blender `--background --python` maakt het GLB opnieuw aan. De oorspronkelijke referentiefoto wordt hierbij niet geladen of meegeleverd.
