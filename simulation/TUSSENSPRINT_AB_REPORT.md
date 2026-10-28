# TUSSENSPRINT: werkelijk uitgevoerde A/B-proef — 28 oktober 2026

200 wedstrijden voltooid: 100 A en 100 B, steeds 40 ronden op 250 m met 16 AI-renners. Seeds 1001–1100 zijn gepaard. De volledige definitieve batch is herhaald: alle 12 resultaat-CSV’s zijn bytegelijk, zie `repeat_verification.json`. De herhaling telt niet als extra onafhankelijke wedstrijden. B houdt meer W′ over en verschuift winst naar sprinters. Dit bewijst geen algemene verbetering van racebalans of volledige UCI-conformiteit.

## Bron en proefopzet

GitHub `main` vastgezet op `edab6a112df472ec301603bf56919c827dde0355`. Bronbestanden: `simulation/sim_f.py` (blob `3fc33da1c4c7d6ed4f92ee4a3ccee5b5565126c5`) en `simulation/energy_core.py` (blob `49effd46f6f643665a71dd3654de7c4567099624`). Geen oudere lokale simulator is als wedstrijdengine gebruikt.

De gebruiker koos expliciet de speelbare puntenkoers-CP’s: tijdrijder 265 W, sprinter 240 W, aanvaller 250 W. De runner stelt die voor beide armen identiek in; het energiebronbestand blijft bytegelijk. De standaard Python-CP’s waren 270,86 / 235 / 250 W. W′ en piekvermogen blijven respectievelijk 24120,4 J / 856,79 W; 30638 J / 1661,88 W; 32658,4 J / 1149,1 W, vóór identieke individuele vormvariatie. Er rijden zes tijdrijders, vijf sprinters en vijf aanvallers.

A gebruikt de huidige herhaalde sprintvraag uit `game/points_ai.gd` op dezelfde actuele Python-fysica. De oude Python-puntenmodus had nog vijf­rondensprints, 3/2/1 en 6/4/2/1; die proxy is voor beide armen vervangen door dezelfde aparte jury. Dit is dus een geïsoleerde tactiekvergelijking binnen de aangepaste puntenproef, geen replay van de oude Python-proxy en geen Godot-benchmark. Eindsprint, overige tactiek, energieformules, drafting, baan-/bankkosten en snelheidsintegrator zijn in beide armen gelijk. De bestaande Python-spelersentinel staat buiten de wedstrijd; alle 16 echte deelnemers zijn AI.

`Rider`, `road_power`, `integrate_speed`, `draft_speed_factor`, `bank_height` en `lane_distance_multiplier` zijn per Python-AST vergeleken met de vastgezette bron en identiek bevonden; zie `physics_verification.json`. De bestaande optie `real_laps=True` staat in beide armen aan, zodat wielvolgen over een rondeverschil dezelfde fysieke beschutting kan geven. Eerdere verkennende uitvoer zonder die optie is niet in deze resultaten opgenomen. De tijdstap blijft 2 s met de bestaande integratie van 0,25 s.

## Nieuwe tactiek

TUSSENSPRINT geldt alleen voor de tussensprints in ronde 10, 20 en 30. Een gedeelde momentopname voorkomt volgordeafhankelijke tegenstanderinschattingen. Verwachte aankomsttijden gebruiken snelheid, afstand tot de bruikbare lijn, actuele W′ en de bestaande power-duration- en snelheidsfuncties. Een logistieke onzekerheidsaanname geeft heuristische kansen op 5/3/2/1 punten. Deze kansen zijn niet empirisch gekalibreerd.

De reserve wordt groter bij meer resterende afstand en meer volgende sprints. Een goede puntenkans of kleine late achterstand kan reserve vrijgeven. Bij minder dan 23% topvierkans, minder dan 0,45 verwachte punten of minder dan 500 J vrij sprintbudget wordt de sprint overgeslagen of afgebroken. De reserve begrenst sprintvraag; aanvallen en wielvolgen buiten die inspanning mogen nog W′ kosten. Het is geen harde garantie dat de renner nooit onder de reserve komt. De eindspurt gebruikt in beide armen dezelfde oude sprintfunctie.

## Winst, sprints en ronden

Alle cellen zijn A → B. Sprintzeges en sprintpunten omvatten de drie tussensprints plus de dubbele eindsprint. Rondepunten zijn daarvan uitgesloten.

