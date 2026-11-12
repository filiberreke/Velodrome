# Madison – analyse van het bestaande rig en de Godot-aansturing

Status: checkpoint 1 (inspectie) + prototype GRAB/SLING. Gemeten met Blender 5.2.2 LTS en Godot 4.7.2 (GL Compatibility).
Alle bevindingen uit de eerste inspectie zijn hieronder zelf nagecontroleerd; afwijkingen staan expliciet vermeld.

## 1. Hoe het rig is opgebouwd (`game/assets/source_blender/build_rider.py`)

* Volledig procedureel: `blender -b -P build_rider.py` bouwt armature, skin-modifier-lichaam, helm, handschoenen, fiets,
  IK-constraints, shape keys (6 morphs) en decals. Draait nog steeds probleemloos op Blender 5.2.2 (~19 s).
* Armature `RiderRig`: 27 deform-botten + control-botten die niet geëxporteerd worden.
  * deform: `root, bike, bars, crank, pedal.L/R, wheel_f, wheel_r, pelvis, spine, chest, neck, head,
    clavicle/upper_arm/forearm/hand.L/R, thigh/shin/foot.L/R`
  * control: `foot_tgt.*` (kind van `pedal.*`), `hand_tgt.*` (kind van `bars`), `knee_pole.*`, `elbow_pole.*`
* IK: twee 2-bone IK-constraints per kant (been → `foot_tgt`, arm → `hand_tgt`) plus Copy Rotation voor voet/hand;
  de poolhoeken worden bij het bouwen gekalibreerd zodat de rustpose exact klopt (fout < 1,2 mm).
* Animatie: `apply_controls(stijl, frame)` stuurt `crank`, `pedal.*`, `wheel_*`, `bike`, `pelvis`, `spine`, `chest`, `neck`,
  `head`, `clavicle.*` en `hand_tgt.*`. Stijlen: `cruise`, `sprint_seated`, `sprint_standing`, `victory`.
  Alles wordt na evaluatie van de IK **gebakken naar FK** (rotatie + translatie per bot); constraints en control-botten worden
  daarna verwijderd en `velodrome_rider.glb` wordt geëxporteerd (30 frames = 1 crankomwenteling @ 30 fps, lengte 1,0 s).
* Oriëntatie: renner kijkt naar −Y in Blender = +Z in Godot; origine onder de trapas. Renner-ruimte die ik in de Madison-scripts
  gebruik: `x` = links van de renner, `f` = vooruit, `z` = omhoog (Godot: `Vector3(x, z, f)`).

**Verificatie (geen wijziging aan de bestaande rig):** `build_rider.py` is ongewijzigd opnieuw gedraaid en vergeleken met de
ingecheckte `velodrome_rider.glb` (`madison/glb_inspect.py a.glb b.glb`):
byte-identiek is het niet (andere exporter-metadata/Blender-versie: 3 621 856 vs 3 621 520 bytes), structureel wel:
`structural differences: none | worst animation value delta 0.00e+00` (30 nodes, 27 joints, 2 meshes, 4 clips, alle waarden gelijk).

## 2. Godot-kant (`game/rider_visual.gd`)

* Eén `AnimationPlayer` in `ANIMATION_CALLBACK_MODE_PROCESS_MANUAL`; `pedal(delta, rpm, watt)` kiest de clip
  (cruise / sprint_seated > 300 W / sprint_standing > 800 W met hysterese 700 W / victory) en zoekt de clippositie op uit de crankfase
  (`seek(phase/TAU * length)`); clipwissel is instant, zonder blending. Er is geen bovenlichaam-overlay.
* **Afwijking t.o.v. de eerste inspectie:** Godot importeert de clips als `cruise`, `sprint_seated`, `sprint_standing`, `victory`
  (de `_loop`-suffix verdwijnt; `rider_visual.gd` zoekt daarom met `_resolve_animation` zowel `x_loop` als `x`).
* Trackpaden in Godot: `RiderRig/Skeleton3D:<bot>` (root_node van de player is `..` = GLB-root). De Madison-clips gebruiken
  exact dezelfde paden (test `test_madison_clips.gd`).
* `PLAYER_LANE_STEP_M = 0.60` (`main.gd`), Godot 4.7, GL Compatibility – bevestigd. Madison staat in `race_menu.gd` nog op
  "Binnenkort" (race_id 6 zit niet in de speelbare lijst) en is niet aangeraakt.

## 3. Gemeten armbereik (Blender, `madison/measure_rig.py`)

| grootheid | waarde |
|---|---|
| bovenarm / onderarm / hand (botlengtes) | 0,270 / 0,260 / 0,0825 m |
| schouderpositie t.o.v. de fietsmiddellijn | ± 0,20 m (schouder-tot-schouder 0,40 m) |
| max. gestrekt bereik schouder → pols | 0,53 m (clasp-punt 0,11 m verder, langs de handas) |
| elleboog bij 0,30 / 0,40 / 0,50 m zijdelings | 74° / 102° / 148° (180° = gestrekt) |
| pols 0,53 m zijdelings | net bereikbaar (miss 9 mm, arm gestrekt) |
| pols 0,60 m zijdelings, romp recht | 77 mm te kort |
| idem met romp 25° naar de partner gedraaid | 23 mm te kort (romp draaien wint ~6 cm zijdelings, maar de schouder gaat ~10 cm achteruit) |
| stuurdrift door fietsrol 1,5° (bars-oorsprong) | 23 mm |

