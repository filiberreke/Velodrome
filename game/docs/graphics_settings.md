# Grafische instellingen

Via **F10 → Beeld → Eenvoudige graphics (na herstart)** kies je de lichte stand.
Standaard staat deze uit. Kies **Toepassen en bewaren** en herstart het spel om
de andere inrichting te laden. De keuze staat lokaal in
`user://config/display_settings.cfg`, onder `arena.simple_infield`.

| Onderdeel | Standaard | Eenvoudig |
| --- | --- | --- |
| Middenpleinpubliek | 2.000 supporters | 400 supporters met eenvoudige modellen |
| Horeca en tenten | Oorspronkelijke inrichting | Zes eenvoudige tenten en vier banken |
| Mediazone en interviews | Aanwezig | Weggelaten |
| Lichtslingers en tegelvoegen | Aanwezig | Weggelaten |
| Tribunepubliek | Bestaande nabij-/verafmodellen | Eenvoudigste modellen op alle afstanden |
| Commentaarcabine | Aanwezig | Weggelaten; gewone tribuneplaatsen op die plek |
| Intro | 26 seconden; 28 bij achtervolging | 2,5 seconden direct bij de renners, zonder lichtshow |

Rennersboxen met bemanning, officials, finishcamera en fotografen, podium,
de keldertrap en de live gebogen schermen blijven in beide standen behouden.
Publieksdichtheid en interne 3D-resolutie zijn afzonderlijke instellingen.
De normale startcontrole en het aftellen volgen na de intro in beide standen.

Het stadion heeft in beide standen twee tribuneringen. Het lagere dak sluit
achter de tweede ring aan. De spots hangen hoger en verder naar binnen onder
het dak. Dit zijn gedeelde stadionaanpassingen, geen onderdelen van de optie.

## Controle

`game/tests/test_graphics_settings.gd` controleert de standaardkeuze, bewaren en
herladen na herstart, beide inrichtingen, de trap en vrije doorgangen, officials,
publieksmodellen, dakspots en introduur voor scratch en beide achtervolgingen.
Voer de test uit met een afzonderlijke gebruikersmap, zodat spelersvoorkeuren
niet worden overschreven. Bestaande tests voor de intro, commentaarcabine,
middenpleininrichting en menu blijven ook van toepassing.

De prototypemeting op Intel Iris Xe gaf ongeveer 77 tegenover 100 FPS voor
standaard/eenvoudig, met dezelfde camera, 12 renners, 1920×1080, 85% interne
3D-resolutie en 60% tribunepubliek. Het was een grafische rondrit zonder
wedstrijd-AI/fysica, geen garantie voor andere hardware of volledige wedstrijden.
