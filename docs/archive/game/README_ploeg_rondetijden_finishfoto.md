# Ploegenachtervolging — rondetijden en ploegfoto

## Installatie

Deze patch bouwt verder op de wattage-HUD en de correctie die het doelvermogen
op kop verbergt. Pak deze ZIP uit naast `project.godot` en vervang de bestaande
bestanden. Alleen nieuwe en gewijzigde bestanden zijn opgenomen. Open daarna
het project opnieuw in Godot 4.7.2. Het oorspronkelijke project is niet direct
overschreven; de gewijzigde werkkopie staat in `work/team_presentation_project`.

## Rondetijden

In ploegenachtervolging vervangt een rondetijdentabel de lijst 'Rondom jou', op
dezelfde plek links onder het persoonlijke blok. Andere spelvormen behouden die lijst.

Elke volledige ronde van jouw ploeg verschijnt direct, bijvoorbeeld:

`2   20.45 s (+0.37 s)`

De tijd is de duur van die ronde. Het verschil tussen haakjes is het totale
tijdsverschil na die ronde, bij gelijke afgelegde afstand: + is voorsprong,
− is achterstand. Zolang de tegenploeg dat punt nog niet passeerde staat er (…).
Dat wordt automatisch vervangen zodra diens rondetijd bekend is. Alle 16 ronden
van een 4 km-rit blijven beschikbaar in een scrollbare tabel; nieuwe ronden
worden vanzelf in beeld gebracht. Dit verandert de halve-rondevergelijking
onderaan niet.

## Finishfoto

De foto toont nu de volledige eigen ploeg vanuit de buitenkant van de baan,
van opzij, met een kijkrichting loodrecht op de rijrichting bij de finishlijn.
Het kader schaalt mee met de ruimtelijke afmetingen van alle drie of vier renners.

De opname wordt getriggerd door de eerste renner van jouw ploeg, onafhankelijk
van welke renner dat is en of de tegenploeg al klaar is. De posities en rijlijnen
worden tussen de simulatiestappen geïnterpoleerd tot die eerste doorkomst.
Een stilstaande kopie van de ploeg zorgt dat doorrijden tijdens het renderen
het gekozen fotomoment niet verandert. De echte renners blijven in de spelcamera
zichtbaar; tijdelijke kopieën en renderlagen worden na de opname opgeruimd.
De foto toont geen zwevende namen of vermogensbadges.

Het tijdstip in het foto-onderschrift is dat van de eerste renner en is sinds
de eerste-voorwielpatch ook de officiële eindtijd van de ploeg. Foto's voor andere modi
behouden hun bestaande camera en meetmoment.

## Antwoorden over AI en tijdmeting

- De AI-tegenploeg rijdt automatisch kop over kop, met standaard ongeveer
  20 seconden per kopbeurt. Een nog lopende wissel wordt eerst afgewerkt.
  De eigen AI-ploegmaats volgen de duur van de laatste kopbeurt van de speler.
- Sinds de eerste-voorwielpatch is de opgeslagen eindtijd die van het voorwiel
  van de eerste renner van de ploeg. De vroegere virtuele derde positie vervalt.
  Strava blijft uitsluitend de individuele spelersmetingen gebruiken. Zie ook
  `README_ploegtijd_eerste_voorwiel.md` voor de nieuwe controles en details.

## Controle

Geslaagd met Godot 4.7.2 headless: projectimport, statische scriptcontrole,
nieuwe ploegpresentatietest, wattage-HUD-test, bestaande HUD-test,
ploegenachtervolgingstest (3/4 renners, 1/4 km en opgeslagen prestaties),
individuele achtervolging, records en starten van de hoofdscene.

De nieuwe test controleert cumulatieve tijdverschillen, wachten op de
tegenploeg, behoud van de tabel bij 16 ronden, foto bij de eerste doorkomst
op hetzelfde moment als de officiële finish, complete ploegkopieën, loodrechte camera, alle
meshgrenzen binnen het fotokader, een stabiele snapshot, opruimen van de tijdelijke
renderlagen en terugkeer naar de gewone HUD/fotocamera in andere spelvormen.

Niet getest: een visuele GPU-gerenderde spelrun, zichtlijn langs stadionobjecten,
daadwerkelijke fotopixels, trainerhardware of exportbuilds. De berekende
fotokadering is dus wel gecontroleerd; de uiteindelijke foto moet nog visueel
in het spel worden beoordeeld. Godot geeft hier daarnaast de bekende melding
over de onleesbare Windows-rootcertificaten; er waren geen scriptfouten.

## Zelf controleren

1. Start een ploegachtervolging van 1 km met 2 AI-ploegmaats. Controleer per ronde
   de tabel en het teken van het verschil tegenover de onderste vergelijking.
2. Finish zowel met jezelf als met een AI-ploegmaat op kop. Bekijk of de foto
   alle drie renners toont bij de eerste doorkomst, vanuit de buitenkant.
3. Herhaal met 3 AI-ploegmaats en een wissel kort voor de finish.
4. Start 4 km: controleer dat de tabel kan scrollen en ronde 16 toont.
5. Start daarna Scratch: controleer dat de gewone rennerslijst en finishfoto terug zijn.

Automatische controle vanuit de projectmap:

```powershell
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_team_presentation.gd
& 'C:\pad\naar\Godot.exe' --headless --path . --script res://tests/test_team_pursuit.gd
```
