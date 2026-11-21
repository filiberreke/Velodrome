# Madison-handsling – animatie- en integratieprototype (volledige set)

> Integratiestatus: deze levering is inmiddels aangesloten op de speelbare
> aflossingstraining. De actuele spelregels en tests staan in
> `game/docs/README_madison.md`. Onderstaande documentatie beschrijft de
> oorspronkelijke zelfstandige demo. Zijn controller heet in deze repository
> `MadisonDemoExchange`; de speelbare game blijft zijn eigen controller gebruiken.
> De instructies hieronder om `main.gd` nog te integreren zijn daarmee historisch.

Dit is een animatie- en integratieprototype, **geen speelbare discipline**: Madison blijft in `race_menu.gd` op "Binnenkort".
Gebruikte versies: Blender 5.2.2 LTS, Godot 4.7.2 (GL Compatibility). Achtergrond/rig-analyse: `RIG_ANALYSE.md`.

## 1. Overzicht

| fase | wat er gebeurt | hoe aangestuurd |
|---|---|---|
| APPROACH | beide renners blijven fietsen, bovenlijf draait naar de partner, grijparm gaat naar buiten, IK-gewicht groeit | `approach_t` 0..1 (start automatisch, 1,0 s) |
| GRAB | A-knop (Advanced) of automatisch (Easy): crossfade approach-eindpose → greeppose, IK-gewicht → 1 | `mix_sling` 0→1, `ik_weight` 0→1 (0,2 s) |
| SLING | handen blijven aan `HandContact`; opbouw tot de piek op `sling_t` 0,6, daarna gecontroleerde afbouw | `sling_t` 0..1, **geen vaste duur** |
| RELEASE | handen open, arm terug naar het stuur, romp terug naar voren – vanuit elke `sling_t` | `mix_release`, `release_t`, `ik_weight` 1→0 |
| SEPARATE | overlay fadet naar 0; renners hervatten hun gewone animaties; alles wordt opgeruimd | `overlay` 1→0 (0,3 s) |

## 2. Clips (`game/assets/riders/madison/madison_anims.glb`)

Pose-strips per rol (`giver` = snelle renner, links/binnen, grijpt met rechts; `receiver` = rechts/buiten, grijpt met links).
Nooit op tijd afgespeeld: Godot zoekt ze op met een genormaliseerde parameter.

| clip | parameter | frames @30 fps | inhoud |
|---|---|---|---|
| `madison_<rol>_approach` | `approach_t` | 31 | bovenlijf draait naar partner, arm naar buiten; einde = clasp-punt 0,10 m vóór het contactpunt |
| `madison_<rol>_sling` | `sling_t` | 61 | handen op `HandContact`; piek op 0,6; afbouw tot 1,0 |
| `madison_<rol>_release` | `release_t` | 31 | start = greeppose, handen open, arm terug naar het stuur |

