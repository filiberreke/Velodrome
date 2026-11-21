# Afvalling: pelotonrijden zonder aanvalstactiek

Aanvallen en ontsnappingen maken geen deel uit van de afvallingstactiek. Renners volgen een wiel, houden aansluiting en sparen energie. Veilige renners trekken geen sprint aan voor iedere afvalling. Alleen de bedreigde achterste renners verbeteren kort voor de jurylijn hun positie. Hun versnelling wordt begrensd ten opzichte van de eerste veilige renner. Zodra zij veilig zitten, volgen ze opnieuw een wiel. De finale met twee behoudt de eindsprint.

De afvallingstactiek staat in `game/elimination_ai.gd`. De gedeelde verkeers- en bewegingslogica voor scratch en puntenkoers blijft behouden. Een finalist blijft nu ook trappen nadat de andere finalist de finish heeft bereikt.

## Controle

Negen volledige wedstrijden met 4, 12 en 16 renners en drie reproduceerbare verdelingen van rennersvorm. Alle wedstrijden eindigen, met het juiste aantal afvallers en een finale met twee. Aanvullend zijn de bestaande spelverloop-, jury- en gedeelde verkeersproeven geslaagd. Gerichte controles bewaken wielvolgen vanuit veilige posities, inspanning bij afvallingsgevaar, geen aanvalstactieken en een werkende eindsprint.

Onderstaande cijfers zijn gemiddelden over de negen simulaties, vanaf 20 seconden na de start en voor de finale met twee. Zware inspanning betekent meer dan 120% van het kritische vermogen; dit meet inspanningsduur, niet het aantal aanvallen. Beschutting betekent effectieve slipstream boven 0,12. Spreiding betreft actieve computerrenners en kan een achterblijver omvatten.

| Maat | Voor | Na |
| --- | ---: | ---: |
| Tijd met zware inspanning | 46.2% | 22.9% |
| Tijd beschut | 57.0% | 67.6% |
| Gemiddelde spreiding | 24.2 m | 15.3 m |

De controles zijn gesimuleerd zonder beeldweergave. Bestaande waarschuwingen over asset-UIDs en het Windows-certificatenarchief veranderen de testuitslagen niet.

## Uitgebreide simulaties

De aanvullende reeks omvat 27 volledige wedstrijden: 4, 12 of 16 deelnemers, telkens met 230, 300 of 400 W spelersvermogen en drie scenario's met 60%, 80% of 100% AI-sterkte. De rennersvorm varieert reproduceerbaar van 94% tot 106%, met seeds 17, 43 en 91. Elke combinatie wordt gecontroleerd op correcte voltooiing, het aantal afvallers, eindige fysica, begrensde energie en het ontbreken van aanvalstactieken. Grote verschillen in sterkte kunnen het veld nog uitrekken; de harde inspanningen omvatten ook het terug aansluiten en het vermijden van afvalling.

De afzonderlijke resultaten staan in `game/verification/elimination_peloton/simulations.json`. Uitvoeren in Godot:

```
godot --headless --path game --script res://tests/test_elimination_peloton_simulations.gd
godot --headless --path game --script res://tests/test_elimination_peloton.gd
godot --headless --path game --script res://tests/test_elimination_gameplay.gd
godot --headless --path game --script res://tests/test_elimination_rules.gd
godot --headless --path game --script res://tests/test_shared_race_traffic.gd
```