| Profiel | Wedstrijdzeges /100 | Sprintzeges /400 | Sprintpunten | Rondewinsten | Rondeverliezen |
|---|---:|---:|---:|---:|---:|
| Tijdrijder | 32 → 33 | 95 → 130 | 1646 → 1969 | 12 → 18 | 232 → 142 |
| Sprinter | 16 → 26 | 136 → 100 | 1526 → 1315 | 1 → 2 | 460 → 482 |
| Aanvaller | 52 → 41 | 169 → 170 | 2328 → 2216 | 3 → 13 | 144 → 127 |

Sprinters winnen eerste tussensprints 68 → 11 en eindsprints 16 → 31. Tijdrijders winnen eerste tussensprints 0 → 43 en eindsprints 41 → 21. Aanvallers winnen eindsprints 43 → 48. De winstverschuiving bewijst geen betere balans; de zes/vijf/vijf profielverdeling en jurykeuze tellen mee.

## W′ rond de sprints

Gemiddeld percentage van de individuele W′-capaciteit. Meting op dezelfde geïnterpoleerde koersklok bij het openen van iedere sprint, dus zodra de eerste renner die sprintlijn passeert. Dit is het gezamenlijke meetmoment onmiddellijk na de winnende lijnpassage; niet het persoonlijke einde van iedere renner. `energy_crossing.csv` bevat daarnaast de W′ bij ieders eigen sprintpassage, en `energy.csv` de gezamenlijke meting. Interpolatie binnen de bestaande 2-s stap is een benadering.

| Profiel | Na sprint 10 | Na sprint 20 | Na sprint 30 | 5 ronden te gaan | Na eindsprint 40 |
|---|---:|---:|---:|---:|---:|
| Tijdrijder | 23.08% → 36.28% | 4.89% → 22.26% | 4.54% → 17.65% | 12.16% → 16.10% | 4.31% → 5.17% |
| Sprinter | 15.32% → 43.45% | 3.12% → 17.30% | 3.09% → 12.37% | 8.19% → 10.85% | 3.00% → 2.99% |
| Aanvaller | 21.56% → 40.29% | 4.86% → 23.86% | 4.45% → 17.83% | 12.43% → 16.06% | 4.29% → 4.52% |

De gepaarde gemiddelde winst bij vijf ronden te gaan is +3.93 procentpunt voor tijdrijders, +2.65 procentpunt voor sprinters, +3.63 procentpunt voor aanvallers. `paired.csv` bevat de 100 seedparen per profiel. Dezelfde seeds geven identieke beginprofielen; na andere tactische beslissingen kunnen random trekkingen in de gedeelde AI uiteenlopen. Dit is geen gemengde A/B-competitie waarin één B-renner tegen A-renners rijdt.

## Vroegtijdige uitputting

Operationele definitie: minimaal één 2-s observatie op ≤5% W′ vóór het gezamenlijke ronde-35-meetmoment; “leeg” betekent ≤1 J. De laatste stap die de checkpoint bevat is niet meegeteld. Dit is een spelmodelmaat.

| Profiel | Renner-wedstrijden | Ooit ≤5% vóór ronde 35 | Ooit ≤1 J vóór ronde 35 | Afgebroken sprintbeslissingen |
|---|---:|---:|---:|---:|
| Tijdrijder | 600 per versie | 568 → 147 | 252 → 126 | 0 → 115 |
| Sprinter | 500 per versie | 499 → 285 | 319 → 275 | 0 → 73 |
| Aanvaller | 500 per versie | 484 → 113 | 154 → 92 | 0 → 146 |

Afbreken telt een overgang van een actieve poging naar afzien; een renner kan later opnieuw proberen. B vermindert vroege uitputting, maar 275 van de 500 sprinter-wedstrijden raken nog vrijwel leeg vóór ronde 35. De tactiek lost de overige energievraag niet op.

## Regels, jurycontrole en beperkingen

