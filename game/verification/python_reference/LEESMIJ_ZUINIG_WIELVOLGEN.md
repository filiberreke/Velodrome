# Velodrome 250 X - Sprinters: zuiniger wielvolgen (simulator)

Dit pakket bevat een experimentele Python-simulator, **geen Godot-patch**. Gebaseerd op de actuele simulator met actieve wielkeuze, 6 rijlijnen, snelheidsafhankelijke draft, krachtige start en basis-CP van aanvallers **250 W**. Sprint-CP blijft **235 W**; CP, W', piekvermogen, sprint- en rondewinstregels zijn niet bijgesteld.

## Nieuw in het gedrag (alleen sprinters, variant L)

1. **Wiel vasthouden.** De AI onthoudt de laatst gekozen voorganger en behoudt deze als de afstand en lijn goed zijn. Bij een nieuwe keuze krijgen beschutte, goed uitgelijnde en nabijgelegen voorgangers voorrang. Bestaande conflictdetectie in de rijlijnen blijft leidend; er wordt nooit geteleporteerd.
2. **Economischer bijtrekken.** Bij een kleine afstandscorrectie vraagt de sprinter minder extra snelheid en is het vermogen boven CP begrensd volgens de actuele W'-reserve. Vanaf een groter gat (>5,5 m) mag hij steviger bijtrekken om niet onnodig te worden gelost. Hij behoudt bestaande maximale fysica en kan nog altijd zijn wiel verliezen.
3. **Sneller positioneren achter het wiel** wanneer er voldoende ruimte is, zonder de conflictregel opzij te zetten.

De correctie is in `sim_f.py` standaard **aan** voor variant `L`. Voor reproduceerbare A/B-tests kan ze via de functie `run(..., sprinter_wheel_economy=False)` uitgeschakeld worden. Op de CLI: `--legacy-sprinter-wheels`.

## Reproduceer de analyse

Met Python 3 (alleen standaardbibliotheek):

```
python compare.py --races 100 --seed 1001 --workers 4 --out resultaten_zelf
```

Deze opdracht rijdt **100 baseline- én 100 verbeterde wedstrijden** met identieke seeds 1001..1100, afwisselend 8 en 12 deelnemers inclusief een vereenvoudigde speler. Het zijn dus 100 *gepaarde vergelijkingen* (200 runs). De scenario's rijden alle 50 ronden met variant L, actieve slot-fase, volledige 0,25s-fysica-integrator, tactische ontsnappingen en rondewinstregels. Zie `results_100_final/` voor alle CSV's.

`python sim_f.py --variant L --races 20 --laps 50 --out tests` gebruikt standaard het nieuwe wielvolgen, maar de commandline-snelinstellingen van `sim_f.py` zijn niet identiek aan het uitgebreide wedstrijdscenario van `compare.py`. Vergelijk dus met **compare.py**.

## Resultaten 100 identieke seeds

| Onderdeel | Basis | Nieuw |
|---|---:|---:|
| Sprinter effectieve drafting t/m eigen ronde 45 | 46,99% | 51,48% |
| Sprinter gemiddelde vermogen t/m ronde 45 | 259,26 W | 253,87 W |
| Sprinter W' bij eigen ronde 45 | 8,02% | 10,39% |
| Sprinter gemiddelde W' bij finish | 2,36% | 2,88% |
| AI-zeges sprinter | 5 | 18 |
| AI-zeges aanvaller | 41 | 39 |
| AI-zeges tijdrijder | 54 | 43 |
| Effectief drafting-aandeel alle AI | 45,57% | 46,98% |
| Gemiddelde spreiding alle AI | 198,16 m | 227,65 m |
| Sprinter uitvalevents gemiddeld per renner | 1,71 | 1,66 |

**Interpretatie:** het zuiniger wielvolgen helpt gemiddeld qua echte beschutting, vermogen en W'-reserve, maar maakt de totale spreiding groter (bijvoorbeeld doordat renners soms uiteenrijden terwijl ze energie sparen). Dit is een **trade-off**, geen afgeronde oplossing voor pelotoncohesie. W' rond 10% bij ronde 45 is nog steeds laag. Dit is geen gevalideerde biomedische voorspelling.

## Controle en bekende beperkingen

- Python-syntax en CLI-smoketest slagen. De gepaarde simulatie (100 seeds x 2 scenario's) is voltooid.
- `python -m unittest -v test_lap_rules.py`: 2/4 tests slagen. De twee falende tests rond rondewinst waren **ook in de voorgaande simulator al niet geslaagd** en zijn met deze sprintercorrectie niet gerepareerd. De rondewinstfunctie blijft dus een apart te onderzoeken probleem.
- Dit pakket past **de speelbare Godot-code niet aan**. De Godot-rijlogica heeft eigen variabelen en vereist een aparte implementatie na verdere validatie.
- In de simulator is de speler vereenvoudigd; de uitslagen hier zijn de AI-winnaars.
