# Velodrome 250 X — mixed-zone en noordelijk horecaplein

Deze patch bouwt voort op de vorige Chasse Patate/Kopwerk-patch. De ZIP bevat uitsluitend gewijzigde en nieuwe bestanden. Pak ze uit in de bestaande Godot-projectmap waar `project.godot` staat, met behoud van de mappenstructuur. Maak vooraf een kopie van `infield_details.gd`.

## Indeling

- Wielerpraat wordt een mixed-zone op dezelfde plaats (X 9,4 / Z 23). De blauwe loper loopt noord-zuid door beide open zijkanten naar het podium. Binnen staan een renner met helm, interviewer en microfoon; buiten staat een tv-camera met cameraman. De oostelijke achterwand toont het Wielerpraat-logo aan beide kanten, met leesbare tekst vanaf de piste.
- Het podium staat op de oude plek van de kleine gele biertent (X 9,4 / Z 16), met publiek aan de voorkant. De toegangsroute blijft vrij van willekeurig geplaatste bezoekers.
- De biertent staat op de oude podiumplek (X 0 / Z 41,5). De vloeroppervlakte verdubbelt van 3 × 3 naar 6 × 3 meter; de hoogte blijft vergelijkbaar. Dak, achterwand en toog zijn geel. Aan de noordelijke rugkant staat de bestaande gele TRUST NO ONE-banner, zichtbaar vanaf de bocht. De voorkant blijft herkenbaar als biertent, met opschrift, drie tappen en bediening.
- De tentkleur wordt uit de gele achtergrond van de originele banner bemonsterd. Banner en tent gebruiken normale belichting en dezelfde ruwheid. De banner is dus niet langer onbelicht/felgeel terwijl de tent in de schaduw staat. De oorspronkelijke PNG is ongewijzigd; een kleine kleurvariatie in de afbeelding en natuurlijke schaduwverschillen tussen dak en wand blijven mogelijk.
- Naast de biertent staat een pizza-oven (X 7,2 / Z 36,5), met koepel, boogopening, schoorsteen, werkblad, pizza's en bediening. Het terras telt drie ronde tafels, negen stoelen en drie zittende gasten. Een bestraat vlak verbindt deze noordelijke horeca met het bestaande plein.
- De overige kraampjes, twee zuidelijke kiosken en hun terrassen blijven behouden. Een vuilnisbak is iets verplaatst om het publiek voor het nieuwe podium ruimte te geven.

Dit is scène-aankleding: de interviewopstelling is statisch. Er is geen nieuwe automatische wandeling, uitslaggestuurde huldiging of besturing van wedstrijdrenners naar de mixed-zone toegevoegd. De loper en afzetpaaltjes maken de bedoelde route zichtbaar. Wedstrijd-, HUD-, trainer- en exportcode zijn niet gewijzigd.

## Getest

- Godot 4.7.2 headless import: geslaagd.
- Hoofdscript parsen: geslaagd.
- De echte hoofdscène starten en twintig frames laten draaien: geslaagd.
- `tests/test_north_infield.gd`: geslaagd. Controleert de verplaatste objecten, dubbele vloeroppervlakte, daadwerkelijke logo-geometrie aan twee kanten, tekstoriëntatie, vrije noordelijke doorgang, pizza-zitplaatsen, eindige geometrie binnen het middenplein, behouden zuidelijke kiosken en normale belichting van de bierbanner.
- Bestaande Chasse Patate/Kopwerk-controle: geslaagd.
- Visuele controle via Blender CPU-renders van de uit Godot geëxporteerde echte geometrie. Deze renders zijn geen screenshots van de draaiende game; de bestaande Godot-publiekshaders en Label3D-tekst worden niet volledig door het renderformaat weergegeven.

Niet getest: interactieve GPU-spelrun, zichtbaarheid vanuit alle bewegende spelcamera's, FPS op de spelcomputer en een nieuwe Windows-export. Trainerverbinding en Strava-upload zijn niet opnieuw getest; hun code is ongewijzigd. Godot geeft op deze computer de bestaande melding over de Windows-rootcertificaten; er zijn geen nieuwe scriptfouten in de geslaagde controles.

## Zelf controleren

1. Open het bestaande project in Godot en wacht tot de nieuwe banner geïmporteerd is.
2. Start het spel. Bekijk de noordelijke zone vanaf de piste: logo op de buitenkant van Wielerpraat, geel bierkraam op de kop van het middenplein, TRUST NO ONE op de rugkant en pizza-oven ernaast.
3. Bekijk ook de binnenkant: open mixed-zone met interview, loper naar het nieuwe podium, drie pizzatafels en vrije doorgangen.
4. Vergelijk het geel van banner en tent bij dezelfde kijkhoek. Beide reageren nu op hetzelfde licht; het dak kan door zijn andere hoek vanzelf lichter of donkerder ogen.
5. Optioneel, vanuit de projectmap in PowerShell:

```powershell
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_north_infield.gd
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_branded_kiosks.gd
```

De eerste controle eindigt met `NORTH_INFIELD_OK`, de tweede met `BRANDED_KIOSKS_OK`.
