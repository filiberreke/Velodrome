# TUSSENSPRINT in Godot — 28 oktober 2026

De geteste Python-tactiek is overgezet naar `points_intermediate_sprint.gd` en staat standaard aan in de speelbare puntenkoers. De gedeelde fysiologie, daadwerkelijke snelheids-/baanberekening, scratchmodus en jury zijn niet gewijzigd. Basis-CP blijft 265 / 240 / 250 W; W′ en piekvermogen blijven gelijk.

Godot 4.7.2 headless is daadwerkelijk uitgevoerd. Vijftien scripts slagen, waaronder:

- `test_intermediate_sprint.gd`: 64 beslissingen tegen fixtures uit de Python-proef, met maximaal 0,00001 verschil in kansen, reserves en gevraagde watts; afbreken, momentopname, reset, speler/finishers en gelijke eindsprintuitvoer met de tactiek aan/uit.
- `test_intermediate_sprint_race.gd`: volledige 40-rondenkoers op 250 m bij 60 Hz, 16 deelnemers (15 AI plus een speler op 300 W), seed 1001. Finish na 920,8 gesimuleerde seconden; vier sprints, 55 sprintpunten plus rondepunten, eindige W′ en geen rondepunten na de gemeenschappelijke finish. De tactiek maakte zowel sprint-, overslaan- als afbreekbeslissingen.
- De bestaande puntenkoersproef (40 ronden op 10 Hz en 10 ronden op 60 Hz), puntenmeldingen, scratch-AI, wielvolgen, rondegedrag, groot veld, sprintereconomie, menu, HUD, trainerbesturing, individuele/ploegenachtervolging en omroepintro.

De twaalf Python-tests voor de eerdere A/B-proef zijn opnieuw uitgevoerd en slagen. De simulatorcode en de 100 A/100 B-resultaten uit de proef zijn niet gewijzigd door deze Godot-port. Dit is geen uitgevoerde batch van 100 Godot-wedstrijden en voorspelt geen identieke profielverdeling in het spel.

Een verouderde menutest verwachtte de al verwijderde permanente punten-/sprintbalk. Dezelfde fout is vastgesteld met de oorspronkelijke `points_ai.gd`; zie `menu_baseline.json` en `test_menu_baseline.log`. Alleen die testverwachting is aangepast aan de bestaande compacte HUD en popups, met een extra controle dat TUSSENSPRINT actief is. Er is geen HUD-productwijziging.

De eerste assetimport eindigde met exitcode 0 en vier meldingen over ontbrekende UV's voor tangenten op de ongewijzigde Euromax-modellen; geen nieuwe parsefouten. De headless omgeving meldt ook dat de certificaatstore niet leesbaar is. Deze meldingen staan in de ruwe logs; ze zijn geen geslaagde hardware-/netwerkverificatie. Geen fysieke trainer of visuele speeltest uitgevoerd.

De bekende bel-/rondejurybeperkingen uit `simulation/TUSSENSPRINT_AB_REPORT.md` blijven bestaan. De koerskop wordt niet bij de bel vastgezet; kopwerk door gedubbelde renners voor koplopers wordt niet afgedwongen. Het menselijke vermogen wordt niet door deze tactiek aangestuurd. De speler wordt wel als tegenstander in de schatting meegenomen, op basis van huidige snelheid en watts.

Reproduceren na de normale projectimport, vanuit de repository:

```text
python game/tests/generate_intermediate_sprint_cases.py
godot --headless --path game --script res://tests/test_intermediate_sprint.gd
godot --headless --path game --script res://tests/test_intermediate_sprint_race.gd
godot --headless --path game --script res://tests/test_points_race.gd
```

`summary.json` bevat de complete lijst geslaagde scripts en bronhashes. `godot_race_smoke.json` bevat de daadwerkelijk gemeten 60-Hz-proef. De ruwe logs staan ernaast. De fixtures gebruiken een afgewerkte speler-placeholder en 16 AI's om exact dezelfde 64 Python-beslissingen te toetsen; de aparte gameplaytest gebruikt de normale 16 deelnemers inclusief speler.
