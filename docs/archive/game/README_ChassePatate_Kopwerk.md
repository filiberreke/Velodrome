# Chasse Patate en Kopwerk op het middenplein

## Installatie

Pak deze ZIP uit naast `project.godot`, over de huidige versie met de lichte/blauwe
Velodrome-boarding. Behoud de mappenstructuur en vervang `infield_details.gd`.
Open daarna het project opnieuw zodat Godot de twee nieuwe afbeeldingen importeert.
Alleen gewijzigde en nieuwe bestanden zijn opgenomen.

De volledige gewijzigde werkkopie staat in `work/branded_kiosks_project` van de
Codex-workspace. Het oorspronkelijke project is niet rechtstreeks overschreven.

## Kraampjes en terrassen

De bestaande horecazone op het zuidelijke middenplein heeft twee nieuwe modellen:

- **Chasse Patate**: geel-groen frietkot, toonbank, frituurbakken, afzuigkap,
  frietzakjes, sausflessen en verkoper. De aangeleverde branding staat op de
  voorzijde, zijkanten, achterkant en het dak.
- **Kopwerk**: ronde koffiekop met groot crème/oranje oor, donkerbruine romp,
  crème verkooptoog rondom en een hoge logoband. De volledige toogrand blijft
  vrij van dakpalen: precies één centrale pilaar draagt het dak. De logoband
  herhaalt de branding rondom; bovenop staat het tandwiel/koffiekoplogo. Binnenin
  staan een barista, espressomachine en koffiemolen.
- **Per kraam zes tafeltjes**, elk met een eigen parasol, drie stoelen en een
  zittende gast. Chasse Patate gebruikt geel/groen; Kopwerk crème/bruin/oranje.

De kraampjes vervangen de oude friettruck en de gewone zuidelijke koffiestand.
De andere wafels- en snackskramen zijn verplaatst om ruimte te laten voor de
nieuwe terrassen. Merch, banken en de overige delen van het middenplein blijven
aanwezig. De lichtslingers boven deze horecazone hangen hoger, vrij van de dakborden.
De tafel- en kraamgebieden zijn uitgesloten van de willekeurige menigteplaatsing.

De kraampjes bestaan uit echte Godot-geometrie en gebruiken de aangeleverde PNG's
ongewijzigd als textuur. Er is voor het spel geen Blender-installatie nodig.
De vaste geometrie is per materiaal samengevoegd: 17 groepen voor Chasse Patate
en 13 voor Kopwerk, inclusief de terrassen en statische personen. Er zijn geen
extra botsingsvormen of wijzigingen aan spelregels, HUD, rijlijnen of exports.

## Uitgevoerde controles

Godot 4.7.2 headless: projectimport, statische scriptcontrole, gerichte
kraampjescontrole, integratie in de echte hoofdscene, bestaande HUD-test en
het starten van de hoofdscene. Alle controles zijn geslaagd, zonder scriptfouten.

De gerichte controle verifieert:

- twee kraampjes, elk met zes tafels, zes parasols en achttien stoelen;
- één centrale daksteun en geen steunpalen in de serveerzone langs de buitenrand;
- de geometrie binnen de toegewezen ruimte van het middenplein;
- beschermde plaatsen voor terrassen en een beperkt aantal materiaalgroepen;
- de aanwezigheid in de echte arena en de vervanging van de oude friettruck.

De werkelijk door Godot gegenereerde modellen zijn daarnaast naar GLB geëxporteerd
en met Blender 5.2 op de CPU gerenderd. Zowel het overzicht als een detail van
Kopwerk zijn visueel gecontroleerd. Die beelden zijn renders van de echte modellen,
geen AI-mockups. Ze tonen geen Godot-spelcamera of stadionbelichting.

Niet uitgevoerd: een visuele GPU-spelrun in Godot, volledige visuele controle
van alle stadionobjecten en menigtes, FPS-metingen op de doelcomputer, hardwaretests
of exportbuilds. De bekende Godot-melding over Windows-rootcertificaten staat los
van deze geslaagde controles.

## Zelf bekijken en testen

1. Open de hoofdscene en bekijk de zuidelijke horecazone op het middenplein.
2. Controleer vanuit de zijcamera en overzichtscamera de logo's en terrassen.
3. Bekijk Kopwerk ook vanaf de achterkant: de toog en serveeropening lopen rond
   en het dak heeft langs de rand geen palen.
4. Controleer de afstand tot de teamzone, bestaande kramen, lichtslingers en menigte.

Gerichte controle vanuit de projectmap:

```powershell
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_branded_kiosks.gd
```

Optioneel maakt dezelfde test een GLB van de echte geometrie voor een externe render:

```powershell
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_branded_kiosks.gd -- --kiosk-preview
```
