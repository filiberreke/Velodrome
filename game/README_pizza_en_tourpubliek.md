# Pizza-oven, vrienden en Tour-publiek

## Wijzigingen

- De derde pizzatafel, tussen oven en piste, is vervangen door één statafel met twee low-poly mannen naar de foto: gestreept donker shirt, baard, pizza en wijnglas links; rode polo, donkere bril en geheven wijnglas rechts. De stoelen en de oude zittende persoon van die plek zijn weg. De andere twee zitgroepen blijven behouden.
- De ovenmond heeft een gemetseld gewelf van 98 cm diep dat in de koepel dringt. De boog is verlaagd zodat hij binnen het profiel van de koepel past. De oven draagt geen tekst meer.
- Achter de Tour d'Ambiance-bocht staat op de vijfde traptrede van het onderste tribunedeel een kleine langharige chihuahua bij een lasagneschotel. Deze plek is verhoogd en zichtbaar vanuit de hogere wedstrijdcamera; vanuit lage camerastanden kunnen boarding en publiek delen afdekken.
- Op de eerste rij van dezelfde bocht staat een oudere man met grijs haar en bril, met het spandoek **WOUT WOUT WOUT!** richting piste. Een kleine plek in de normale stoelen-/publieksverdeling is vrijgehouden om overlap te voorkomen.

Alle nieuwe figuren hebben vaste poses. Geen eet-, zwaai- of gespreksanimaties. De geometrie gebruikt eenvoudige opaque materialen; de wijnglazen hebben een lichte omlijsting en zichtbare rode wijn, zonder dure glasbreking.

## Hergebruik en bron

Modellen onder `assets/people/`: `pizza_vrienden_statafel.glb`, `chihuahua_lasagne.glb`, `supporter_wout.glb`. Blender-bronnen onder `assets/source_blender/crowd/`: `build_pizza_friends.py`, `build_tour_spectators.py`, met de bestaande `people.py` en `vlib.py`. Blender 5.2.2 is alleen nodig om opnieuw te modelleren, niet om het spel te starten.

`north_infield.gd` plaatst de statafel en bouwt de oven. `tour_spectator_details.gd` plaatst hond en supporter; `arena.gd` roept die module aan en reserveert de eerste-rijplek. Geen wijzigingen aan race-, trainer-, AI-, FIT- of Strava-logica.

## Testen en installatie

De ZIP bevat alleen nieuwe en gewijzigde bestanden, relatief aan de bestaande lokale Godot-projectmap met `project.godot`. Bewaar de mappenstructuur bij uitpakken. In GitHub is de actieve projectstructuur onder **game/** gebruikt. Daar stonden de laatste mixed-zone-bestanden nog als losse patch buiten de projectmap; de benodigde interviewmodellen en scripts worden ook onder game/ samengebracht zodat de bijgewerkte noordelijke omgeving haar afhankelijkheden vindt.

Geslaagd met Godot 4.7.2: import, hoofdscriptcontrole, hoofdscène twintig frames, model-/plaatsingscontroles van pizza en Tour-details, bestaande journaliste- en bars-tests. De ovendoorgang is geometrisch gecontroleerd op echte diepte en overlap met de koepel. De exacte spandoektekst, richting, eerste-rijplaats en echte trapcoördinaat zijn gecontroleerd.

Echte Godot GPU-screenshots gemaakt en bekeken van het duo, de oven vooraan/schuin, de plaatsing in het spel, de hond op de trap en de supporter. Deze laatste grafische run gaf geen shader- of scriptfouten; de bestaande Windows-rootcertificaatmelding kan nog in de log staan.

Niet uitgevoerd: een volledige interactieve wedstrijd, een nieuwe Windows-export, een FPS-meting of tests op andere GPU's. Lage camerastanden garanderen geen ononderbroken zicht op kleine tribunedetails.

Zelf testen: start het spel, bekijk de pizzahoek en rijd door de Tour-bocht met de hogere camera. Optioneel:

```
Godot.exe --headless --path . --script res://tests/test_pizza_guests.gd
Godot.exe --headless --path . --script res://tests/test_tour_details.gd
```

Verwacht `PIZZA_GUESTS_OK` en `TOUR_DETAILS_OK`.
