# Binnenbaanvoorkeur: uitgevoerde verificatie

Getest op de actuele spelcode vanaf `2152166fbd93a09de6a4dce278b5df73b7e9e272` met Godot 4.7.2 headless. Alle 19 genoemde Godot-testscripts slagen. De voorkeur geldt onmiddellijk wanneer de binnenbaan en de volledige afdaling vrij zijn, ook tijdens het optrekken; er is geen vaste wachttijd.

## Werkelijke afstand

De bestaande geometrie geeft bij numerieke integratie van één 250-m-referentieronde circa **257.56 m** op rijlijn 1,18 m en **298.64 m** op rijlijn 7,18 m. De buitenlijn was dus al langer; de fysica is hiervoor niet aangepast. Dit zijn lengtes van de gekozen rijlijncentra ten opzichte van de referentieafstand, geen nieuwe officiële baanmeting.

## Vergelijking daadwerkelijk gereden binnenbaan

Acht volledige wedstrijden uitgevoerd: scratch en puntenkoers, seeds 1001 en 1002, telkens met de voorkeur uit en aan. Per wedstrijd: 20 ronden, 16 deelnemers inclusief een speler op 300 W, 15 AI-renners, 0,1-s tijdstap en identieke beginprofielen en parameterkeuze per seedpaar. Dit is een beperkte gedragscontrole, geen nieuwe 100-wedstrijdenbenchmark.

Binnenbaan = rijlijnpositie ≤1,53 m. Het percentage weegt de actieve AI-rennerseconden vanaf 20 seconden na de start; speler en gefinishte renners zijn uitgesloten.

| Spelvorm | Voorkeur uit | Voorkeur aan |
|---|---:|---:|
| scratch | 33.70% | 37.63% |
| points | 26.40% | 33.05% |

Alle deelnemers finishen en de puntenboekhouding blijft correct. De nieuwe voorkeur veroorzaakt andere wedstrijdverlopen; meer binnenrijden is geen garantie op een snellere finish of meer overwinningen. Individuele seedresultaten en profielmetingen staan in `races.csv` en `races.json`.

## Gerichte tests en regressies

- Vrije binnenbaan, bezette tussenbaan, bezette binnenbaan, snellere achterligger, reeds geplande kruisende routes, een rondeverschil, startlijnpassage, gefinishte renners en een tijdens het afdalen veranderende bezetting.
- Wielvolgen, aflossen, aanvallen, sprintpositionering en de handmatige rijlijn van de speler.
- Startvergelijking met de voorkeur aan/uit voor 8, 12 en 16 deelnemers. Bij 8/12 rijden alle AI’s na 10 s onder eigen vermogen boven de bestaande snelheid-/afstandgrens. Bij 16 zaten in de baseline drie renners onder die grens; de wijziging introduceert geen extra langzame starters. Deze bestaande eigenschap is niet als opgelost gerapporteerd.
- Volledige 40-rondenpuntenkoers op 60 Hz, de bestaande puntenkoerstests en volledige scratch-gameplay voor 8/12 renners.
- Bestaande tests voor scratch-AI, wielvolgen, rondelogica, groot veld, sprintereconomie, TUSSENSPRINT, meldingen, menu, HUD, trainerbesturing, achtervolging, ploegenachtervolging en omroepintro.

`summary.json` bevat de complete lijst scripts en bronhashes. `main.gd`, de TUSSENSPRINT-beslismodule, de jury en pelotonstatus zijn bytegelijk aan de basiscommit. De gedeelde fysiologiefuncties in de gewijzigde AI zijn afzonderlijk identiek vergeleken. CP, W′ en echte snelheids-/baanfysica zijn niet aangepast. De oorspronkelijke Python A/B-resultaten blijven resultaten van vóór deze rijlijnwijziging.

De eerste versie van de nieuwe voorkeur stuurde bij een geblokkeerde binnenbaan alvast naar een tussenbaan. Dat verstoorde de start van twee renners en is hersteld: een geblokkeerde route behoudt de bestaande tactische keuze. De definitieve tests en tabellen hierboven horen bij de uiteindelijke versie zonder vaste startvertraging.

Bekende beperkingen: de bestaande jury-/botsingsvereenvoudigingen blijven gelden. De routecontrole is defensief maar bewijst geen volledig botsingsvrije wedstrijd. De headless omgeving geeft de bekende melding over de certificaatstore. Geen fysieke trainer of visuele speeltest uitgevoerd.

Reproduceren vanuit de repository na de normale Godot-import:

```text
godot --headless --path game --script res://tests/test_inside_lane.gd
godot --headless --path game --script res://tests/test_inside_lane_launch.gd
godot --headless --path game --script res://tests/test_inside_lane_races.gd
```
