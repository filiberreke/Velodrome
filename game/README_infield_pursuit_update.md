# Binnenplein en achtervolging — 31 oktober 2026

- Omheining rondom 2,00 m naar binnen verplaatst: offset -0,45 naar -2,45 m. De grijze strook naast de cote d'azur is veiligheidszone. De rijlijnen blijven op de piste.
- Zes boxen 2,00 m mee verplaatst; coaches staan aan de pistezijde. Vijf open doorgangen tussen de boxen onderbreken glas, plint en leuning. Publiek houdt de toegangen vrij.
- Individuele achtervolging: kies uit alle vijftien beschikbare AI-slots en eventuele extra renners in riders_config.cfg. Naam, profiel en outfit van de gekozen renner worden toegepast. CP blijft instelbaar; vorige ritten blijven beschikbaar.
- Ploegenachtervolging: alle elf beschikbare landen zijn selecteerbaar. Beide ploegen tellen drie of vier renners. AI-ploegmaats dragen de outfit van de speler, ook na een wijziging in Instellingen. Alle tegenstanders dragen het gekozen landenpak.
- 2.000 supporters in de gedeelde binnenplein-batches, bovenop de afzonderlijke terrasgasten en boxbemanning. De ongewijzigde basis telde minder dan 500 personen in deze batches. Vier rijen langs de publieksdelen van de omheining; de werkzones van de boxen blijven toegankelijk. Alle bestaande terrasstoelen en picknicktafels zijn bezet. Noordelijke bartafels en vlaggen zijn naar binnen verschoven waar nodig.

## Controle

Geslaagd: test_infield_update.gd (inclusief alle 11 landen met 3 en 4 renners), test_team_pursuit.gd, test_menu.gd, test_infield_boxes.gd en test_box_occupation.gd. De nieuwe geometriecontrole test de echte glasmesh, de veiligheidszone, coaches, vrije toegangen en het publieksaantal. GPU-beelden van beide menu's, de boxen, het noordplein en het overzicht zijn visueel nagekeken.

test_pursuit.gd heeft één bestaande fout bij de assertion "Actual countdown launches both riders from a standing start". Dezelfde fout is gereproduceerd op de ongewijzigde basis. Overige assertions in die test slagen. De Windows-melding over de root certificate store is een bestaande lokale Godot-omgevingsmelding.
