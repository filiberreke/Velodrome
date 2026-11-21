# Ploegenachtervolging — tijd op eerste voorwiel

## Installatie

Pak deze ZIP uit naast `project.godot`, over de vorige rondetijden-/ploegfotopatch.
Alleen gewijzigde en nieuwe bestanden zijn opgenomen. Open het project opnieuw
in Godot 4.7.2. Het oorspronkelijke project is niet direct overschreven; de
bijgewerkte werkkopie staat in `work/team_first_wheel_project`.

## Nieuwe ploegmeting

Voor beide ploegen wordt de officiële tijd voortaan genomen wanneer het voorwiel
van de eerste renner de aankomstlijn bereikt. Dat mag de speler of een AI-ploegmaat
zijn. De doorkomst wordt binnen de simulatiestap geïnterpoleerd. De vroegere
referentie 5 meter achter de kop vervalt.

Ook ronde- en halve-rondetijden, de tussenstanden, de opgeslagen ploegprestatie
en nieuwe Top-10-vermeldingen gebruiken deze eerste-rennerreferentie. De finishfoto
en de officiële ploegtijd horen nu bij hetzelfde doorkomstmoment. Alle ploegleden
delen de officiële ploegtijd; de speler hoeft daarvoor niet zelf op kop te rijden.

Oudere opgeslagen ploegprestaties met de aanwezige `front`-metingen worden bij
het laden in het geheugen naar de eerste-rennerlijn omgerekend. Het originele
opslagbestand blijft behouden. Bestaande historische Top-10-vermeldingen worden
niet met terugwerkende kracht herberekend; nieuwe vermeldingen volgen de nieuwe regel.

## Strava blijft individueel

De officiële ploegregistratie en de activiteitsexport gebruiken aparte gegevens.
Strava/FIT gebruikt uitsluitend `ride_records`: het gemeten vermogen en de cadans
van de speler, diens eigen spelafstand en diens snelheid. Er worden geen watts,
afstand of meetgegevens van de AI-kopman in de activiteit ingevoegd. De duur van
de FIT-activiteit wordt uit de tijdstempels van de spelersmetingen opgebouwd en
niet door de officiële ploegtijd vervangen.

Als de speler bij de ploegfinish achteraan rijdt, kan zijn geregistreerde afstand
dus korter zijn dan de volledige wedstrijafstand. De opname eindigt bij het einde
van de ploegwedstrijd; de code dwingt voor Strava geen persoonlijke 1/4 km-finish af.
Vermogen blijft het eigen vermogen, ook wanneer dat door de positie minder is
dan het vermogen van de koprijder.

Zonder trainer blijft de bestaande demo-export apart en herkenbaar als simulatie.
Ook die gebruikt nu de eigen spelerpositie en het eigen vermogen in deze modus.
De ploegtrace voor replay van een tegenstander wordt nooit als Strava-activiteit gebruikt.
Er is niets naar een Strava-account geüpload tijdens het testen.

## Uitgevoerde tests

Geslaagd met Godot 4.7.2 headless: projectimport, statische controle, gerichte
eerste-voorwiel-/FIT-test, ploegpresentatie, volledige ploegachtervolging,
individuele achtervolging, records, wattage-HUD, algemene HUD, UDP-protocol en
het starten van de hoofdscene.

De gerichte test controleert voor drie en vier renners een AI-kopman met de speler
achteraan. Ze verifieert de geïnterpoleerde eindtijd, eerste voorwiel exact op de
meet, een kortere spelersafstand, overeenkomst tussen laatste ronde en eindtijd,
de nieuwe replay-eindpositie en het intact blijven van oude opslaggegevens.
Een lokale uploadstub onderschept het FIT-bestand van de echte uploadfunctie.
De test leest daaruit vermogen, cadans, afstand, snelheid en tijdstempels terug,
met opzettelijk afwijkende gegevens voor de AI-kopman, en bevestigt dat alleen
de spelerswaarden zijn gebruikt.

Niet uitgevoerd: visuele GPU-spelrun, echte trainerhardware, een upload naar
Strava of validatie door Strava zelf, en exportbuilds. De bekende Godot-melding
over Windows-rootcertificaten staat los van deze tests; er waren geen scriptfouten.

## Zelf testen

1. Start ploegenachtervolging en geef de kop af voor de finish.
2. Controleer dat de rit eindigt zodra het voorwiel van de koploper finisht,
   ook als jij nog achter hem rijdt.
3. Vergelijk de officiële tijd met de foto en de som van de rondetijden.
4. Controleer de eigen opname/FIT: je eigen vermogen, snelheid, cadans en afstand
   moeten behouden blijven. De afstand hoeft bij een plaats achterin geen exact
   veelvoud van 250 meter te zijn.

```powershell
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_team_first_wheel.gd
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_team_pursuit.gd
```
