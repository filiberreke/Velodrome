# Tijdritrecords, rennersboxen en uitslagnavigatie

Basis: main `964bca2`. Godot 4.7.2 op Windows, geïsoleerde testgegevens.

## Aanpassingen

- Tijdritrecords gebruikten nog de verborgen afstand-ID's 1000/4000 van
  achtervolging. Daardoor sprong tijdrit 1 km terug naar 500 m. De selector krijgt
  nu de juiste ID's en teksten voor de actieve discipline.
- Bij een nieuw opgeslagen tijdritresultaat opent Records automatisch op de
  juiste afstand en startwijze, ook na herstart van het spel. Zonder nieuw
  resultaat blijven handmatig gewijzigde filters behouden. Historie blijft intact.
- Beide tijdritstartwijzen openen alleen de box van de speler, met de tijdritfiets.
  Andere gordijnen sluiten; hun staf en los materiaal verdwijnen. Groepswedstrijden
  openen daarna opnieuw alle zes boxen.
- De uitslagknoppen heten Wedstrijd opnieuw rijden en Terug naar hoofdmenu.
  Opnieuw rijden bewaart discipline, afstand, startwijze, deelnemers, vormwaarden,
  tegenstandersterkte, referentierit en ploegfactoren. Het gaat direct naar de
  bestaande stilstandcontrole/aftelling. Opgeslagen tegenstanders worden niet
  nogmaals geschaald. R na de finish voert dezelfde herstart uit.

## Controle

Geslaagde controles:

- `test_time_trial_record_filters.gd`: 1 km blijft geselecteerd, de vliegende uitslag
  verschijnt, handmatige filters blijven behouden, nieuwe uitslag selecteert haar
  categorie en wisselen naar 4 km achtervolging en terug werkt.
- `test_result_navigation.gd`: alle zes speelbare disciplines, beide solo-starten,
  twee opeenvolgende herstarts, behoud van deelnemers en vormwaarden, ploegreset,
  herhalen van een geschaalde opgeslagen tegenstander, R en terug naar hoofdmenu.
- `test_infield_boxes.gd` en `test_box_occupation.gd`: precies de eigen box open
  voor beide solo-startwijzen, juiste fiets, zichtbaarheid van staf en materiaal,
  en behoud van achtervolgings- en groepsgedrag. De bezettingstest kiest expliciet
  verschillende landen voor de twee achtervolgers.
- Bestaande suites: flying time trial, records, solo time trial HUD, exit/pause,
  pursuit flow, team pursuit en neutral start.

De bestaande pursuit-flow-test slaagt, maar geeft bij opruimen zeven meldingen
over een ontbrekend materiaal. Dezelfde zeven meldingen zijn gereproduceerd met
de ongewijzigde main.gd van de basiscommit. De nieuwe navigatietest ruimt oude
frames tussen opeenvolgende herstarts op en slaagt zonder die meldingen.

De recordfilters, uitslagknoppen en solo-boxen zijn met de echte renderer
gecontroleerd. Previewrecords zijn synthetische testgegevens. Persoonlijke
rijhistorie wordt niet gewijzigd door deze aanpassing. Geen fysieke trainertest.

De renderomgeving logt bij afsluiten ook zeven shader-initialisatiemeldingen
(`shader_gles3.cpp`). De gemaakte beelden zijn volledig gerenderd en gecontroleerd.
