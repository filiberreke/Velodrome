# Tour d’Ambiance op de piste

Pak deze ZIP uit naast `project.godot`, over de huidige hartslag-/FIT-versie.
Behoud de mapstructuur en bevestig het vervangen van `main.gd`. Open het project
daarna opnieuw zodat Godot de nieuwe afbeelding importeert.

De aangeleverde afbeelding staat nu op het houten baanoppervlak in de laatste
bocht vóór het rechte stuk naar de normale finish. Ze ligt op het buitenste
deel van de piste, boven de blauwe stayerslijn, met de bovenkant in de rijrichting.
De originele gele achtergrond en de volledige afbeelding zijn behouden.

De markering volgt de kromming én de banking van de bestaande piste. De verhouding
van de afbeelding wordt bepaald op het hellende oppervlak. Ze ligt 6 mm boven
de ondergrond om flikkeren te vermijden en heeft geen botsingsvorm. De nieuwe
texture gebruikt mipmaps voor een rustiger beeld op afstand.

Alleen de baanopbouw krijgt een extra markering; rijlijnen, fysica, tijden,
HUD, AI en exports zijn ongewijzigd. De werkkopie staat in `work/track_logo_project`;
het oorspronkelijke project is niet rechtstreeks overschreven.

Uitgevoerd met Godot 4.7.2 headless: import van de PNG, statische scriptcontrole
en starten van de volledige hoofdscene. Geen scriptfouten. Ook gecontroleerd dat
de opgenomen PNG byte voor byte overeenkomt met de aangeleverde afbeelding.

Niet uitgevoerd: visuele beoordeling in een GPU-gerenderde spelrun of exportbuild.
Bekijk de laatste bocht met de zijcamera of overzichtscamera om plaatsing,
leesrichting en grootte in de daadwerkelijke spelweergave te beoordelen.
De bekende omgevingsmelding over de Windows-rootcertificaten staat los van de checks.
