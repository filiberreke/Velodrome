# Wielerpraat-tent — woordmerk en vier dakmicrofoons

Deze aanvulling hoort bovenop `velodrome_250_X_noordplein_mixed_zone_patch.zip`. Pak de bestanden uit in dezelfde Godot-projectmap, met behoud van de mappenstructuur. Alleen gewijzigde en nieuwe bestanden zijn opgenomen.

## Wijzigingen

- De achterzijde naar de piste toont uitsluitend het woord **WIELERPRAAT** uit het bestaande logo, zonder microfoon of onderschrift.
- Op elk van de vier schuine dakvlakken staat één microfoon uit hetzelfde logo. De bovenkant van elke microfoon wijst naar de dakpunt; vanaf de bijbehorende buitenzijde staat het symbool rechtop.
- Het opschrift `WIELERPRAAT • MIXED ZONE` bij de dakrand is verwijderd.
- De binnenkant houdt het bestaande volledige logo. De blauwe loper en de interviewopstelling blijven behouden.
- De opdruk gebruikt UV-uitsneden van de bestaande afbeelding. Een kleine shader verwijdert uitsluitend de blauwe afbeeldingsachtergrond, zodat de microfoons rechtstreeks op het tentdoek lijken te staan. Er zijn geen nieuwe of gewijzigde afbeeldingsbestanden nodig.

## Controles

Godot 4.7.2 headless import, hoofdscriptcontrole en het opstarten van de echte hoofdscène gedurende twintig frames zijn geslaagd. De bijgewerkte `tests/test_north_infield.gd` controleert ook de daadwerkelijk gegenereerde opdrukgeometrie: vier dakmicrofoons op de schuine dakvlakken, de uitsnede voor het woordmerk aan de pistezijde, behoud van het binnenlogo en het verwijderen van de tekst bij de dakrand.

Visueel gecontroleerd met Blender CPU-renders van de uit Godot geëxporteerde geometrie. Voor deze renders wordt de blauwe-achtergrondmaskering nagebootst in een Blender-materiaal; dit is geen screenshot van de spelrenderer. Er is geen interactieve Godot GPU-run of FPS-meting uitgevoerd. Shaderweergave, randjes en transparantie moeten daarom nog vanuit de spelcamera op de doelcomputer worden nagekeken. De bestaande melding over het lezen van de Windows-rootcertificaten staat los van deze wijziging.

## Zelf testen

1. Open het project in Godot en wacht tot de nieuwe shader geïmporteerd is.
2. Bekijk de tent vanaf de piste: alleen het woord WIELERPRAAT op de achterwand.
3. Bekijk het dak van verschillende kanten: vier microfoons, zonder tekst of blauwe rechthoeken rond de symbolen.
4. Controleer binnenin het tentje het volledige logo en de interviewopstelling.

Optioneel vanuit de projectmap:

```powershell
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_north_infield.gd
```

De controle eindigt met `NORTH_INFIELD_OK`.
