# Complete country skinsuits (UV v1)

Both rider generators use `skinsuit_uv.py` on the original body polygons, in
rest space, before shape keys and animation baking. No extra suit shell or rig
is added. Torso (front, back and sides), shoulders, both complete sleeves and
both shorts legs have UVs. The standard rider keeps its original bare forearms
by default; selecting a kit dresses those existing polygons as long sleeves.
Hands/gloves, shoes, socks, skin outside the clothing, helmet and bike retain
their existing appearance. Six morphs and all four animation clips remain.

## Select one rider

Copy `game/riders_config.example.cfg` to `game/riders_config.cfg`, then set only
the desired section. These section numbers are peloton positions, not the four
body/profile indices. Selection also works in pursuit modes.

```ini
[player]
skinsuit_png="res://assets/riders/national_kits/belgium/skinsuit.png"

[rider_03]
skinsuit_png="res://assets/riders/national_kits/belgium/skinsuit.png"
```

Omit a key or use `skinsuit_png=""` for the original palette and prints. A missing, invalid or unreadable PNG also restores those colors and prints, with a warning. There is
no automatic Belgian override for profile 0. The example selects AI rider 03;
it has no effect until copied to the personal config file.

PNG paths can be `res://...`, relative to the game directory, `user://...`, or
absolute filesystem paths. Imported project PNGs use ResourceLoader; external
and unimported PNGs are loaded as images and receive mipmaps. In exported games,
keep custom external PNGs in a readable external folder or under `user://`.
No personal `riders_config.cfg` is committed.

Code can assign `visual.skinsuit_png` before adding the node, or call
`visual.set_skinsuit_png(path)` at runtime. `set_skinsuit_png("")` restores that
instance's original materials and default prints. The optional
`country_kit="belgium"` preset and `set_country_kit("belgium")` API also work.
An explicit nonempty `skinsuit_png` takes priority, including fallback to the
original palette if that path fails. Per-instance materials are
duplicated; neither the shared GLB nor other riders are changed. While a full
kit is selected, the four legacy chest/back/thigh prints are hidden. The
`set_decal()` API remains available for optional individual sponsor/number
prints; country clothing no longer depends on those patches.

## Helmet PNG and visor

Each player/AI section also accepts an independent `helmet_png` path, with the
same imported, relative, user and absolute path support as `skinsuit_png`.
Empty/missing/invalid images restore the original helmet colors. The PNG
covers both opaque shell panels (including the center stripe); visor, straps,
skin and suit are unaffected.

```ini
[player]
skinsuit_png="res://assets/riders/national_kits/belgium/skinsuit.png"
helmet_png="user://my_helmet.png"
visor="doorzichtig"

[rider_03]
visor="donker"
```

`visor` accepts two fixed values: `donker` (dark tinted, alpha .88) or
`doorzichtig` (light transparent, alpha .16). Omit the key to keep the original
imported visor. An invalid value warns and falls back to that original visor.
These are material presets, not visor PNGs. Outfit, helmet and visor changes
do not clear one another, and do not affect other riders.

Both generators add spherical rest-space UVs to the existing helmet shell.
Use `helmet_uv_template.svg` for painting: UV V .02-.98 runs from the lower
shell to the crown; U .02-.66 is one full wrap (back seam at .02, front at .34),
and .66-.98 is seam continuation. Crown/underside projection has normal
spherical distortion; inspect fine logos on the model. UVs follow the head bone
in all poses. Runtime APIs are `set_helmet_png(path)` and
`set_visor("donker")` / `set_visor("doorzichtig")`.

## Author another country

Create `game/assets/riders/national_kits/<country_id>/skinsuit.png`. Use a
lowercase identifier (for example `portugal`), an sRGB PNG, and the same
atlas layout. Opaque texels are clothing; alpha coverage exposes the original
model skin for short sleeves without making the body transparent.
No code registry or rebuild is needed to add another texture.
All clothing material names end in `_kit`; Godot sets their tint to white and
uses this single atlas. Other materials keep the existing rider palette.

