# Afvalling – Python AI-testarchief (8–9 november 2026)

Deze experimentele resultaten horen bij de afzonderlijke Python-simulator, **niet** bij de Godot-spelcode. Geen wijzigingen aan `main`.

## Reproduceerbare observaties uit eerdere testruns

| Model | Wedstrijden | Gemiddelde pelotonlengte | Botsingscorrecties | Gemiddelde snelheid |
|---|---:|---:|---:|---:|
| Faseafhankelijke positionering | 7 | 181,1 m | 6.650 | 39,1 km/u |
| Voorspellende veiligheid | 7 | 138,9 m | 0 | 39,7 km/u |

De voorspellende variant telt gemiddeld 6.041 preventieve snelheidsbegrenzingen. Dat zijn ingrepen per simulatiestap, niet noodzakelijk afzonderlijke remacties.

**Let op:** nul correcties betekent niet dat de verkeerslogica fysisch correct is. De preventieve begrenzing past de berekende snelheid achteraf aan. Onderzoek nog of een volger daardoor langzamer wordt dan de voorligger, of dat wielkeuze en botsingscontrole een andere voorganger gebruiken.

## Gewenste prioriteiten

1. Botsingen vermijden vóór een manoeuvre.
2. Slipstream zoeken en aansluiting behouden.
3. Vooral in de eliminatieronde vermijden om laatste te rijden.

Net na een afvalling mag een renner achteraan rijden en energie sparen, maar niet de aansluiting verliezen. Buitenom rijden kost extra afstand/energie. Een renner mag een manoeuvre alleen starten als het voorspelde traject vrij is.

## Status

Dit is een **archief van bestaande testresultaten**, geen gevalideerde of in Godot geïntegreerde AI. Het onderzoek naar de oorzaak van de pelotonspreiding is nog niet afgerond. De volledige lokale handoff-ZIP bevat aanvullende simulatorvarianten en logs die afzonderlijk moeten worden toegevoegd om alle tests te kunnen herhalen.
