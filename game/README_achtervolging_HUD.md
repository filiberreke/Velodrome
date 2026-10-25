# Achtervolging: nieuwe horizontale HUD-balk

## Installeren
Deze patch vereist de vorige achtervolgingsversie. Pak uit in de projectmap waar project.godot staat en vervang de bestanden. Alleen gewijzigde scripts, de bijgewerkte HUD-test en deze README zijn opgenomen; dit is geen volledig spelproject.

## Nieuw
- Links het rondenummer; centraal vast jouw naam links en tegenstander rechts.
- Tegenstander heet AI of de naam van de opgeslagen rit (maximaal 20 tekens; bij beperkte schermruimte met beletselteken).
- De rondetijden en hun verschil in seconden worden bijgewerkt zodra beiden dezelfde ronde hebben afgelegd. Tot de eerste gezamenlijke doorkomst staat er --. Zo worden nooit verschillende rondes vergeleken.
- Centraal staat het verschil tussen die twee rondetijden. Wit/rood duidt de leider/tweede in de wedstrijd aan, op basis van de opgetelde tijden bij diezelfde ronde. Een snellere laatste ronde betekent dus niet noodzakelijk de leiding in de wedstrijd.
- Wit en rood zijn doorschijnend (55% dekking); bij gelijke totaaltijd of zonder vergelijkbare ronde zijn beide kanten neutraal grijs.
- Geen tekst 'Laatste ronde'. Totale persoonlijke tijd rechts in honderdsten; positie verdwijnt bij achtervolging.
- De scratch-weergave blijft beschikbaar bij terugkeren naar die spelvorm.

## Getest
Godot 4.7.2 headless: scriptcontrole, HUD-tests, achtervolgingstests (AI en opgeslagen rit, 1/4 km), menutests en laden van de hoofdscene geslaagd.
HUD-tests controleren onder meer rondevergelijking terwijl één renner al een ronde verder is, kleuren bij leiderswissel, gelijkstand, naamlimiet, AI-label, transparantie, klok, schermgrenzen en terugkeer naar scratch.
Godot meldt in deze omgeving dat de certificatenopslag niet gelezen kan worden. Geen scriptfouten in de geslaagde controles; netwerkfunctionaliteit is niet getest.

## Nog zelf controleren
Geen visuele speeltest op de GPU en geen fysieke trainer getest. Headless controles bevestigen geen daadwerkelijke leesbaarheid boven bewegend beeld.
1. Start 1 km achtervolging tegen AI: ronden links, twee namen centraal, totale tijd rechts; geen positie of 'Laatste ronde'.
2. Rijd de eerste ronde uit: na beide doorkomsten verschijnen twee rondetijden en het onderlinge rondeverschil. Kijk of de doorschijnende vakken goed leesbaar zijn.
3. Verander het tempo: namen blijven staan; wit volgt de leider op de vergeleken ronde, rood de tweede.
4. Probeer 4 km en een opgeslagen rit met een lange naam. Er verschijnen maximaal 20 tekens van die ritnaam.
5. Ga terug naar scratch: de gewone tijd/afstand/positie-balk moet terug zijn. X blijft de developer-HUD schakelen.

## Bestanden
main.gd, race_hud.gd, tests/test_hud.gd.
