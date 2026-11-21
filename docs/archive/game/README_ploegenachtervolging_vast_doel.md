# Ploegenachtervolging — vast wattagedoel en AI-kopstatus

Installatie: pak deze patch uit in de bestaande projectmap waar project.godot staat en vervang de bestanden. Vereist de vorige ploegenachtervolgingspatch en de eerder geïnstalleerde 3D-modellen. Alleen gewijzigde/nieuwe bestanden en deze README worden meegeleverd.

## Vast wattagedoel
Het referentievermogen is uitsluitend het tijdgewogen gemiddelde van de laatste afgeronde kopbeurt van de speler. Een AI-kopbeurt verandert dit gemiddelde nooit. Snelheid, baanhelling en het huidige vermogen van de AI veranderen het doel evenmin.
Het getoonde doel is dit vaste gemiddelde maal het positiepercentage:
- 3 renners: op kop 100%, tweede 80%, derde 50%.
- 4 renners: op kop 100%, tweede 80%, derde 60%, vierde 40%.

Voorbeeld: bij een laatste eigen kopbeurt van gemiddeld 300 W is het doel 150 W achteraan in een driemansploeg, en 120 W achteraan in een viermansploeg. Bij opschuiven verandert het doel volgens de nieuwe positie; het gemiddelde zelf verandert pas wanneer je opnieuw je eigen kopbeurt beëindigt. Ook tijdens een volgende eigen kopbeurt blijft het vorige afgeronde gemiddelde staan.
Tijdens de allereerste kopbeurt is nog geen vorig gemiddelde beschikbaar: dan staat er EERSTE KOPBEURT en blijft het eigen wattage neutraal. Tijdens het afzakken staat er UITBOLLEN en geldt geen wattagedoel. Rood/groen gebruikt na de eerste eigen kopbeurt hetzelfde vaste doel als de overlay.
De bestaande vermogenssturing van het ploegtempo blijft werken: tijdens volgen bepaalt jouw vermogen via de positieverhouding de daadwerkelijke aandrijving op kop. Het vaste doel is dus een referentie uit jouw laatste beurt, geen voortdurend herberekende natuurkundige compensatie voor een exact gelijke snelheid.

## Zwevende status
In ploegenachtervolging worden geen naamlabels boven de renners meer gemaakt. In plaats daarvan heeft iedere ploeg maximaal één zwevend, naar de camera gericht vermogensbordje:
- Alleen zichtbaar boven de actuele AI-koprijder; nooit boven de speler.
- Toont het werkelijke actuele vermogen op kop in watt en een horizontale vermogensbalk.
- Volgt automatisch de nieuwe AI-koprijder na een wissel.
- Ook de AI-koprijder van de tegenploeg heeft dit bordje.
- Verborgen vóór de start, in menu's, na de finish van de betreffende ploeg en bij andere spelvormen.
De balk heeft een vaste schaal van 0–1000 W. Hogere waarden vullen de balk volledig; het getal blijft het volledige werkelijke wattage tonen. Dit is een vermogensbalk, geen energiereserve. De status wordt niet in de finishfoto getoond.
De naamlabels van individuele achtervolging, scratch en de overige spelvormen blijven behouden.

## Getest
Godot 4.7.2 headless: import, scriptcontrole, uitgebreide teamtest, modelintegratie, individuele achtervolging, HUD, menu en hoofdscene laden geslaagd.
De teamtest bevat acht volledige wedstrijden: 3/4 renners, 1/4 km en AI/opgeslagen rit. Extra controles bevestigen een stabiel doel bij snelheids-/vermogensveranderingen, ongewijzigde referentie tijdens AI-beurten, vervanging na de volgende eigen beurt, eerste-beurtweergave, rood/groen, ontbreken van naamlabels, verplaatsing naar een AI-koprijder, actueel vermogen op het bordje en herstel van labels bij terugkeer naar scratch.
Visuele Godot-speeltest/GPU-weergave van het nieuwe zwevende bordje, leesbaarheid op verschillende camera-afstanden, prestaties van de twee kleine statusviewports en een fysieke trainer zijn niet getest. De headless omgeving meldt dat de certificatenopslag niet gelezen kan worden; geen scriptfouten in de geslaagde controles. Netwerkfunctionaliteit niet getest.

## Zelf controleren
1. Start ploegenachtervolging: geen naamlabels, bovenaan EERSTE KOPBEURT. Alleen de AI-koprijder van de tegenploeg heeft een vermogensbordje.
2. Rijd bijvoorbeeld een kopbeurt rond 300 W en stuur rechts. Tijdens afzakken staat UITBOLLEN; na aansluiten is het doel circa 150 W (drie renners) of 120 W (vier renners).
3. Varieer je vermogen en controleer rood/groen. Het doel blijft vast voor dezelfde positie, terwijl het werkelijke AI-kopvermogen op het zwevende bordje wel mag veranderen.
4. Kijk naar AI-kopwissels: het bordje volgt de nieuwe AI-koprijder. Wanneer jij op kop komt, verdwijnt het bordje boven jouw ploeg.
5. Rond een volgende eigen kopbeurt af op een ander gemiddeld vermogen: pas dan wordt het referentiegemiddelde vervangen.
6. Keer terug naar scratch of individuele achtervolging: de gewone naamlabels zijn weer aanwezig en de teamvermogensbordjes zijn verborgen.
