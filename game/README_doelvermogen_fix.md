# Correctie doelvermogen — ploegenachtervolging

Pak deze ZIP uit naast `project.godot`, over de vorige wattage-HUD-patch heen.
Alleen gewijzigde bestanden zijn opgenomen.

Het doelpijltje, de doelwaarde en de rood/groene doelkleuren verschijnen uitsluitend
wanneer de speler achter een ploegmaat rijdt, tijdens een actieve rit met een
bekend doelvermogen. Op kop en tijdens uitbollen zijn pijl en doelwaarde verborgen
en gelden de gewone wattagekleuren. De berekening van het doelvermogen verandert niet.

Getest met Godot 4.7.2 headless: wattage-HUD-test en volledige
ploegenachtervolgingstest, beide geslaagd. De controles dekken ook opnieuw op kop
komen, vervolgens weer volgen en uitbollen. Geen scriptfouten.
Niet getest: visuele GPU-spelrun en trainerhardware. ERG-aansturing blijft ongewijzigd.
