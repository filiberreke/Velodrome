# Meerdere stadions — issue #59

Branch: `feature/multiple-venues`.

## Wedstrijden starten

Kies een wedstrijdvorm en daarna bij **Locatie** de tegel **Vélodrome** of **Gent**. Iedere tegel toont een echt overzichtsbeeld van de piste en de naam. De actieve tegel is in kleur; de andere afbeelding en tegel zijn grijs. Bij individuele en ploegenachtervolging staat de keuze bij de tegenstander en sterkte. De keuze wordt bewaard als menuvoorkeur. De bestaande ontwerpweergave van Gent blijft beschikbaar om de inrichting te bekijken.

Een nieuw omnium heeft dezelfde tegels bij de spelinstellingen. De locatie blijft instelbaar totdat de eerste discipline begint. Daarna is ze vastgelegd voor het hele toernooi, inclusief hervatten, afbreken/opnieuw proberen en archiveren.

## Werkelijke baanlengte

| Locatie | Ronde | 500 m | 1 km | 4 km |
|---|---:|---:|---:|---:|
| Vélodrome | 250 m | 2 ronden | 4 ronden | 16 ronden |
| Gent | 1000/6 m | 3 ronden | 6 ronden | 24 ronden |

Vrij ingestelde wedstrijden gebruiken het gekozen aantal ronden. Puntenkoers en temporace behouden hun sprintmomenten in ronden. Keirin telt drie ronden achter de derny en drie vrije ronden; afvalling gebruikt twee ronden per afvalling. Een verkort omnium gebruikt één ronde per afvalling en twee slotronden voor het laatste tweetal. De overige omniumafstanden blijven in meters gelijk aan het gekozen format: bijvoorbeeld 5 km scratch = 20 ronden op Vélodrome en 30 op Gent.

## Techniek en opgeslagen gegevens

`venue_runtime.gd` configureert geometrie, rondetelling, jury, AI, bel, minimap, half-rondesplits en camerareferenties voordat de renners voor een nieuwe wedstrijd worden geplaatst. Een stadion wisselen tijdens een actieve wedstrijd is niet toegestaan. Bij een volgende wedstrijd wordt de vorige aankleding verwijderd en de eigen bouwer van de geselecteerde locatie gebruikt. Gent krijgt dus geen Vélodrome-tenten of supporters als neveneffect.

Prestaties, tijdritreferenties, opgeslagen achtervolgingen en omnium bevatten `venue_id`, `lap_length_m` en `geometry_version`. Referentieritten en records worden op de gekozen locatie gefilterd. Oudere gegevens zonder locatie blijven Vélodrome; er is geen destructieve herschrijving. Trainervermogen en werkelijk afgelegde meters worden niet met de stadionmaten geschaald. De bestaande trainingsmenu's blijven Vélodrome gebruiken; de omniumopwarming volgt de toernooilocatie.

Gent gebruikt zijn eigen jury, rondenteller, tv-box, eigen introtraject en uitgang naar de rennerboxen. De uitslag gebruikt in Gent de finishcamera; er wordt geen bestaand Vélodrome-podium naar het volle Gent-middenplein gekopieerd.

## Controle en ontwerp

- [Integratie, tests en actuele screenshots](WEDSTRIJDEN.md).
- [Gent: inrichting en ontwerpweergave](gent/GODOT.md).
- [Oorspronkelijke analyse en bouwbrief](gent/ontwerp.md), [fotobronnen](gent/referenties.md), [historische uitvoeringstaken](taken.md).
- [FPS-vergelijking](PERFORMANCE.md): meting vóór de wedstrijdintegratie op een software-renderer; geen voorspelling voor een laptop-GPU.
