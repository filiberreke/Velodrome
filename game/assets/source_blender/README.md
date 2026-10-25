# Velodrome 250 – cartoonrenner + baanfiets

## Bestanden
- `velodrome_rider.glb` – game-ready voor Godot: 1 skelet, 2 meshes (`Rider`, `Bike`), 3 gebakken loops.
- `velodrome_rider_rig.blend` – bewerkbare rig met IK: voeten volgen de pedalen, handen volgen het stuur.
  Animeer daar de besturingsbotten (crank, pelvis, spine, chest, neck, head, hand_tgt.*).
- `build_rider.py` – genereert alles opnieuw. Pas `COLORS`, proporties of `STYLES` aan en run:
  `blender -b -P build_rider.py` (output in `./out`).
- `rider_animator.gd` – voorbeeldscript voor Godot.

## Animaties (30 fps, 30 frames = 1 crankomwenteling)
| naam | houding | vermogen |
|---|---|---|
| `cruise_loop` | zittend, handen bovenop het stuur | 0–300 W |
| `sprint_seated_loop` | lager, agressiever, handen in de beugels | 301–800 W |
| `sprint_standing_loop` | uit het zadel, fiets wiegt | > 800 W |

Bij `speed_scale = 1` is de cadans 60 rpm, dus `speed_scale = cadans / 60`.
Wielen draaien mee met verzet 48x16 (3 wielomwentelingen per crankomwenteling).
Alle loops hebben dezelfde lengte en fase, zodat je kan wisselen zonder dat de benen verspringen.

## Godot
- Oriëntatie: de renner kijkt naar **+Z** (Godot `MODEL_FRONT`). Origine = grond onder de trapas.
- Namen eindigen op `_loop`, Godot zet die automatisch op loopen (het script forceert het ook).
- Cartoonlook: zet in de geïmporteerde materialen `Diffuse Mode = Toon` en `Specular Mode = Toon`,
  of gebruik een eigen toon-shader. Een outline kan met een tweede pass (grow + cull front).
- Kleuren zitten per materiaal (`suit`, `accent`, `helmet`, `frame`, …) dus teamkleuren wissel je
  in Godot via `material_override` per surface of door `COLORS` aan te passen en opnieuw te genereren.

## Helm & vizier
- Moderne baanhelm met korte staart, kinriem en een doorzichtig getint vizier (materiaal `visor`, alpha 0.5).
- In Godot wordt `visor` als transparant materiaal geïmporteerd (glTF `alphaMode: BLEND`).
  Zie je sorteerproblemen, zet dan in dat materiaal `Transparency = Alpha Depth Pre-Pass`.
- Helm is opgebouwd uit naadloos aansluitende panelen (`PANELS` in het script): achterkant, zwarte band, kruin, middenstreep en vizier.
- Kleuren: `helmet`, `helmet2` (middenstreep), `visor_frame` (zwarte band + kinriem) en `visor` in `COLORS`.

## Shape keys (lichaamsbouw)
Het `Rider`-mesh heeft 6 shape keys (in Godot: blend shapes), elk van -1.0 (slanker) tot 1.0 (voller):
| naam | effect |
|---|---|
| `ShoulderWidth` | schouder- en rugbreedte |
| `TorsoMass` | borstkas en romp |
| `HipWidth` | bekkenbreedte |
| `ThighMass` | spiermassa bovenbenen |
| `CalfMass` | kuitomvang |
| `ArmMass` | armomvang |

Ze werken samen met het skelet en alle animaties; botten verschuiven niet, dus voeten en handen blijven op pedalen en stuur.
Hoofd, helm, handschoenen en schoenen veranderen niet mee.
In Godot: `set_body_shape("ThighMass", 0.8)` uit `rider_animator.gd`, of rechtstreeks
`$Rider.set_blend_shape_value($Rider.find_blend_shape_by_name("ThighMass"), 0.8)`.
De sterkte bij waarde 1.0 stel je in via `SHAPE_KEYS` in `build_rider.py`.