De gelezen officiële [UCI Part III, 01.09.2026](https://assets.ctfassets.net/761l7gh5x5an/7IE4WjTvQLqeRF5aniDP34/886f3c73d9f0241465b71f9e2e0833d8/PART_3_E_-_As_of_01.09.2026.pdf), artikelen 3.2.116–119 en 3.2.125, schrijft op 250 m tien­rondensprints, 5/3/2/1, dubbele slotpunten, ±20 rondepunten en finaleplaats als tiebreak voor. Bij de bel moet de koerskop vaststaan; rondewinst bij een sprint kan beide soorten punten opleveren.

De septemberversie is via de officiële UCI-downloadlink gelezen (artikelen 3.2.114–133). De wijziging naar acht ronden op exact 333,33 m raakt deze 250 m-proef niet. De gevraagde 10 km is een proefafstand. Startopstelling, vliegende start, incidenten, neutralisaties en discretionaire jurybeslissingen zijn niet gemodelleerd. Het verbod op kopwerk door gedubbelde renners voor koplopers (3.2.126) wordt evenmin afgedwongen.

Ook gelezen: `game/points_race_rules.gd`, `game/peloton_state.gd`, `game/points_ai.gd` en `game/docs/README_points_race.md` op dezelfde commit. De aparte Python-jury volgt hun lijnpassage-/rondecorrectieconventie, met gedeelde punten bij exacte ties toegevoegd. Er is geen uitgevoerde Godot/Python-tracevergelijking; de Python-groepselectie heeft bovendien een vaste ID-tiebreak bij gelijke groepen.

In alle 200 wedstrijden: nul fouten in de geprogrammeerde invarianten; vier volledige sprints met 16 unieke passages, alle energiechecks aanwezig, juiste som van sprint- plus rondepunten en geen rondepunten na de leiderfinish. Er waren nul exacte aankomstties.

Bekende afwijking: de jury registreert de bel, maar bevriest de koerskop daar niet. In A zijn er **134 van 400** sprints met een rondewijziging tussen bel en sprint; in B **120 van 400**. Dat zijn reviewgevallen, geen bewezen aantallen onjuiste uitslagen. De audit reconstrueert geen volledige officiële tegenfeitelijke uitslag. Ook gedubbelde renners worden volgens de huidige spelconventie bij hun volgende lijnpassage opgenomen, wat zonder belbevriezing een verkeerd sprintpodium kan geven.

De hoge aantallen rondeverlies (A 836; B 751) verdienen afzonderlijke modelcontrole. Herhaalde rondecorrecties komen uit de bestaande grootste-groepconventie (≥3 renners, ≤12 m aansluitafstand, ≤125 m span), niet uit een menselijke jurybeoordeling. Het onafhankelijke groep-/rondegedrag is niet fysiek gevalideerd. Meer behouden W′ is dus de sterkste conclusie; winstverdelingen blijven afhankelijk van deze jurykeuze.

## Uitgevoerde verificatie en reproduceren

Python 3.12.4 op Windows. De 12 nieuwe tests slagen. Vier bestaande scratch-laptests zijn apart op zowel gewijzigde als ongewijzigde bron uitgevoerd: twee slagen, twee falen in beide. `test_lap_gain_wins_race` en `test_rider_can_draft_after_lap_gain` verwachten een rondewinst bij seed 1049 die de huidige bron niet levert. Deze bestaande tekortkoming is niet weggewerkt door seeds te veranderen. Zie `verification.log`.

```powershell
python -m unittest discover -s simulation -p test_intermediate_sprint.py -v
python simulation/run_intermediate_ab.py --races 100 --seed 1001 --workers 4
```

`manifest.json` bevat bronhashes, parameters en de werkelijke seedlijst. `profiles.csv`, `races.csv`, `riders.csv`, `initial.csv`, `sprints.csv`, `lap_events.csv`, `energy.csv`, `energy_crossing.csv`, `energy35.csv`, `paired.csv` en `audit.csv` zijn de uitgevoerde resultaten. `decisions.csv.gz` bevat alle ruwe beslissingen met kansen en reserves; gzip is verliesloos. De gewone CSV wordt bij herhalen automatisch geschreven.

Deze oorspronkelijke A/B-proef wijzigde uitsluitend `simulation/`; de bovenstaande resultaten blijven Python-resultaten. Na de keuze van de gebruiker op 28 oktober 2026 is TUSSENSPRINT ook in de speelbare Godot-puntenkoers toegevoegd, met behoud van CP/W′, daadwerkelijke fysica en de bestaande eindsprint. De port, 64 overeenkomstige tactiekbeslissingen, vijftien geslaagde Godot-tests en een volledige 40-rondenproef op 60 Hz staan beschreven in `game/verification/tussensprint/README.md`. Dit vormt geen batch van 100 Godot-wedstrijden. De bekende bel-/rondejurybeperkingen blijven bestaan; die corrigeren en beide armen opnieuw uitvoeren blijft een afzonderlijke vervolgstap.
