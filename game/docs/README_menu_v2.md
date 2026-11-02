# Menutest: startlijsten en podium

Deze testversie is bedoeld voor `feature/ivory-blue-menus`, niet voor publicatie
naar `main` vóór de eigen speeltest van de gebruiker. De nieuwe wijzigingen
voor Afvalling tot en met main-commit `20243396` zijn meegenomen.

## Wat is veranderd

- Scratch, Puntenkoers en Afvalling openen na de wedstrijdinstellingen een
  tweede pagina met alle tegenstanders als compacte profielkaarten. Met
  **Wissel renner** kies je uit de nog niet gebruikte identiteiten. De eigen
  renner staat niet tussen de tegenstanders. Ook bij zestien deelnemers zijn
  reserveprofielen beschikbaar. Er kan geen dubbele identiteit worden gekozen.
- Teruggaan en het aantal deelnemers aanpassen bewaart de al gekozen
  tegenstanders waar mogelijk. De lijsten worden per discipline apart bewaard
  tijdens de sessie. Bij de daadwerkelijke start gaan naam, specialiteit,
  vermogen, lichaamsprofiel en kleding van de gekozen identiteit mee.
- Achtervolging en Ploegenachtervolging gebruiken dezelfde indeling als Scratch:
  links het beeld, de titel en de beschrijving; rechts de instellingen en
  navigatie. De bestaande keuze van tegenstander/eigen prestatie blijft intact.
- De uitslagpagina gebruikt het originele logo en dezelfde ivoor/blauwe stijl.
  Rechts blijft het echte podium zichtbaar. De definitieve top drie staat
  zonder fiets op de juiste treden: winnaar midden, tweede links, derde rechts.
  De winnaar heft de armen. De avatars behouden hun werkelijke wedstrijdtenue
  en lichaamsprofiel. De podiumkopieën veranderen de racers en finishfoto niet.
- De podiumvolgorde volgt dezelfde klassering als de uitslag: rondewinst bij
  Scratch, punten bij Puntenkoers en de afvallingsjury/finale bij Afvalling.
  Zolang er nog renners onderweg zijn, worden nog geen podiumplaatsen uitgereikt.
  Achtervolging heeft twee deelnemers en dus twee podiumplaatsen. Bij
  Ploegenachtervolging vertegenwoordigt één renner elke geklasseerde ploeg.
- Records heeft alvast **Tijdrit**, met een duidelijke lege toestand. Er worden
  nog geen tijdritregels, afstanden of fictieve prestaties geregistreerd.

## Zelf proberen

Open `game/project.godot` in Godot 4.7.2 en start met F5. Gebruik een aparte
uitgepakte projectmap als je de test-ZIP gebruikt.

1. Kies Scratch, stel deelnemers/ronden in en klik **Startlijst**. Wissel een
   tegenstander en controleer dat de gekozen renner in de race verschijnt.
2. Ga terug, verander het aantal deelnemers en open de lijst opnieuw.
3. Controleer Puntenkoers en Afvalling met zestien deelnemers. Alle vijftien
   tegenstanders en de startknop zijn bereikbaar; wisselen blijft mogelijk.
4. Controleer afstand/ploegomvang en uitgeklapte ploeginstellingen bij
   Achtervolging en Ploegenachtervolging.
5. Voltooi een race. Vergelijk de definitieve uitslag met de drie podiumrenners.
6. Kies Records → Tijdrit en ga terug naar een bestaande recordcategorie.

De nieuwe tests zijn `tests/test_startlist_flow.gd` en `tests/test_results_podium.gd`.
Zij controleren echte muisacties, het uitsluiten van dubbele/verzonnen profielen,
het doorgeven aan de AI, wijzigingen in deelnemersaantal, behoud van bestaande
recordfilters, juiste podiumklassering, uiterlijk, voetposities, hergebruik van
podiumfiguren en opruimen bij herstart. De overige regressietests blijven aanwezig.

`tests/capture_menu_v2.gd` maakt tien echte renderbeelden in
`verification/menu_v2/`. Deze gebruiken expliciete testuitslagen. Een echte
trainer, Ride-hardware en een live Strava-upload zijn niet getest.
