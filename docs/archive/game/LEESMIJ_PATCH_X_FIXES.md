# Velodrome 250 — X-correctie: wielvolgen en finish (22 oktober 2026)

Deze kleine patch is uitsluitend bedoeld voor de **eerder geleverde X Godot-integratiekandidaat** op basis van je laatste `velodrome_export.zip`. De ZIP bevat geen assets, geen configuratie, geen Python-simulator en geen trainerbridge.

## Installeren

1. Maak een kopie van de werkende Godot-projectmap.
2. Pak de ZIP uit **in de projectroot**; overschrijf alleen `main.gd` en `x_scratch_ai.gd`.
3. Behoud de `scratch_lap_rules.gd` uit de eerdere X-patch. Je overige scripts, scènes en assets blijven onaangeroerd.
4. Open het bestaande project met Godot 4.7 en test een scratch van 5 ronden.

## Vier gerichte correcties

- **Achtervolgers, solisten en renners in een ontsnappingsgroep** zoeken ook naar een wiel dat nog in een andere rijstrook rijdt. Als de speler voor hen rijdt, kan hij dus als doel dienen. Binnen 23 m passen zij hun gewenste vermogen aan om het wiel te volgen, met behoud van de fysieke vermogens-/W′-beperkingen. Een urgente correctie mag de normale rijstrookvergrendeling doorbreken.
- **Solo zonder wiel**: een renner die echt alleen rijdt, stuurt terug naar de kortste toegestane rijlijn (`1.28 m`), behalve tijdens een kopwissel, aanval of inhaalmanoeuvre. Ook een geïsoleerde renner die net uit de `SOLO`-toestand valt, wordt teruggestuurd naar binnen.
- **Finishfoto**: er wordt een opname aangevraagd zodra een nieuwe voorlopige winnaar de meet kruist, niet pas wanneer alle renners klaar zijn. Mocht een renner die later finisht dankzij rondevoorsprong de winnaar worden, dan vervangt zijn opname de eerdere foto. Dezelfde winnaar triggert nooit opnieuw een foto door volgende finishers.
- **Doorrollen na finish**: elke gefinishte renner rolt onmiddellijk uit na zijn eigen aankomst, ook als de speler nog onderweg is. De geregistreerde afstand en finishtijd blijven vastgezet; alleen de zichtbare positie loopt door.

## Testscenario's

1. **Speler ontsnapt in rijstrook buiten**: laat een tijdrijder van een andere rijstrook op 5–15 m komen. Hij moet naar jouw rijstrook bewegen, een passende afstand zoeken en minder vermogen vragen wanneer hij voldoende beschutting vindt.
2. **Tijdrijder echt alleen**: als er geen geschikt wiel voor hem is, moet hij binnen enkele seconden naar de binnenkant bewegen, niet halverwege de piste blijven hangen.
3. **AI wint voor speler**: de AI moet voorbij de finishlijn blijven uitrollen en de foto van de winnaar moet al op het scorebord staan wanneer de speler later finisht.
4. **Meerdere finishers**: de foto mag niet wisselen wanneer de echte winnaar al binnen is; een later gefinishte renner met een hogere rondeklassering mag de foto wel vervangen.
5. **Speler wint**: foto van speler en normale uitrol blijven werken; herstart met R moet foto-/uitrolstatus wissen.

### Optionele headless AI-regressietest

Bestand `test_x_wheel_follow.gd` hoort bij de patch. In de projectmap:

```sh
godot --headless --path . --script res://test_x_wheel_follow.gd
```

Bij succes verschijnt `X_WHEEL_FOLLOW_OK`. Deze test verifieert achtervolgen van het spelerswiel vanuit een andere rijstrook en het rijden op de binnenste rijlijn als solist.

## Beperking

De scripts zijn hier statisch gecontroleerd, **maar niet uitgevoerd in Godot** omdat de editor/runtime in deze omgeving ontbreekt. De foto, renderframe-volgorde en daadwerkelijk uitrollen moeten dus nog in je project visueel worden geverifieerd. Dit is een gerichte patch op X, geen nieuwe versie van de Python-simulator en geen verandering aan de 1.000 Python-tests.
