# Solo-tijdrit

Kies in het instelmenu **Staande start** (standaard) of **Vliegende start ·
1 aanloopronde**, naast de afstand van 500 meter of 1 kilometer en de referentierit.

Een staande start gebruikt de bestaande trainercontrole en aftelling. Bij een
vliegende start vertrek je na diezelfde aftelling voor één aanloopronde van 250
meter. Je kunt voluit versnellen; er geldt geen oprijsnelheidslimiet. De bestaande
solofysica en stuurbediening blijven actief.

Tijdens de aanloop verschijnt groot in beeld **NOG 250 M**, daarna **NOG 200 M**,
**NOG 150 M**, **NOG 100 M** en **NOG 50 M**. Een tweede melding verduidelijkt dat dit
de afstand tot de start is. Bij de volgende passage over de eigen startlijn
verschijnt groot en groen **GO!**. De opgebouwde snelheid blijft behouden.

De klok, rondetijden, 125 m-tussentijden en wedstrijdstatistieken beginnen pas bij
GO. Na de aanloop wordt de volledige gekozen 500 of 1000 meter gereden. De
verwachte eindtijd blijft tijdens de aanloop leeg. De trainingsopname neemt wel
de hele rit op en heeft doorlopende tijd en afstand over het startsein heen.
Traineruitval pauzeert ook de aanloop volgens de bestaande verbindingsregels.

## Vergelijken en records

Laatste rit, recent PR (60 dagen) en all-time PR worden afzonderlijk per afstand
én startwijze gekozen. Een vliegende tijd wordt dus niet met een staande tijd
vergeleken. Het recordscherm heeft hiervoor dezelfde keuze tussen staande en
vliegende start. Oude opgeslagen ritten zonder startwijze blijven als staande
start beschikbaar. De volledige historie blijft bewaard; alleen de weergegeven
ranglijst is beperkt tot tien ritten.

De uitslag vermeldt de startwijze. Bij een vliegende start vermeldt ook de
Strava-beschrijving de aanloopronde. De speler blijft de enige renner; er is geen
drafting of arcadeboost.

## Controle

Zie [validatie](../verification/flying_time_trial/VALIDATION.md).
`tests/test_flying_time_trial.gd` simuleert volledige 500 en 1000 m-tijdritten op
10 en 60 rekentijdstappen per seconde en controleert de menukeuze, aftelmeters,
behoud van snelheid, split- en finishtijden, records, opnames, traineruitval en
herstart. `tests/capture_flying_time_trial.gd` maakt beelden van het instelmenu,
de vier afstandsmeldingen, GO en het recordscherm.

Geen fysieke trainerhardwaretest uitgevoerd.
