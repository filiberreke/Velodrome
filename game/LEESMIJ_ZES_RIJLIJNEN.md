# Velodrome 250 X - zes rijlijnen op dezelfde baan

Deze aanvulling bouwt verder op de snelheidsafhankelijke drafting-, peloton- en demarragepatch.

## Wijzigingen
- De speler kan zes rijlijnen kiezen (A/D of pijltjes), HUD toont 1/6 t/m 6/6.
- Centra op 1.18, 2.38, 3.58, 4.78, 5.98 en 7.18 meter ten opzichte van het bestaande referentiepad.
- Het houten baanoppervlak loopt van offset 0.78 tot 9.03 m en is niet vergroot.
- AI in scratch doorzoekt zes uitwijkcorridors; andere modi gebruiken dezelfde zes lijndoelposities.
- AI kan nog altijd vloeiend zijdelings schuiven en buitenrenners leggen in bochten een langere weg af.

## Installatie
Vervang in het bestaande volledige Godot-project `main.gd` en `x_scratch_ai.gd`. Deze ZIP is een scriptpatch, geen volledig project.

## Testpunten
1. Speler A/D van lijn 1 tot 6 en terug, inclusief HUD.
2. Midden in groep: AI moet meerdere lijnen gebruiken en niet langdurig overlappen.
3. Uitwijken bij een demarrage, ook aan de buitenrand.
4. Controleer modelbreedte/visuele afstand op de hellende bochten; corridors liggen 1.20 m uiteen.

Godot-runtime is hier niet beschikbaar: statische broncodecontrole, geen speltest.
