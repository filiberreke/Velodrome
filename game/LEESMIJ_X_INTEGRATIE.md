# Velodrome 250 - Scratch X, Godot-integratiekandidaat

Basis: de **laatste** `velodrome_export.zip` van 22 oktober 2026. Alleen deze projectbestanden worden vervangen/toegevoegd:

- `main.gd` (aangepast)
- `x_scratch_ai.gd` (nieuw)
- `scratch_lap_rules.gd` (nieuw)
- `test_scratch_lap_rules.gd` en `test_x_scratch_ai.gd` (headless testscript, mogen na validatie blijven)

**Geen assets, project.godot, trainerbridge, Strava-scripts of persoonlijke `.cfg`-bestanden inbegrepen.** De originele models/textures blijven op hun bestaande `res://assets/...`-paden nodig om de scene te spelen. Leg de bestanden uit de ZIP in de **projectroot**, niet in een submap.

## Wat overgezet is uit Python-model X

- AI-profielen: TT CP 270.86 W, sprinter CP 235 W, aanvaller CP 224.37 W, elk met eigen piekvermogen en W'-voorraad, +/- persoonlijke dagvorm.
- W' verbruik boven CP, niet-lineaire recuperatie onder CP en langzame vermoeidheid.
- Vermogen + massa + luchtweerstand + rolweerstand -> fysieke versnelling, zonder kunstmatige vmax. **Dezelfde bewegingswet voor AI en speler** (spelersvermogen uit bestaande Wahoo/demo-integratie; aan de speler wordt geen AI-W' opgelegd).
- Cirkelvormige slipstream en wielvolgen, sterke meer-rennerbeschutting, laterale baankeuzes met lock.
- Demarrages, duurzame solo's, gerichte achtervolging, ontsnappingsgroepjes met kopbeurten (sprinters korter) en actieve wielvolging binnen kopgroepen.
- Tactisch stilvallen zonder ontsnapping en buiten de laatste twee ronden; snelle daling van kopvermogen naar ca. 43% CP.
- `FINAL_750`: positionering en individuele sprintstart voor alle profielen.
- Rondewinst alleen na daadwerkelijke drempelpassage binnen 2 meter achter de achterste renner van een voldoende grote referentiegroep, met apart klassement; ook detectie rondeverlies. Aansluiting biedt daarna weer fysieke slipstream.
- Scratchscore, speler en AI: positieve rondecredits komen voor positieve tijdsverschillen; achterstand van een ronde is zichtbaar in de uitslag.

## Verschillen met het Python-experiment

Dit is een **GDScript-vertaling en speeltestkandidaat**, niet een byte-identieke reproductie van de 1.000 Python-runs. De Godot-simulatie gebruikt Godots fysicaframes, bestaande lane/baneking- en visuele modellen, initiële startsnelheid 0 m/s, een echte menselijke vermogeninput, en wijkt op sommige tactische details af. De vorige 1.000 Python-raceuitslagen gelden NIET automatisch voor deze Godot-build.

De fysische rondecontactdrempel is strikter: van ca. 18 m in Python naar 2 m in Godot. Een ronde wordt pas uitgedeeld wanneer het *relatieve afstandsverschil* over de drempel van 248 m loopt, niet door enkel een absoluut/modulo verschil te herkennen. De implementatie kent voorlopig maximaal 1 gewonnen of verloren ronde per renner toe. Uitgebreide commissarisregels, meerdere rondewinsten en botsingen vallen buiten deze eerste speeltest.

## Teststatus, 22 oktober 2026

- De **oorspronkelijke Python X** regressiereeks: 4 tests geslaagd (`python -m unittest -q test_lap_rules.py` op de X-bron).
- De nieuwe Godot-integratie: statische integratiecontroles geslaagd, inclusief geen ongedefinieerde `summary` in Strava-export, trainerpad behouden en samengevoegde eindklassementregels.
- **Godot 4.7 was niet geïnstalleerd in de uitvoeromgeving. De GDScript-code is niet gecompileerd, niet via Godot-headless getest en niet interactief gespeeld.** De patch is dus nog niet door Godot-runtime validatie heen. Niet meteen als definitieve release verspreiden.

### Lokale stappen voor Godot 4.7

1. Maak een back-up van je huidige project.
2. Pak de ZIP in de projectroot uit. Bewaar de assets uit je eigen project; niet vervangen.
3. Open het project met Godot 4.7; los eventuele parsefouten uit de console eerst op.
4. Voer indien beschikbaar uit: `godot --headless --path /pad/naar/project --script res://test_scratch_lap_rules.gd` en daarna `godot --headless --path /pad/naar/project --script res://test_x_scratch_ai.gd`.
5. Speel scratch 1 ronde (sprinter/TT), 25 ronden (tegenaanvallen, kopgroep, eindspurt) met demo en daarna echte Wahoo.
6. Controleer specifiek: speler rondt groep, AI rondt groep, rondeverlies, niet dubbeltellen, slipstream na ronding, correcte speler- en AI-klassering, geen snelheidsplafond, en bestaande Strava-export.

## Risico's om gericht na te testen

- De Python/Godot tactische stroom verschilt door framesnelheid en startsituatie; als koersuitkomsten te ver afwijken moet de AI in Godot opnieuw worden gekalibreerd op meetgegevens.
- Het huidige script bevat nog oudere AI-methoden voor andere toekomstige wedstrijdtypes; de X-AI wordt uitsluitend ingeschakeld bij `race_mode == 0` (scratch).
- Fietsen kunnen tijdens inhalen nog tijdelijk visueel overlappen: dit is geen botsingsmodel.
- Een rondeverlies/-winst wordt gecontroleerd tegen de grootste groep met rondecredit 0; bij complexe meervoudige rondingen moet de scheidsrechterslogica worden uitgebreid.
- De gemiddelde sprintfinish, overwinningspercentages en de 1.000-run statistiek van Python X zijn niet herhaald in deze Godot-build.
