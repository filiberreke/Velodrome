# X – actief wiel opzoeken
Vervang in je bestaande Godot-project `x_scratch_ai.gd`. Andere scripts blijven gelijk aan de laatste AI-startpatch.

- Draft/chase-renners richten zich opnieuw actief op de rijlijn van een beschikbaar wiel, ook tijdens een eerdere lane-lock.
- Een renner die in de lengte al veilig achter een voorganger rijdt, verlaat die lijn niet uitsluitend om meer vrije ruimte te zoeken.
- Uitwijken wordt gereserveerd voor onmiddellijke overlap (minder dan 1,45 meter lengteafstand en minder dan 0,85 meter laterale afstand), en alleen als een veilige alternatieve rijlijn beschikbaar is.
- De bestaande vermogensbegrenzing achter een geblokkeerde renner blijft werkzaam.
- Bestaande 6 lijnen, snelheidsafhankelijke draft, AI-start en achteruitblik ongewijzigd.

Statisch gecontroleerd; nog niet getest in een Godot runtime. De voorspelde bewegingsbaan tijdens een rijlijnwissel wordt niet door een volledige collision solver gecontroleerd.
