# Velodrome 250 beta.16.16b - Peloton Intelligence (experimentele delta)

**Basis:** het project `velodrome_211026.zip` van de Blender-vriend, inclusief de nieuwe boost-hond. Installeer de bestaande simulatorpatch eventueel apart.

Deze patch bevat alleen `main.gd`; alle Blender-assets, configuraties en Strava-bestanden blijven behouden.

Nieuwe logica:
- Sprinters rijden om beurten op kop / achtervolgen bij een spelersvoorsprong > 11 m. Extra kopvermogen komt uit hun beperkte anaerobe reserve.
- Renners proberen in het wiel te rijden of een snellere renner voorbij te gaan via een andere rijlijn.
- Aanvallers proberen na iedere vijfde ronde (niet allemaal tegelijk) 14 seconden op ongeveer 610 W bij 80% AI; ook dat verbruikt W-prime. Daarna 15 s herstel.
- Aanvallers rijden niet langer na de eerste startaanval voortdurend circa 100 W.
- Tijdrijders behouden hun constante doelvermogen.
- Tactische tellers worden bijgehouden in `ai_attack_count`, `ai_lead_seconds`, `ai_peloton_changes` (nog geen uitgebreid HUD of CSV-rapport).

**Beperking:** dit is een eerste AI-prototype in de live Godot-game. De eerder gemaakte Python-pelotonsimulator deelt nog niet dezelfde rekenkern en kan dus niet als bewijs gelden voor de spelbalans. Godot-runtime is hier niet beschikbaar; syntaxis en spelgedrag zijn niet live gevalideerd.

Test: 8 renners, 10 ronden, daarna 12 renners, 25 ronden. Controleer of aanvallers na ronde 5/10 versnellen, of het peloton in groep blijft en of de speler niet automatisch minutenlang alleen voorop rijdt.
