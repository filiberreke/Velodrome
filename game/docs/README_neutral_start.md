# Geneutraliseerde start

Scratch, puntenkoers en afvalling beginnen na de bestaande trainercontrole en
aftelling met één geneutraliseerde ronde van 250 meter. De tegenstanders houden
hun startformatie rond de speler aan. De speler levert zelf het vermogen via de
trainer of de demo-instelling en kan gewoon sturen. Tijdens deze ronde zijn
aanvallen, sprinttactiek en arcadeboost uitgeschakeld.

Het scherm toont **NEUTRAAL**, een wedstrijdtijd van nul en de afstand tot het
startsein. Bij de finishlijn begint de wedstrijd met **START!**. Alle fietsen
behouden hun snelheid en fysieke positie. De ingestelde wedstrijdafstand komt
volledig na de geneutraliseerde ronde. Rondetijden, rondewinsten, sprintpunten,
afvallingen en wedstrijdstatistieken starten pas bij dit sein.

Als spelkeuze is de oprijsnelheid begrensd op 30 km/u. De speler moet bij het sein
minstens 12 km/u rijden en de groep mag maximaal 40 meter lang zijn. Dit zijn
afstembare spelparameters, geen door de UCI voorgeschreven snelheden. Wie te traag
aan de lijn komt, krijgt de melding om rustig te versnellen. Zonder trappen blijft
de start uitgesteld. Bij traineruitval geldt dezelfde korte overbrugging en pauze
als tijdens de koers; het spel schakelt daarbij niet naar demo.

De trainingsopname begint bij het vertrek en gebruikt doorlopende tijd en afstand,
ook over het vliegende startsein heen. Daardoor blijft de oprijronde in de training
staan, zonder de wedstrijdtijd of uitslag te beïnvloeden. De demo-opname gebruikt
dezelfde indeling. Herstarten wist de startfase en de opname zoals voorheen.

Achtervolging, ploegenachtervolging en tijdrit behouden hun staande start. Tempo
en Madison zijn niet toegevoegd door deze wijziging.

## Implementatie en controle

`neutral_start.gd` beheert het oprijden. `main.gd` kiest na `COUNTDOWN` voor
`NEUTRAL` of direct `RACING`. Bij de lijnpassage wordt de rekentijdstap gesplitst:
het deel vóór de lijn blijft neutraal, het deel erna gebruikt de normale koers.
Alle afstanden worden met exact één ronde verminderd. De jury en tactische AI
worden op dat moment voorbereid met de actuele posities en rijlijnen.

`tests/test_neutral_start.gd` controleert de drie disciplines op 10 en 60 stappen
per seconde, compact oprijden met zestien renners, behoud van positie en snelheid,
uitgestelde tijd- en rondentelling, trainingsgegevens over het startsein,
stilstand, te lage startsnelheid, traineruitval en de staande tijdritstarts.
`tests/capture_neutral_start.gd` maakt beelden van de oprijronde en het startsein.

Geen test met fysieke trainerhardware uitgevoerd.
