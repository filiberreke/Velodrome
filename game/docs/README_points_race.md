# Puntenkoers

Kies **Puntenkoers** in het hoofdmenu en daarna **Start wedstrijd**.
Standaard: **40 ronden (10 km), 16 deelnemers inclusief jou**.
Je kunt 6–16 deelnemers en 10–120 ronden kiezen, in stappen van 10 ronden.
Demo en de bestaande trainer-/aftelprocedure worden ondersteund.

## Punten

- Elke 10 ronden sprinten de renners voor 5, 3, 2 en 1 punt.
- De laatste sprint telt dubbel: 10, 6, 4 en 2 punten.
- Een ronde winnen op het grootste peloton geeft 20 punten; een ronde verliezen kost 20 punten.
- De meeste punten winnen. Bij gelijke punten beslist de volgorde van de laatste sprint.
- Gedubbelde deelnemers finishen bij hun eerstvolgende lijnpassage na de gemeenschappelijke finish, zonder eerst hun eigen volledige afstand te moeten afleggen.

Het wedstrijdscherm toont jouw punten, de volgende sprint, de puntenstand en netto ronden.
De uitslag toont punten, gewonnen/verloren ronden en de punten per sprint. De uitslag wordt aangevuld tot iedereen de laatste lijn gepasseerd is.
De arcadeboost is uitgeschakeld voor puntenkoers.

## AI en fysiologie

De punten-AI gebruikt de Godot-versie van het gekozen CP/W′-model, drafting, zuinig wielvolgen voor sprinters en de bestaande kracht-/bankberekening.
Basis-CP: **265 W tijdrijder, 240 W sprinter, 250 W aanvaller**; vorm varieert zoals in scratch. W′-capaciteit en piekvermogen zijn gelijk gebleven.
Alle profielen kunnen sprinten. Er zijn ook aanvallen, achtervolgingen en samenwerking in ontsnappingen.
Het vermogen van de speler blijft afkomstig van de trainer of de demo-instelling.

`points_ai.gd` erft de gedeelde fysiologie van `x_scratch_ai.gd` en heeft een aparte tactische stap voor herhaalde sprints. De CP-constanten van scratch blijven ongewijzigd. Beide spelvormen delen de verbeterde beurtwisselingen in kleine ontsnappingen, ook met de speler. De bestaande achtervolgings- en ploegenachtervolgingsmodi blijven beschikbaar.

Zie ook [pelotonweergave en rondewinst](README_peloton_feedback.md) voor de scheiding tussen afgelegde afstand en wedstrijdpositie, de meterafstanden rondom jou, de aparte puntenstand en energiebatterijen.

## Jury en beperkingen

`points_race_rules.gd` beheert een leiderklok, geïnterpoleerde lijnpassages, herhaalbare rondewinsten/-verliezen en de eindrangschikking. Het grootste fysieke peloton wordt op de cirkel herkend: maximaal 12 m tussen opeenvolgende renners, minimaal drie deelnemers en maximaal 125 m spanwijdte. Zonder herkenbare groep worden geen automatische rondepunten toegekend. Rondepunten stoppen bij het finishtijdstip van de leider.

Dit is de speelbare Godot-implementatie, geen garantie op identieke uitslagen als de Python-benchmark. Godot gebruikt de echte baangeometrie, de normale physicsfrequentie en menselijke input. Een start uit stilstand blijft behouden. Valpartijen, neutralisaties en gedeelde punten bij een exacte dead heat zijn niet gemodelleerd; exact gelijke passagetijden gebruiken een vaste ID-volgorde. De tactische afleiding moet bij latere scratchwijzigingen worden bijgewerkt.

## Verificatie

Godot 4.7.2 headless, vanuit de game-map:

```
godot --headless --path . --script res://tests/test_points_race.gd
godot --headless --path . --script res://tests/test_menu.gd
```

De nieuwe tests controleren lijnpassages met gedubbelde deelnemers, herhaalde rondewinsten, rondeverlies, een peloton over de startlijn, het ontbreken van een peloton, dubbele finishpunten, gemeenschappelijke finish, puntenconservering en een volledig afgewerkte 40-rondenkoers met 16 deelnemers. Een tweede volledige 10-rondenkoers loopt op 60 Hz.

Ook gecontroleerd: menu/start/reset, live HUD, puntenuitslag en behoud van scratchinstellingen; bestaande scratch-AI-, wielvolg-, ronde-, startopstellings-, gameplay-, individuele en ploegenachtervolgings- en sprinterenergietests. De instellingen, HUD en uitslag zijn met de renderer visueel nagekeken. Geen fysieke trainerhardwaretest uitgevoerd.
