# Velodrome 250 – elf selecteerbare spelersrijlijnen

De speler kiest met A/D, pijltjes of de stuurpaddles uit elf posities: 1,18; 1,78; 2,38; 2,98; 3,58; 4,18; 4,78; 5,38; 5,98; 6,58; 7,18 meter. Eén nieuwe druk verplaatst de doelpositie 0,60 m. Ingedrukt houden herhaalt niet; laat de paddle terugkeren naar neutraal voor de volgende druk.

Het bereik blijft 6,00 m. Baanoppervlak en geometrie blijven gelijk, net als de vloeiende rijlijnanimatie, fysieke slipstreamberekening en vrije continue AI-positionering. De zes oorspronkelijke startcorridors blijven behouden om overlappende fietsen te vermijden.

Scratch, puntenkoers, afvalling, individuele achtervolging en individuele tijdrit gebruiken dezelfde handmatige rijlijnselectie. Afvalling heeft geen automatische spelerspositionering of inhaalhulpoptie. Afvalling hergebruikt de rijlijn- en verkeersafhandeling van scratch en puntenkoers; de extra afvallingsbegrenzers en blokkeringsmeldingen zijn verwijderd.

Ploegenachtervolging houdt automatische formatie: alleen een nieuwe druk op rechts vraagt een kopwissel aan. Links verandert geen rijlijn. De uitstuurafstand en finishfoto blijven op dezelfde fysieke lijn (3,58 m).

De HUD gebruikt het werkelijke aantal selecteerbare rijlijnen. Zie tests/test_player_lanes.gd voor bereik, drukherhaling, disciplines, animatie, AI-tussenposities en slipstream.
