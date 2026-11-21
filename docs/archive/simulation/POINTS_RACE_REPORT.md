# Puntenkoers: 100 simulaties met actuele scratchfysica

## Bron en uitvoering

Gecontroleerde GitHub-main: `169b3a8d4f0b495e17a95c508dfa64ad4e13a04d`.
De nieuwste Python-simulator werd toegevoegd in commit `94095e91f00d7297fccd38b210dd22e1433483ed` ("Voeg simulator toe"): `simulation/sim_f.py`, variant L, met `energy_core.py`. De latere merges betreffen de Godot-startopstelling en skins. De oudere `game/simulator/simulate.py` gebruikt andere, verouderde referentiefysica.
Op de gecontroleerde main en beide andere GitHub-branches bestond geen `simulation/points_race.py`. Deze wijziging voegt die module toe op basis van de actuele simulator; ze vervangt dus geen bestaand bestand op main.

`points_engine.py` is een afzonderlijke afleiding van de scratchlus. Rider/Phys, CP/W', vermogenscurve, rijlijnen, bankhoogte, extra afstand in bochten, drafting, zuinig sprinter-wielvolgen en de ongecapte 0,25s-snelheidsintegrator worden rechtstreeks uit de actuele modules gebruikt. De scratchbestanden en Godot-code zijn niet gewijzigd.

```sh
cd simulation
python -m unittest -v test_points_race
python points_race.py --races 100 --seed 1001 --workers 4 --out results_points_100
python audit_points_results.py results_points_100/races.json
```

Seeds **1001–1100**, elk **40 ronden x 250 m**, **16 AI-renners**, geen speler. Vaste profielverdeling volgens de huidige cyclische volgorde: **6 tijdrijders, 5 sprinters, 5 aanvallers**. Vorm varieert per renner van 95–105%; de tabel toont basis-CP.

## Jury en sprintgedrag

Sprints na ronde **10, 20, 30 en 40**. De eerste vier krijgen **5–3–2–1**; bij de finish **10–6–4–2**. Rondewinst/-verlies geeft **+20/-20**. Bij gelijke eindpunten beslist de volgorde van de laatste sprint. Dit volgt de kernregels voor puntenkoers op een 250meterbaan; de afstand van 40 ronden is het gevraagde simulatiescenario.

De leider bepaalt de wedstrijdklok. Elke sprint opent op zijn lijnpassage; de jury rangschikt vervolgens ieders eerste fysieke lijnpassage, ook die van gedubbelde renners. Passagetijden worden binnen de 2s-tijdstap geïnterpoleerd. Een achterblijver hoeft niet zijn eigen 40 ronden te voltooien: na de gemeenschappelijke finish passeert hij nog eenmaal de lijn. Rondepunten stoppen op het geïnterpoleerde finishtijdstip van de leider.

De aparte jury bepaalt de grootste fysieke groep op de cirkel, met maximaal 12 m tussen opeenvolgende renners, minimaal drie renners en maximaal 125 m spanwijdte. Rondepunten vereisen het bereiken van de achterkant respectievelijk het ingehaald worden door de voorkant. Gekende rondeverschillen normaliseren de referentie, zonder fysieke verplaatsing. Meerdere winsten, verliezen en teruggenomen ronden zijn mogelijk. Bij een verspreid veld zonder herkenbare groep kent de jury geen rondepunten toe.

Alle profielen kunnen sprintvermogen vragen tijdens de sprintlap; inzetmoment, vermogenscurve en reserve begrenzen de vraag. Deze vraag wordt na het wielvolgen toegepast zodat dat gedrag de sprint niet overschrijft. Aanvalskansen, samenwerken, achtervolgen en de nieuwe sprinterbesparing blijven uit variant L behouden.

## Uitslagen

| Profiel | Basis-CP (W) | Koerszeges | Ronden gewonnen | Ronden verloren | W' ronde 35 (%) | W' ronde 35 (kJ) |
|---|---:|---:|---:|---:|---:|---:|
| Tijdrijder | 270.86 | 60 | 44 | 124 | 13.37 | 3.22 |
| Sprinter | 235.00 | 2 | 5 | 736 | 4.80 | 1.48 |
| Aanvaller | 250.00 | 38 | 22 | 158 | 12.34 | 4.04 |

Rondeaantallen zijn gebeurtenissen over alle 100 koersen; één renner kan meer dan één ronde winnen of verliezen. Profielaantallen zijn ongelijk: 600 TT-, 500 sprinter- en 500 aanvallerwaarnemingen.

W' is de resterende anaerobe werkreserve, **niet alle lichaamsenergie**. Iedereen wordt op hetzelfde ogenblik gemeten: de geïnterpoleerde passage van de leider na ronde 35, vijf leider-ronden voor de finish. Zowel individuele W' als individuele maximale W' worden gebruikt voor percentages; CSV bevat ook afstand en vermoeidheid.

### Sprintwinnaars per profiel

| Ronde | Tijdrijder | Sprinter | Aanvaller |
|---|---:|---:|---:|
| 10 | 0 | 62 | 38 |
| 20 | 32 | 13 | 55 |
| 30 | 56 | 3 | 41 |
| 40 | 66 | 1 | 33 |

### Aanvallen en sprintpogingen

| Profiel | Aanvallen totaal | Gem. sprintvraag (s/renner/koers) | Gem. achtervolging (s/renner/koers) |
|---|---:|---:|---:|
| Tijdrijder | 201 | 56.08 | 0.76 |
| Sprinter | 46 | 24.30 | 0.61 |
| Aanvaller | 435 | 44.80 | 0.86 |

