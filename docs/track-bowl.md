# Vloeiende pistebochten — 11 november 2026

Gebaseerd op commit b2dac77, in een aparte lokale testversie. De niet-gecommitteerde Madison-bestanden in de oorspronkelijke werkmap zijn niet gewijzigd.

## Vergelijking met een echte piste

Een echte piste heeft overgangsbogen: de horizontale kromming loopt geleidelijk op tussen recht stuk en cirkelboog. Ook de verkanting verandert geleidelijk. Het hout blijft in de dwarsdoorsnede recht; de kuipvorm ontstaat over de lengte van de piste.

- Fitzgerald et al. (2022), metingen van een echte 250-meterpiste: twee rechte stukken, twee cirkelbogen en vier overgangsbogen. De gemeten maximale kromming is 0,0465/m (straal circa 21,5 m). https://pmc.ncbi.nlm.nih.gov/articles/PMC9256602/
- Stanoev (2022), geometrie van pisteoppervlakken en vloeiende polynomiale overgangsbogen: https://arxiv.org/html/2207.13556
- UCI over verkanting: voor een 250-meterpiste kan die circa 45 graden bedragen. https://www.uci.org/article/the-science-of-track-speed/5M2rrXZUZfOuGsiyh6j9vU
- UCI-reglement 2026: geleidelijke bochtovergangen; referentiewaarden voor 250-meterpistes zijn 19–25 m bochtstraal en 7–8 m breedte. https://assets.ctfassets.net/761l7gh5x5an/7IE4WjTvQLqeRF5aniDP34/ffccabbbc5b69d25994a5f656ecb2225/PART_3_E_-_As_of_01.01.2026.pdf

## Wijziging

- Vier overgangen van 36 m, elk gecentreerd rond een vroegere aansluiting tussen recht stuk en halve cirkel. De helling begint daardoor 18 m vóór die aansluiting. Er blijven echte rechte stukken en cirkelbogen bestaan.
- Kromming en verkanting volgen dezelfde vijfdegraads overgang met nul eerste en tweede afgeleide aan beide uiteinden. Er ontstaat geen abrupte stuurbeweging of knik in de stijging.
- Verkanting blijft 12–42 graden. De houtbreedte van 8,25 m wordt langs het oppervlak gemeten: horizontale projectie = breedte × cos(hoek), hoogte = breedte × sin(hoek). Voorheen werd de horizontale projectie vastgehouden, waardoor het hout in de bochten circa 11,1 m breed werd en de buitenrand te hoog kwam.
- Rijderhelling volgt de echte kromming. Afstandscorrectie, trainerhelling, verf, camera en aankleding gebruiken dezelfde gewijzigde positie-functie.
- Posities worden vooraf opgebouwd; Hermite-interpolatie houdt raaklijnen continu, ook bij de halve en hele ronde.

## Grenzen van deze versie

Dit is een verbetering van de bestaande spelpiste, geen exacte reconstructie of homologatie. De bestaande referentie-omtrek van 250 m, binnenstraal van 18 m, houtbreedte van 8,25 m en rijstrooknummers blijven het uitgangspunt. De fysieke zwarte meetlijn is, net zoals voordien, langer dan de referentie-omtrek: die is niet opnieuw gekalibreerd op exact 250 m. Een volledige UCI-maatvoering vergt een aparte afstemming van meetlijn, baanbreedte, arena en afstandsexport. Het blauwe binnenvlak behoudt de bestaande vaste dwarshelling.

## Controle

`game/tests/test_track_bowl.gd` bemonstert elke 5 cm de gesloten piste, constante oppervlakbreedte, opwaartse normaal, hellingsbereik, stijging en vloeiende aansluitingen. Het vergelijkt de grootste stijging op rijlijn 7,18 m met de oorspronkelijke piste. Bestaande controles dekken binnenrijlijnen, neutrale start, achtervolging, trainersturing, pisteoefeningen en plaatsing van omgevingselementen.

`game/tests/capture_track_bowl.gd` rendert voor/na vanuit identieke camera's met de echte spelgeometrie. De referentie voor de oude geometrie staat in `game/tests/track_bowl_before.gd`.

De bestanden in `game/` van het wijzigingspakket horen bij dezelfde paden in de game. `main.gd` is een volledige vervanging op basis van b2dac77; bij een andere bronversie moet de meegeleverde diff worden toegepast in plaats van het bestand blind te vervangen.
