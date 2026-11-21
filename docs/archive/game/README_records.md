# Velodrome 250 X — Records / all-time Top 10

## Installeren
Deze patch bouwt voort op de laatste ploegenachtervolgingsversie met het vaste wattagedoel en het zwevende AI-vermogensbordje. Pak uit in de bestaande projectmap waar project.godot staat en vervang de bestanden. Alleen gewijzigde/nieuwe scripts, script-UIDs, tests en deze README zijn opgenomen. Geen persoonlijke records, ritbestanden of testgegevens worden meegeleverd.

## Nieuwe tegel en pagina
Het openingsscherm heeft nu zeven tegels, verdeeld over vier kolommen en twee rijen. De nieuwe tegel Records heeft een eigen trofee-/podiumillustratie en opent een aparte Top-10-pagina. De status op de tegel Ploegenachtervolging is bijgewerkt naar SPEEL. De overige nog niet beschikbare spelvormen blijven BINNENKORT tonen.

Op de Records-pagina kies je de spelvorm, afstand en zo nodig ploegomvang. Er zijn zes afzonderlijke klassementen:
- Individuele achtervolging: 1 km en 4 km.
- Ploegenachtervolging met 3 renners: 1 km en 4 km.
- Ploegenachtervolging met 4 renners: 1 km en 4 km.

Elke rij bevat rang, spelernaam, datum/tijd en eindtijd. De snelste tijd staat bovenaan; bij exact gelijke tijden komt de oudste prestatie eerst. De tabel toont maximaal tien prestaties per categorie. Wanneer de beschikbare schermhoogte onvoldoende is, kun je door de rijen scrollen. Via Spelvormen of Escape ga je terug.

## Automatisch bewaren
Een voltooide individuele of ploegenachtervolging wordt automatisch geregistreerd zodra de speler/eigen ploeg finisht. Je hoeft hiervoor niet op Rit opslaan te drukken. Afgebroken/onvoltooide pogingen, tegenstanderprestaties en scratchritten worden niet toegevoegd.
De spelernaam wordt op het finishmoment vastgelegd. Een latere naamswijziging verandert oude vermeldingen niet. De datum/tijd van nieuwe prestaties is de lokale systeemdatum/-tijd bij de finish, niet de virtuele wedstrijdklok. Demo- en trainerritten tellen beide mee in deze lokale persoonlijke klassementen.
Het apart bewaren van een rit als tegenstander blijft mogelijk. De opname krijgt voortaan ook de oorspronkelijke spelernaam, finishdatum en een prestatie-id mee, zodat openen van Records of later bewaren van dezelfde rit geen dubbele vermelding oplevert. Elke nieuwe rit telt wel als een eigen prestatie; het zijn geen lijsten met maximaal één tijd per spelernaam.

De Top 10 blijft na afsluiten/herstarten lokaal bewaard in user://personal_records.json. Er worden maximaal 60 tijden bewaard, tien per categorie; minder snelle tijden worden niet in het klassement opgenomen. Dit is geen online leaderboard en de gegevens worden niet tussen computers gesynchroniseerd. De bestaande instellingen en opgeslagen tegenstanders blijven afzonderlijk bewaard.
Bij een update van het bestand wordt een reservekopie bijgehouden. Bij een onleesbaar hoofd bestand kan de laatste leesbare reservekopie worden gebruikt; zijn beide onleesbaar, dan worden ze niet stilzwijgend overschreven en toont de pagina een melding.

## Oudere prestaties
Bij het openen van Records worden bestaande opgeslagen individuele en ploegprestaties uit hun gebruikelijke user://-mappen meegenomen, met dezelfde scheiding per afstand/ploegomvang. Deze import verandert de oorspronkelijke ritbestanden niet en wordt niet dubbel geteld.
Oude ritbestanden bevatten vaak alleen een zelfgekozen ritnaam en het opslagmoment. Die ritnaam wordt niet als spelernaam geïnterpreteerd: zulke vermeldingen krijgen Onbekende speler. De datum/tijd is dan het toenmalige opslagmoment, expliciet in UTC weergegeven. Een toelichting staat onder de tabel zodra zulke oude vermeldingen zichtbaar zijn. Nieuwere ritbestanden met de extra metadata behouden de werkelijke spelernaam en finishdatum.
Oudere pogingen die nooit zijn opgeslagen, kunnen niet achteraf worden gereconstrueerd. Vanaf deze patch worden voltooide pogingen automatisch meegenomen, ook zonder aparte tegenstanderopname.

## Getest
Godot 4.7.2 headless: 15 controles geslaagd zonder scriptfouten:
import, scriptcontrole, nieuwe recordtests, ploegenachtervolging, modelintegratie, scratch-AI, wielvolgen, rondewinst, wedstrijdregels, sprinterverbruik, volledige scratchwedstrijden, individuele achtervolging, HUD, menu en hoofdscene laden.

Nieuwe controles omvatten:
- Meer dan tien tijden per categorie invoeren; correcte sortering en beperking tot tien voor alle zes categorieën; gelijke tijden op datum rangschikken.
- Herladen vanaf schijf, JSON-getallen, spelernaam en exacte finishdatum/-tijd, automatische registratie zonder handmatig opslaan, en geen toevoeging vóór de finish.
- Herhaalde finishverwerking, een latere naamswijziging en daarna optioneel bewaren als tegenstander: geen duplicaat of wijziging van de oorspronkelijke recordnaam.
- Bestaande oude rit importeren, onbekende spelernaam/UTC-opslagdatum tonen, herhaalde import zonder dubbele vermelding.
- Ongeldige tijden weigeren; leesbare reservekopie herstellen; onleesbare bestanden behouden.
- De zevende tegel, SPEEL-status bij ploegenachtervolging, filters, tien tabelrijen, terug/Escape en schermgrenzen van de tegels en navigatie.

Niet getest: visuele Godot-speeltest/GPU-weergave van de nieuwe tegel en Records-pagina, alle schermformaten, een fysieke trainer en daadwerkelijke historische ritbestanden uit jouw spelinstallatie. De import is getest met representatieve bestanden in dezelfde formaten. De headless omgeving meldt dat de certificatenopslag niet gelezen kan worden; netwerkfunctionaliteit is niet getest.

## Zelf proberen
1. Open het spel: controleer de tegel Records en SPEEL op Ploegenachtervolging.
2. Open Records. Wissel tussen achtervolging/ploegenachtervolging, 1/4 km en 3/4 renners. Controleer ook eventuele oude opgeslagen ritten.
3. Voltooi een individuele achtervolging en kies geen Rit opslaan. Ga terug naar Records: je spelernaam, datum/tijd en eindtijd moeten automatisch aanwezig zijn wanneer de prestatie binnen de Top 10 valt.
4. Herhaal met ploegenachtervolging. Controleer dat de tijd alleen bij de juiste ploegomvang staat.
5. Bewaar een rit daarnaast als tegenstander. De prestatie mag maar één keer in de Records-lijst staan.
6. Herstart het spel en controleer of de lijsten bewaard blijven. Afbreken van een poging mag geen record opleveren.

De nieuwe tests zijn uitvoerbaar met Godot headless via --script res://tests/test_records.gd. Modellen, fysica, het vaste ploegwattagedoel en het AI-vermogensbordje zijn niet gewijzigd.