* Gesleuteld: alleen rotaties van `spine, chest, neck, head, clavicle.*, upper_arm.*, forearm.*, hand.*` (12 botten). Nooit
  `root, bike, bars, crank, pedal.*, wheel_*, pelvis` of benen → geen root motion, pedaleren blijft bestaan. (Clavicula's zijn constant.)
* Dezelfde 27-botten-skeletstructuur en botnamen als `velodrome_rider.glb`; trackpaden `RiderRig/Skeleton3D:<bot>` (getest).
* Blender: `HandContact`-empty + per grijphand een Child-Of-constraint op `hand_tgt` (influence-curve bars → contact), daarna naar FK gebakken.
* Godot importeert de clips als `madison_giver_sling` enz.; de importer dunt keys uit (≤ 0,56° afwijking, gemeten), de IK vangt dat op.

## 3. Parameters en bereik (`madison_profile.gd`, `madison_profile.json`)

| naam | bereik | betekenis |
|---|---|---|
| `approach_t`, `sling_t`, `release_t` | 0..1 | clip-opzoekparameters |
| `efficiency(sling_t)` | 0..1 | exact 1,0 bij 0,6; 0,35 bij 1,0; **dezelfde curve** voor HUD-balk en pose-intensiteit |
| `slider_width(sling_t)` | 0,12..1,0 | HUD-balkbreedte; piek (0,6) = maximale breedte |
| `lateral_gap` | m | gameplay-afstand tussen de fietsmiddellijnen (grijpen mag ≤ 1,80 m = 3 lijnen) |
| `mix_sling`, `mix_release`, `overlay`, `ik_weight` | 0..1 | crossfades/IK-gewicht van de overlay |
| `release_crossfade_seconds(t)` | 0,20–0,40 s | 0,20 + 0,20·efficiency (verder van de greeppose = langere crossfade) |

Bewezen (test `test_madison_clips.gd`): Blender-tabel == GDScript-formules; argmax efficiency = 0,6; `slider_width(0,6)` = max; de zichtbare duw
van de gever (gemeten aan de animatie) volgt de slidercurve over de hele sling met max. 1,1 % afwijking.

## 4. `MadisonExchange` (`game/madison/madison_exchange.gd`)

Eén controller voor beide renners. Toestanden: `IDLE, APPROACH, GRAB, SLING, RELEASE, SEPARATE`.
Variabelen: `approach_t, sling_t, release_t, efficiency, lateral_gap, visual_gap, grab_window_open, release_reason`.

| signaal | wanneer |
|---|---|
| `approach_started` | `start()` aangeroepen |
| `grab_window_opened` | `approach_t` ≥ 0,80 en gap ≤ 1,80 m |
| `grabbed` | na de GRAB-crossfade; handen zijn verbonden |
| `grab_failed(reden)` | `"too_far"` (gap > 1,80), `"too_early"` (A vóór het venster, Advanced), `"missed"` (venster voorbij zonder A) – schone afbreking |
| `sling_peak` | `sling_t` passeert 0,6 |
| `released(efficiency)` | begin RELEASE; `release_reason`: `"auto"` (Easy), `"player"` (A los), `"max_hold"` (`sling_t` = 1), `"reach"` (gecontroleerde vroege release) |
| `separated` | alles opgeruimd, terug naar `IDLE` |

* **Easy:** grijpt automatisch rond `approach_t` 0,95, laat automatisch los op de piek (0,6).
* **Advanced:** `a_held` door de game gezet; A in het venster = GRAB; `sling_t` loopt (0,6/s) zolang A ingedrukt is; loslaten = RELEASE; na `sling_t` 1,0 `max_hold`.
* **Vroege release:** `ik.last_required_reach / max_reach` ≥ 0,94 gedurende 2 frames → release met reden `"reach"` i.p.v. uitrekken (gemeten: contact blijft < 5 mm tot de release).
* **Snelheidsoverdracht** (in de controller, niet in de animatie): bij release `transfer = efficiency · 3,0 m/s`; `speed_receiver += transfer`,
  `speed_giver −= 0,8·transfer` (ramp 0,6 s) als *verzoeken* in `speed_giver/speed_receiver`; de game beslist voor de speler.
* **Sturen:** de afgeremde renner = de gever. `outward_role == "giver"` en `outward_progress` 0→1 (1,5 s) als de gever AI is (game stuurt hem naar boven de blauwe lijn);
  is de gever de speler, dan is `outward_role == ""`. Een speler-ontvanger wordt nooit automatisch gestuurd (getest).
* **Visuele laterale correctie** (alleen `rig_scene`-offset + lichte lean ≤ 4°, nooit de gameplaypositie): gap > 1,40 m → visueel 1,40 m; gap < 1,00 m → visueel 1,00 m
  (brief: ≥ 0,75 m; gemeten is ≥ ~0,95 m nodig voor < 5 mm IK-fout, anders zijn de armen te sterk gevouwen).
* Na SEPARATE worden `AnimationTree`, IK-modifier en library van beide renners verwijderd; andere renners krijgen nooit iets.

### Integratie in `main.gd` (nog niet doorgevoerd; Madison blijft "Binnenkort")
```gdscript
# 1. eenmalig: var madison := MadisonExchange.new(); add_child(madison)
# 2. start (bv. wanneer gever en ontvanger binnen 3 lijnen naast elkaar rijden):
#      madison.start(bikes[g].get_child(0), bikes[r].get_child(0), mode, "giver" / "receiver" / "", speeds[g], speeds[r])
# 3. elk frame in _update_visuals (vóór de pedal()-aanroepen van de twee renners):
#      madison.a_held = Input.is_action_pressed(<A-actie>)            # alleen Advanced
#      madison.set_gameplay(absf(lane_offsets[r] - lane_offsets[g]), distances[r] - distances[g])
#      madison.tick(dt)
# 4. snelheid/sturen: lees madison.speed_giver / speed_receiver (AI: toepassen; speler: zelf beslissen)
#      en madison.outward_role / outward_progress (alleen AI-gever naar boven de blauwe lijn sturen)
# 5. verbind signalen met HUD/punten: released(efficiency), grab_failed(reden), separated
# 6. HUD-balk: breedte = MadisonProfile.slider_width(madison.sling_t); sweet spot = midden; timing-slider tijdens APPROACH = approach_t
```
`rider_visual.pedal()` hoeft niet aangepast te worden: de overlay haakt via `exchange_overlay` in (zie `changes.patch`).
De controller gebruikt `rig_scene.global_transform`, dus werkt ook op de gebankte baan met fiets-/lean-rotaties.

## 5. Laterale afstand – scenario D (Easy, controller)

| gameplay-gap | visuele gap | verschuiving (totaal) / lean | Blender FK-handafstand zónder IK (min / gem / max) | Godot IK-fout (hele sling) | max. armstrekking sling / einde approach | zonder visuele correctie |
|---|---|---|---|---|---|---|
| 0,60 m | 1,00 m | 0,40 m / 4° | 42 / 51 / 57 mm | 1,15 mm | 0,59 / 0,35 | IK-fout tot 13 mm, armen sterk gevouwen, stuuruiteinden ~0,2 m uit elkaar |
| 1,20 m | 1,20 m | geen | 8 / 23 / 33 mm | 1,12 mm | 0,62 / 0,43 | – |
| 1,80 m | 1,40 m | 0,40 m / 4° | 48 / 56 / 63 mm | 1,15 mm | 0,66 / 0,47 | **onhaalbaar**: IK-fout 115 mm, armstrekking 1,22 (clamp) |

Extra correcties zijn dus nodig bij 0,60 m (naar buiten, zachte noodzaak) en 1,80 m (naar binnen, harde noodzaak). Verschuiving + lean laten ~5 cm FK-restafstand over, die de IK wegwerkt.
Bronnen: `scenarios_summary.csv`, `blender_fk_hand_distance.csv`, `sling_contact_gap_table.csv`.

## 6. Scenario's A–D

| scenario | verloop (controller, 60 fps) | resultaat |
|---|---|---|
| A perfect | Advanced, A in het venster, vast tot `sling_t` 0,6 | release bij 0,600, efficiency 1,000 (`player`), contact 1,15 mm |
| B te vroeg | A los bij `sling_t` 0,2 | release bij 0,200, efficiency 0,210, natuurlijke terugkeer (release-test) |
| C te lang | A vast tot `sling_t` 0,95 | release bij 0,950, efficiency 0,378, release vanuit late pose |
| D gap | Easy bij 0,60 / 1,20 / 1,80 m | zie §5 |

* Blender: `game/assets/source_blender/madison/madison_demo.blend` – twee bestaande renners, één tijdlijn (marker) per scenario: A, B, C, D 0,60 / 1,20 / 1,80.
  De tijdlijnen zijn de frame-voor-frame toestanden van de echte Godot-controller (`docs/madison/measurements/timeline_*.json`); poses = gebakken FK-clips, zonder IK
  (bewust: toont waar Godot's IK/visuele correctie moet werken). Stills: `screenshots/blender_fk_*_peak.png`.
* Godot: `res://madison/madison_demo.tscn` – knoppen A/B/C/D 0,60/1,20/1,80, Easy, "Advanced: hold A / Space", plus de handmatige `sling_t`-slider, gap-keuze, snelheidsafwijking, drift en IK aan/uit. De debugbalk leest `sling_t`.

## 7. Metingen

**SLING-contact, 1,20 m** – Blender (gebakken FK-clips): max. 0,001 mm; Godot (echte pedalerende riders): FK-only max 19,6 mm → met IK **1,15 mm**.
**Andere gaps** (1,0 … 1,5 m): ≤ 3,5 mm, armstrekking 0,48 … 0,89. **Dynamisch snelheidsverschil** (ontvanger drijft ± 0,15 / 0,30 / 0,45 m, jitter, 2 s): ≤ 1,16 mm,
geen clamp. **Langsafwijking** −0,8 … +0,8 m: contact ≤ 1,1 mm zolang armstrekking < ~0,96; daarboven `clamped` (arm gestrekt richting doel, nooit uitrekken, botlengtes onveranderd).
**RELEASE vanuit 21 sling-posities** (+0,2/0,6/0,95): eerste frame sluit aan binnen 0,056° / 1,9 mm; max. stap 5,9°/frame en 26 mm/frame (1,6 m/s).
**Race-animaties ongewijzigd:** digest van alle clips en een scripted rit identiek vóór/na de patch.

### Performance, 16 renners (`tests/benchmark_madison.gd`, 600 frames, exchange in lus incl. opbouw/afbraak)
| omgeving | 16 gewone renners | 14 gewoon + 2 in exchange | extra per exchange | setup (2 trees + IK) |
|---|---|---|---|---|
| headless (CPU, dummy renderer) | 1,08 ms/frame update | 1,26 ms | ≈ 0,19 ms (0,09 ms/renner) | 13,8 ms eenmalig |
| windowed GL Compatibility, Intel Iris Xe | 0,44 ms/frame update (frame 2,2 ms) | 0,46 ms (frame 1,8 ms) | ≈ 0,02 ms, binnen de meetruis | 4,8 ms eenmalig |
Meetruis ≈ ±0,3 ms; ná opruimen is de update weer op het niveau van de gewone renners (0,40 resp. 1,23 ms). Alleen de twee betrokken renners krijgen een tree/IK; GPU-skinning niet apart gemeten.

## 8. Tests (headless)
```bash
godot --headless --path game --import
for t in clips contact release flow baseline; do godot --headless --path game --script res://tests/test_madison_$t.gd; done   # MADISON_WRITE_DOCS=1 schrijft CSV/JSON
godot --headless --path game --script res://tests/benchmark_madison.gd
godot --path game res://madison/madison_demo.tscn -- --capture=<map>      # screenshots
```
`clips`: laden, trackpaden = bestaande rig, alleen 12 bovenlijfbotten, geen root/bike/bars/crank/pedal/wheel, piek = 0,6 = max. slider. `contact`: hand-contact nominaal/gaps/dynamisch/clamp.
`release`: continuïteit vanaf 21 punten. `flow`: toestanden/signalen/Easy/Advanced/A–D/vroege release/grab_failed/opruimen/snelheid/sturen. `baseline`: race-animaties ongewijzigd.

## 9. Wijzigingen aan bestaande bestanden
Alleen `game/rider_visual.gd` (+7 regels, `exchange_overlay` + early-return in `pedal()`, inactief zonder overlay). `build_rider.py`, `build_pursuit_rider.py`,
`velodrome_rider.glb`, `race_menu.gd`, `main.gd` zijn niet gewijzigd. Motivatie en rig-onderzoek: `RIG_ANALYSE.md`.

## 10. Bekende beperkingen
* `TwoBoneIK3D` van Godot 4.7.2 veranderde in mijn tests niets (misschien mijn configuratie); eigen `MadisonTwoBoneIK` gebruikt (`RIG_ANALYSE.md` §5). IK-resultaat is pas na de volgende `process_frame` uitleesbaar.
* Niet-grijpende hand blijft op het stuur zonder IK: bij fietsrol (±1,5°) kan die hand tot ~23 mm schuiven.
* Handen zijn eenvoudige wanten die elkaar overlappen (geen vingergreep); kleur van de Blender-demo-renners is niet per rol aangepast (helmen wel).
* Simulatie van gameplay (snelheden, `ahead`) in de scenario-runner is een eenvoudige stand-in; `main.gd`-integratie, echte A-knop-input en AI-sturen naar de blauwe lijn zijn nog niet aangesloten.
* Alleen getest op Blender 5.2.2 / Godot 4.7.2 / Windows (Intel Iris Xe).
