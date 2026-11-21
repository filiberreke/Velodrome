# Patch X - Pelotonruimte en snelle reactie op demarrages

Deze ZIP bouwt voort op `velodrome_250_X_draft_snelheid_HUD_patch.zip`. De draftingcorrecties uit die patch zijn behouden.

## Wat is aangepast
- `x_scratch_ai.gd`: detectie van menselijke demarrages via snelheidsverandering (> 0,42 m/s²) of een snelheidsverschil (> 0,9 m/s), voordat er een gat van 15 m is. Het signaal blijft 3,5 seconden actief. Alleen nabije AI-renners met voldoende W' en samenwerking reageren; ze gaan tijdelijk in chase-modus. Hun vermogen blijft door CP/W' en piekvermogen begrensd.
- `x_scratch_ai.gd`: controle op een bezette rijcorridor (ca. 0,9 m breed). AI remt via lager aangevraagd vermogen bij een blokkade en kan kiezen uit vier verspreide rijstrookcentra voor een vrije passeerroute. Een urgente uitwijking overschrijft de vroegere lane-lock van 35 seconden.
- `main.gd`: onveranderd t.o.v. de vorige draftingpatch. Het aansturen van baanwissels blijft vloeiend via de bestaande `move_toward`-functie.

## Testen in Godot
1. Maak een back-up. Kopieer `main.gd` en `x_scratch_ai.gd` uit deze ZIP naar het project, in dezelfde map als de bestaande scripts.
2. Start een scratch, laat het peloton samenkomen en observeer AI-renners die naast elkaar rijden. Test vooral een dichte groep gedurende minstens 30 seconden.
3. Versnel vanuit het peloton plots en kijk of er al een achtervolgingsreactie begint voordat je 15 meter voorsprong hebt.
4. Controleer een demarrage uit een druk peloton, het volgen van jouw wiel en sprintposities.
5. Controleer dat de eerdere drafting-HUD en snelheidscorrectie nog werken.

## Beperkingen
De maatregelen reduceren het risico op langdurige overlappingen, maar zijn geen harde botsingsengine; nabije rennerposities blijven via bestaande fysica en snelheden bewegen. Niet in een draaiende Godot-runtime getest (Godot is hier niet geïnstalleerd). De reactieparameters en rijstrookbreedtes zijn eerste afstemmingswaarden.