Tijdrijders rijden dus niet alleen passief mee: ze vallen aan en vragen sprintvermogen. Sprintvraag betekent een tactische poging, geen garantie op dat effectief geleverde vermogen of een gewonnen sprint. De gedeelde Phys- en vermogensduurgrenzen blijven gelden. Hun hogere CP lijkt in dit scenario gunstig bij herhaalde inspanningen, maar de aantallen bewijzen geen oorzakelijk fysiologisch effect.

Sprinters winnen 62 van de 100 eerste sprints, maar nog slechts één laatste sprint en twee koersen. Hun lage reserve en 736 verloren ronden tonen een belangrijke modelzwakte in herhaalde inspanningen/pelotoncohesie; ze zijn geen realistische verwachting voor een echte wedstrijd.

### Ronden per renner-ID

| ID | Profiel | Gewonnen | Verloren |
|---|---|---:|---:|
| 1 | Tijdrijder | 6 | 18 |
| 2 | Sprinter | 1 | 138 |
| 3 | Aanvaller | 5 | 29 |
| 4 | Tijdrijder | 9 | 15 |
| 5 | Sprinter | 1 | 140 |
| 6 | Aanvaller | 4 | 26 |
| 7 | Tijdrijder | 9 | 28 |
| 8 | Sprinter | 2 | 143 |
| 9 | Aanvaller | 2 | 35 |
| 10 | Tijdrijder | 2 | 19 |
| 11 | Sprinter | 1 | 158 |
| 12 | Aanvaller | 6 | 31 |
| 13 | Tijdrijder | 8 | 19 |
| 14 | Sprinter | 0 | 157 |
| 15 | Aanvaller | 5 | 37 |
| 16 | Tijdrijder | 10 | 25 |

IDs zijn posities in een profielrooster; vorm en persoonlijkheid worden per seed opnieuw getrokken.

## Controle en beperkingen

- **11 nieuwe tests slagen**: onder meer lijnvolgorde met gedubbelde renners, uitsluiten van een passage vóór sprintopening, herhaald rondewinst/-verlies, groep over de startlijn, ontbrekend peloton, gezamenlijke finish, verdubbelde punten, interpolatie ronde 35, reproduceerbaarheid en een volledige koers.
- De onafhankelijke audit controleert alle 100 opgeslagen koersen, 1600 renners, 1600 energiesnapshots en 400 sprints: unieke passages, chronologische tijden, punten uit ruwe events, netto ronden en eindrangschikking.
- De ongewijzigde scratchtests blijven **2/4** slagen: `test_lap_gain_wins_race` en `test_rider_can_draft_after_lap_gain` falen op deze bron. Dit was al vermeld in `LEESMIJ_ZUINIG_WIELVOLGEN.md`. De puntenjury gebruikt die oude scratchjury niet.
- De tactische lus is gekopieerd voor puntenkoers en moet bij toekomstige scratchwijzigingen opnieuw worden vergeleken. De gedeelde fysicafuncties en Rider worden geïmporteerd, maar tactische wijzigingen vloeien niet automatisch door.
- De kernfysica is de nieuwste **Python-simulator**, niet de volledige Godot-wedstrijd. Illustratieve baangeometrie, 2s-beslissingen, zachte lijnconflicten en deels op absolute voortgang gebaseerde ontsnappingsgroepen blijven vereenvoudigingen. Gedubbelde renners kunnen fysiek draften, maar groeps-/aanvalstactiek is nog niet overal circulair.
- De jurygrenzen voor pelotonherkenning zijn modelkeuzes. Groepswisselingen en sterk uiteengereden velden maken rondeaantallen gevoelig. Rondebeslissingen liggen op de 2s-stap, sprint- en finishtijden worden geïnterpoleerd. Energie binnen de stap wordt lineair geïnterpoleerd.
- Start vanuit stilstand; geen geneutraliseerde vliegende startronde. Geen valpartijen, neutralisaties, juryverwijderingen of dead-heat-puntendeling. Exact gelijke passagetijden worden deterministisch op ID gesorteerd.
- 40 ronden/16 AI is een apart scenario; de historische scratchbenchmark reed 50 ronden met 8/12 deelnemers en een speler. De uitslagen zijn niet rechtstreeks vergelijkbaar. Geen gevalideerde fysiologische of voorspellende sportanalyse.

## Bestanden en herkomstcontrole

`results_points_100/races.json` bevat elke volledige uitslag, aanval, sprintvolgorde, ronde-event en energiesnapshot. CSV: `riders.csv`, `sprints.csv`, `lap_events.csv`, `energy35.csv`. `summary.json` bevat de aggregaten.

SHA-256 van de ongewijzigde bronbestanden:

- `sim_f.py`: `1703dfffcb4b9f71335019fece00667e8e56f2e83cadf6ef0c5799c79180a1ec`
- `energy_core.py`: `4252b9a8028b5d53495132e37e00b43d5cb353382e1a17820caeaee9cd7429ab`

Regelreferentie: [UCI Track Events commissaires guide](https://downloads.ctfassets.net/761l7gh5x5an/58l70xQUVvCwf0lsHGbQf5/e93f50d61c6ab8d34088288cf96b5b4c/uci-guideformcommis-piste-2019-eng-hd-web.pdf), onderdeel puntenkoers.
