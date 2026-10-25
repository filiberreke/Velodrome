# Achteruitkijken - Velodrome 250 X

Gebaseerd op de patch met zes rijlijnen, snelheidsgestuurde drafting, verbeterde pelotonvorming en reacties op demarrages.

## Bediening
- **B ingedrukt houden**: kijk achteruit, naar de renners achter jou.
- **B loslaten**: terug naar je eerder gekozen camerastandpunt (CLOSE, WIDE, POV of SIDE).
- **C**: wissel zoals voorheen tussen de vier vaste camerastandpunten.

De tijdelijke achteruitblik werkt ook in POV. De camerawissel is enkel visueel; vermogen, snelheid, drafting, AI, rijlijn en finishregels blijven gelijk.

## Installatie
Maak een reservekopie van je Godot-project en vervang `main.gd` (en indien je dat nog niet gedaan had `x_scratch_ai.gd`) met de bestanden uit dit archief.

## Testen
1. Start een scratch in Godot.
2. Houd tijdens het rijden **B** ingedrukt en controleer dat je het achteropkomende peloton ziet.
3. Laat **B** los en controleer dat het vorige camerastandpunt terugkomt.
4. Herhaal na **C** en in bochten.

Statische codecontrole gedaan; niet daadwerkelijk in Godot gestart.