The supplied `skinsuit_uv_template.svg` labels the islands. Coordinates below
use Blender's bottom-left UV origin; PNG rows start at the top.

| Island | U min/max | V min/max | Vertical direction |
| --- | --- | --- | --- |
| torso, full circumference | .02 / .60 | .52 / .98 | pelvis to neck |
| left sleeve | .62 / .78 | .52 / .98 | wrist to shoulder |
| right sleeve | .80 / .96 | .52 / .98 | wrist to shoulder |
| left shorts leg | .02 / .30 | .02 / .48 | knee to hip |
| right shorts leg | .32 / .60 | .02 / .48 | knee to hip |

Each rectangle's first two thirds in U contain the full circumference; its last
third is seam continuation. Paint matching content at the wrap boundary and
extend colors into gutters. Upper and lower arm segments share arc-length V;
inspect shoulder/elbow transitions when placing fine artwork. The torso's
bottom 20% contains the pelvic shorts transition. The cylindrical islands
cover every angle, including the back; they are not flat front/back decals.
Textures stretch with the existing morphs and skinning, so no pose-specific
images are needed. `make_skinsuit_texture.py` produces the reproducible Belgium
sample (light blue shirt, horizontal black/yellow/red band, black shorts,
matching sleeve cuffs) and template using Python's standard library.

## Rebuild and import (PowerShell, repository root)

Use Blender 5.2 (tested 5.2.2) and Godot 4.7 (tested 4.7.2). Substitute your
installed executable paths. Run both generators from their checked-in location
so the shared module and original decal assets can be found.

```powershell
python game/assets/source_blender/make_skinsuit_texture.py
$env:RIDER_OUT = Join-Path (Get-Location) "rider_build"
$env:RIDER_SKIP_PREVIEW = "1"
blender -b -t 4 --python-exit-code 1 -P game/assets/source_blender/build_rider.py
blender -b -t 4 --python-exit-code 1 -P game/assets/source_blender/build_pursuit_rider.py
Copy-Item rider_build/velodrome_rider.glb game/assets/riders/
Copy-Item rider_build/velodrome_pursuit.glb game/assets/riders/
Copy-Item rider_build/velodrome_rider_rig.blend game/assets/source_blender/
Copy-Item rider_build/velodrome_pursuit_rig.blend game/assets/source_blender/
godot --headless --path game --editor --import --quit
godot --headless --path game --script res://tests/test_country_skins.gd
```

The `.blend` files remain editable IK rigs. GLBs contain baked clips. Existing
`.glb.import` settings can be kept; Godot reimports the changed GLB/PNG. Do not
check in `.godot` caches. Remove `RIDER_SKIP_PREVIEW` to also render the
pursuit generator's existing studio previews; it affects only preview work.

For a regression comparison, first build the previous revision into a separate
folder with the same Blender version, then run:

```powershell
python game/tests/check_skinsuit_exports.py baseline_build rider_build
```

This checks skeleton nodes/bind matrices and animation samples exactly, and
positions, weights and six morph position deltas at 1e-6 precision, with
unchanged default material colors. It allows UV-driven vertex splits and
Blender's tessellation/normal variation on unchanged helmet/bike polygons.
The Godot test covers both rigs, all four clips, UV availability/range, morphs,
independent suit/helmet/visor selection/restoration, missing PNG fallback, imported/relative/user/absolute paths, invalid IDs, and isolation from another rider with the
same profile index.

## Ten additional country kits

See [the country catalog and build/test notes](../riders/national_kits/README.md)
and `game/riders_national_kits.example.cfg` for the ten uploaded designs, PNG
paths, editable SVGs and short-sleeve coverage. Existing rider colors and the
Belgium assets remain unchanged unless explicitly selected.
