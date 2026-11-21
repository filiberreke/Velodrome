# Velodrome 250 X — ploegenachtervolging

## Installeren
Deze patch vereist de vorige versie met het nieuwe Blender-achtervolgingsmodel en de HUD met halve-rondetijden/gemiddelden. Pak uit in de bestaande projectmap waar project.godot staat en vervang bestanden met dezelfde naam. Alleen gewijzigde/nieuwe scripts, nieuwe script-UIDs, tests en deze README zijn opgenomen. Modellen, texturen, projectinstellingen en hoofdscene zijn niet opnieuw meegeleverd en niet gewijzigd.

## Instellen
Ploegenachtervolging is nu speelbaar via de derde kaart in het openingsmenu.
- Kies 2 of 3 AI-ploegmaats: in totaal 3 of 4 renners per ploeg. Beide ploegen hebben dezelfde omvang.
- Afstand: 1 km of 4 km, net als bij de individuele achtervolging.
- Tegenstander: AI-ploeg met instelbaar kop-CP (standaard 250 W), of een opgeslagen ploegprestatie van dezelfde afstand en ploegomvang.
- Alle renners gebruiken het nieuwe aero-model. De speler staat op de eigen achtervolgingslijn op kop; de eigen ploegmaats staan erachter op één rij, met 2,5 m tussenruimte. De tegenploeg start aan de overkant.
- Bestaande stilstandcontrole, aftelling, trainerverbinding en demo-startvermogen blijven van toepassing.

## Tempo en kopwissels
Op kop bepaalt jouw werkelijke vermogen het ploegtempo via de bestaande snelheidsfysica. Druk tijdens het rijden op D of pijl rechts om je kopbeurt af te ronden. Daarna verloopt de hele beweging automatisch: naar buiten, afzakken, naar binnen en achteraan aansluiten. Tijdens die beweging is geen stuurinput nodig. Links/rechts veranderen in deze spelvorm geen handmatige rijlijn; rechts start alleen een wissel wanneer jij op kop rijdt en er nog geen wissel bezig is. Vanuit stilstand begint geen kopwissel (onder circa 1,8 km/u).

De volgende AI-koprijder neemt eerst het tijdgewogen gemiddelde vermogen van jouw afgelopen kopbeurt over. De duur van jouw kopbeurt wordt ook de duur van de AI-kopbeurten. Alle AI-ploegmaats wisselen daarna automatisch, totdat jij weer op kop komt. De volgende eigen kopbeurt bepaalt nieuwe waarden. Bij een extreem korte kopbeurt wordt een volgende AI-wissel uitgesteld totdat de lopende manoeuvre voltooid is; er wisselen nooit twee ploegmaats tegelijk.

Tijdens jouw afzakken mag je uitbollen: jouw wattage heeft dan geen invloed op het ploegtempo. De ploeg houdt het overgenomen kopvermogen aan. Na het aansluiten bepaalt jouw wattage opnieuw het effectieve vermogen van de koprijder, volgens deze verhouding:

| Ploegomvang | Positie 1 | Positie 2 | Positie 3 | Positie 4 |
|---|---:|---:|---:|---:|
| 3 renners | 100% | 80% | 50% | — |
| 4 renners | 100% | 80% | 60% | 40% |

Voorbeeld: 150 W op positie 3 in een driemansploeg komt overeen met 300 W op kop. Bij 120 W op positie 4 in een viermansploeg geldt hetzelfde. Lever je minder, dan neemt de aandrijving af en vertraagt de ploeg geleidelijk; lever je meer, dan kan de ploeg versnellen. De snelheid wordt niet direct vastgezet.

De positiepercentages vormen het ploegvolgmodel. Er wordt daarbovenop geen extra algemene slipstreamkorting toegepast en je kunt niet profiteren van de tegenploeg.

## HUD
Bovenaan centraal staat hoeveel watt jij nodig hebt om de huidige snelheid te behouden, passend bij je positie. De aanwijzing gebruikt de echte snelheidsberekening met baanhelling en lage-snelheidsgedrag. Tijdens uitbollen staat er UITBOLLEN. Op kop staat ook de aanwijzing om rechts te sturen voor een wissel.
Het wattage linksboven kleurt rood onder het doel en groen erboven. Binnen 0,5 W blijft de gewone tekstkleur staan om onnodig flikkeren door afronding te voorkomen. Tijdens uitbollen is de kleur neutraal.

Onderaan wordt Jouw ploeg met de tegenploeg vergeleken. De bestaande 125-meterdoorkomsten, lopende positieve/negatieve tijdsverschillen en segmentgemiddelden blijven beschikbaar. De kleine wattages onder die ploegsegmenttijden zijn het gemiddelde equivalente kopvermogen van dat segment; linksboven staat altijd jouw eigen werkelijke wattage. De miniatuurpiste toont alle renners, met één kleur per ploeg. X toont ook de kopvolgorde, kopbeurtduur, overgenomen vermogen, fase van de wissel en positiepercentage.