Gevolgen voor de lateraal afstand G (fietsmiddellijn tot fietsmiddellijn), met de handen zijdelings en het clasp-punt 0,11 m
voorbij de pols: zijdelingse polsafstand per arm = (G − 0,40)/2 − 0,10.

| G | pols zijdelings | oordeel |
|---|---|---|
| 0,60 m | 0,0 m | arm hangt langs het lijf, stuuruiteinden ~0,2 m uit elkaar → visueel naar buiten schuiven (≥ 0,75 m) |
| 1,20 m | 0,30 m | referentiepose, elleboog 74°, 50–63 % van de gestrekte armlengte |
| 1,40 m | 0,40 m | goed haalbaar (stretch 0,80) |
| 1,50 m | 0,45 m | haalbaar maar bijna recht (stretch 0,89) |
| 1,66 m | 0,53 m | theoretisch maximum, arm volledig gestrekt |
| 1,80 m | 0,60 m | **niet haalbaar** zonder correctie (0,07 m te kort) |

→ de brief-aanname (≤ 1,40 m visuele afstand, 1,20 m ideaal, 1,80 m onhaalbaar) wordt bevestigd. Voor SLING is gemeten dat
de handverbinding bij 1,0–1,5 m binnen 3,5 mm blijft (zie README); APPROACH/GRAB bij ≠ 1,20 m is nog niet gemeten (stap 3/4).

## 4. Keuze van de implementatie (minst ingrijpend)

* `build_rider.py` en `build_pursuit_rider.py` blijven **byte-identiek**. `madison/build_madison.py` voert de rig-code van
  `build_rider.py` uit tot net vóór de sectie "keyed control actions" (`madison_common.load_rider_rig`), dus zonder kopie en zonder
  refactor. Risico: als die sectie-markering in `build_rider.py` verdwijnt, faalt het script direct (bewust, duidelijke fout).
* Clips sleutelen alleen **rotaties** van `spine, chest, neck, head, clavicle.*, upper_arm.*, forearm.*, hand.*`
  (nooit root/bike/bars/crank/pedal/wheel/pelvis/benen) → geen root motion, benen blijven van het pedaleren.
* GLB: zelfde 27-botten-skelet en dezelfde botnamen; i.p.v. de 3,6 MB renner-meshes een proxy-mesh van 27 driehoekjes
  (zodat de glTF zijn skin houdt). De exporter schrijft ook statische rust-kanalen voor niet-gesleutelde botten
  (bijv. `foot.R`); `madison_common.filter_glb_channels` haalt die eruit (270 kanalen).
* Rolvarianten (giver/receiver) i.p.v. links/rechts: gever rijdt links/binnen en geeft met rechts, ontvanger neemt met links aan.

## 5. IK in Godot 4.7.2 – bevinding

Geprobeerd: `TwoBoneIK3D` (met en zonder virtueel eindpunt/pool), `CCDIK3D`, `FABRIK3D`, `JacobianIK3D`, headless én windowed
met GL Compatibility. De klassen bestaan en emitteren `modification_processed`, maar geen enkele veranderde een bot-pose of
een gerenderde pixel (controle: een handmatige botrotatie geeft in dezelfde meetopstelling wél 798 pixels verschil; `TwoBoneIK3D`: 0).
De klassen hebben in 4.7.2 geen documentatie, dus een configuratiefout van mij is niet uit te sluiten. Daarom (zoals de brief
voorschrijft) een analytische two-bone-oplossing als `SkeletonModifier3D` in GDScript: `game/madison/madison_two_bone_ik.gd`.
Eigenschappen: clampt op het bereik (nooit uitrekken, botlengtes onveranderd – getest), behoudt het ellebooggevlak van de clip,
`influence` blendt van geanimeerde pose naar IK-pose, virtueel eindpunt = clasp-punt 0,11 m langs de hand.

Godot-valkuil: `Skeleton3D.advance()` verwerkt modifiers uitgesteld en Godot zet de geanimeerde pose daarna terug, dus
`get_bone_global_pose()` toont het IK-resultaat niet. De modifier legt het zelf vast (`last_anchor_world`, `last_error`,
`last_clamped`, `last_required_reach`), beschikbaar na de volgende `process_frame`.

## 6. Overzicht wijzigingen aan bestaande bestanden

| bestand | wijziging | reden |
|---|---|---|
| `game/rider_visual.gd` | +7 regels: `var exchange_overlay: Node = null` en in `pedal()` een early-return die alleen actief is als de overlay gezet is | de overlay-AnimationTree moet de pose van deze rider overnemen i.p.v. `animator.advance`; zonder overlay is het gedrag onveranderd (digest-test) |
| `build_rider.py`, `build_pursuit_rider.py`, `velodrome_rider.glb`, `race_menu.gd`, `main.gd` | geen | – |
