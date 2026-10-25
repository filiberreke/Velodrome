# Boarding — gelijk blauw en afwisselend lichte Velodrome

Pak deze ZIP uit naast `project.godot`, over de vorige sponsorboarding-patch.
Behoud de mappenstructuur en vervang de twee boarding-scripts. Open het project
opnieuw om de nieuwe lichte afbeelding te importeren. Alleen gewijzigde en nieuwe
bestanden zijn opgenomen. De werkkopie staat in `work/sponsor_variants_project`;
het oorspronkelijke project is niet rechtstreeks overschreven.

## Aanpassingen

- Wielerpraat en PelotonPredictor krijgen dezelfde blauwe achtergrond, ook in de
  helderdere delen van de bronafbeeldingen. De vorige correctie beschermde een
  helder blauw kleurkanaal alsof het wit was en liet daardoor kleurverschillen door.
  De correctie beschermt nu neutraal wit, zodat de blauwe achtergrond volledig
  wordt vervangen en witte/oranje tekst behouden blijft.
- Op de laatste rechte lijn wisselen de blauwe en lichte Velodrome-affiche af.
  Er zijn twintig panelen: blauw, licht, blauw, licht, enzovoort. Het laatste
  paneel vóór de eerste bocht is dus licht.
- De Velodrome-varianten behouden hun eigen kleuren. De blauwe kleurcorrectie
  geldt uitsluitend voor Wielerpraat en PelotonPredictor in de eerste bocht.

De lichte variant komt uit `velodrome-boarding-licht.png` in de aangeleverde
boarding-map. Het PNG-bestand is ongewijzigd overgenomen; mipmaps zijn ingeschakeld.

## Controle

Godot 4.7.2 headless: import, statische controle en starten van de hoofdscene
geslaagd. De gerichte boardingcontrole slaagt eveneens:

- 9.803 achtergrondpunten uit de twee gebruikte afbeeldingen worden volledig
  naar dezelfde achtergrond omgezet, zowel bij lineaire als sRGB-invoerwaarden;
- de controle met sRGB-invoer reproduceert de oude fout bij 9.016 van die punten;
- wit en oranje worden door de kleurcorrectie ongemoeid gelaten;
- de juiste blauwe en lichte afbeeldingen worden afgewisseld;
- het laatste lichte paneel sluit aan op het einde van de rechte lijn;
- de Velodrome-materialen hebben de blauwe normalisatie uitgeschakeld.

Dit controleert de shaderformule en de opgebouwde geometrie; er is geen nieuwe
visuele GPU-spelrun of exportbuild uitgevoerd. Bekijk de eerste bocht en de laatste
twee panelen vóór die bocht nog even in het spel. De bekende omgevingsmelding over
Windows-rootcertificaten staat los van de geslaagde controles.

Automatische controle vanuit de projectmap:

```powershell
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_boarding_variants.gd
```
