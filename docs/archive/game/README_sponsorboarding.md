# Sponsorboarding — laatste rechte lijn en eerste bocht

Pak deze ZIP uit naast `project.godot`, over de huidige versie met de gedraaide
Tour d’Ambiance-affiche. Behoud de mappenstructuur en vervang `arena.gd`.
Open daarna het project opnieuw in Godot zodat de drie PNG's worden geïmporteerd.
Alleen nieuwe en gewijzigde bestanden zijn opgenomen.

Geplaatst op de buitenboarding, over vrijwel de volledige boardinghoogte:

- Laatste rechte lijn vóór de normale finish: aansluitend herhaalde Velodrome-affiches.
- Eerste bocht, boven de bestaande Wielerpraat-afbeelding op de piste:
  afwisselend Wielerpraat en PelotonPredictor, zonder open stukken tussen de panelen.

Het aantal herhalingen wordt afgestemd op de fysieke lengte van elk baanvak
en de beeldverhouding van de afbeeldingen. De panelen volgen de ronde vorm
en de hoogte van de boarding. Ze zijn vanuit de piste en het middenplein leesbaar.
De overige helft van de boarding behoudt voorlopig zijn bestaande aankleding.
De bestaande afbeelding op de piste en de gedraaide Tour d’Ambiance-affiche blijven behouden.

Wielerpraat en PelotonPredictor krijgen bij het weergeven dezelfde blauwe
achtergrond (#1C4B91). Daarvoor gebruikt het materiaal een selectieve omzetting
van het blauw; de aangeleverde PNG's zelf blijven ongewijzigd. Wit en oranje van
logo's en tekst worden behouden. Velodrome gebruikt zijn oorspronkelijke kleuren.
Alle drie textures gebruiken mipmaps voor een rustiger beeld op afstand.

De werkkopie staat in `work/sponsor_boarding_project`. Het oorspronkelijke
project is niet rechtstreeks overschreven. Spelregels, HUD, fysica en exports
zijn niet gewijzigd.

Controle met Godot 4.7.2 headless: PNG-import, statische scriptcontrole en starten
van de volledige hoofdscene geslaagd, zonder scriptfouten. De PNG's zijn ook
vergeleken met de aangeleverde bestanden en zijn byte voor byte gelijk.

Niet uitgevoerd: een visuele GPU-spelrun, beoordeling van de shaderkleuren en
leesbaarheid in het spel, of exportbuilds. Controleer de twee vakken met de
zijcamera/overzichtscamera; vooral de leesrichting, de aansluitingen en de
gelijke blauwe achtergrond in de eerste bocht verdienen een visuele controle.
De bekende omgevingsmelding over Windows-rootcertificaten staat los van de checks.