## Tijdmeting, uitslag en opslaan
Voor de ploegtijd gebruikt deze spelimplementatie de derde referentieplek van de compacte trein, 5 m achter de virtuele kop. Beide ploegtreinen volgen dezelfde meetmethode. Ook tijdens een wissel blijft dit een vaste ploegreferentie: dit is geen aparte detectie van de actuele derde voorband tijdens de manoeuvre. Alle ploegleden krijgen dezelfde eindtijd; individuele afvallers en aparte aankomsttijden worden niet gesimuleerd.
De uitslag bevat twee ploegen met eindtijd, verschil en rondeoverzicht. Na de finish kun je de eigen ploegprestatie een naam geven en opslaan. Deze opname bewaart het ploegtempo en de voortgang, inclusief de startfase. De eigen kopwissel wordt daardoor in volgende wedstrijden niet opgelegd: de opgeslagen tegenploeg rijdt het opgenomen tempo met een automatisch wisselende trein. Het precieze historische wisselpatroon van alle individuele renners wordt niet afgespeeld.

Ploegprestaties staan afzonderlijk in user://team_pursuit_3_rides en user://team_pursuit_4_rides. Individuele achtervolgingsritten blijven in hun bestaande map en verschijnen niet als ploegtegenstander. Ook een ploegprestatie met een andere afstand of omvang wordt niet aangeboden. De AI-tegenploeg gebruikt het bestaande constante-tempo/CP-model als kopvermogen voor de hele trein en wisselt automatisch; dit is geen nieuw vermoeidheidsmodel voor ieder afzonderlijk AI-ploeglid.

## Getest
Godot 4.7.2 headless: 14 controles geslaagd zonder scriptfouten:
import, scriptcontrole, teamtest, modelintegratie, scratch-AI, wielvolgen, rondewinst, wedstrijdregels, sprinterverbruik, volledige scratchwedstrijden, individuele achtervolging, HUD, menu en hoofdscene laden.

De nieuwe teamtest omvat:
- Alle combinaties van 3/4 renners en 1/4 km tegen AI en opgeslagen rit: acht volledige wedstrijden.
- Startformatie en tegenoverliggende start, percentages, tijdgewogen kopvermogen, gekopieerde beurtduur, automatisch uit-/af-/insturen en meerdere kopwisselcycli.
- Uitbollen zonder tempo-invloed; hervatten van aandrijving na aansluiten; AI-wissels op het juiste moment.
- Wattagedoel gecontroleerd met de echte fysica op rechte stukken en bochten; rood/groen en de bovenste HUD-box.
- Alle teamrondes en 125-meterdoorkomsten, volledige finish en exact dezelfde eindtijd voor de opgeslagen tegenploeg met een andere simulatietijdstap.
- Werkelijke menu-selectie, uitslag en opslagknop; opgeslagen ploegprestatie opnieuw via het menu gestart; scheiding tussen ploegomvang en individuele ritten.
- Trainerpauze bevriest zowel de klok als de wisselbeweging; reset en terugkeer naar scratch herstellen de gewone HUD en kleuren.
- Menu, HUD-boxen en uitslagtabel binnen de 1920×1080-referentiematen gecontroleerd.

De scratchwedstrijden van 8 renners/10 rondes en 12 renners/50 rondes leveren dezelfde tijden als voordien: 319,3 en 2499,3 s in de bestaande vaste testopstelling. Dit is een regressiecontrole, geen nieuwe balansbeoordeling.

Niet getest: visuele Godot-speeltest/GPU-weergave van de wissels, prestaties met acht geanimeerde renners op jouw hardware, fysieke trainer en alle schermresoluties. Automatische controles van posities bevestigen geen visuele vloeiendheid of leesbaarheid tijdens het spelen. Godot meldt in deze omgeving dat de certificatenopslag niet gelezen kan worden; netwerkfunctionaliteit is niet getest.

## Zelf proberen
1. Kies ploegenachtervolging, 2 ploegmaats, 1 km, AI-ploeg, CP 250 W. Start uit stilstand en rijd ongeveer 15–20 seconden op kop.
2. Druk D/pijl rechts en laat je vermogen zakken naar nul. Controleer de automatische buitenwaartse beweging, het afzakken, de aansluiting achteraan en UITBOLLEN.
3. Hervat na aansluiten het aangegeven wattage. Probeer bewust te weinig en te veel: controleer rood/groen en het geleidelijke verschil in ploegtempo.
4. Controleer de AI-kopwissels en jouw terugkeer op kop. Herhaal met drie ploegmaats en let op de percentages 40%, 60%, 80%.
5. Finish, geef de ploegprestatie een naam en sla op. Kies dezelfde ploegomvang/afstand en start tegen die prestatie. Probeer ook 4 km.
6. Controleer met C en B de verschillende camera's en het achteruitkijken. Ga terug naar individuele achtervolging en scratch: die moeten hun bestaande gedrag behouden.

## Nieuwe bronnen
team_pursuit.gd regelt kopvolgorde, percentages en wisselbeweging. team_race.gd koppelt de twee ploegen aan fysica, tijdmeting, HUD en uitslag. team_pursuit_options.gd verzorgt de ploegkeuze. tests/test_team_pursuit.gd bevat de nieuwe controles en kan headless met --script res://tests/test_team_pursuit.gd worden uitgevoerd.
