# Country skinsuits and helmets

Ten kits adapted to the front/back designs supplied in this chat, alongside
the existing Belgium sample. Assets do not select or recolor any rider until
configured. No personal configuration files are distributed.

| ID / directory | Country | Sleeves | Helmet |
| --- | --- | --- | --- |
| `denmark` | Denmark | long | white |
| `portugal` | Portugal | long, left red / right green | white |
| `italy` | Italy | short | white |
| `great_britain` | Great Britain | short | white, Union Jack / GBR |
| `australia` | Australia | long | white |
| `new_zealand` | New Zealand | short | white, black fern |
| `germany` | Germany | short | white |
| `france` | France | long | white, French flag |
| `netherlands` | Netherlands | long | white, Dutch flag |
| `united_states` | United States | long | navy, red/white center stripes |

Each directory contains `skinsuit.png` and `helmet.png`. `catalog.json` lists
the paths and sleeve lengths. The Portugal front reference determines physical
sleeve assignment; the supplied back mockup swaps those colors.

Country colors, bands, lettering, flags, stars and fern motifs follow the
supplied designs. Heraldic marks are simplified original silhouettes for the
small game model; small commercial sponsor marks are omitted. Socks, shoes,
gloves and geometry are unchanged. Helmets use the existing shell geometry,
with no fake vent holes painted into the albedo.

## Configure one rider

Add selected keys to your own `game/riders_config.cfg`:

```ini
[player]
skinsuit_png="res://assets/riders/national_kits/netherlands/skinsuit.png"
helmet_png="res://assets/riders/national_kits/netherlands/helmet.png"
visor="donker"

[rider_03]
skinsuit_png="res://assets/riders/national_kits/portugal/skinsuit.png"
helmet_png="res://assets/riders/national_kits/portugal/helmet.png"
visor="doorzichtig"
```

`riders_national_kits.example.cfg` contains all ten optional examples. Existing
`riders_config.example.cfg` and personal settings are not modified. These PNGs
also work with the previously added `country_kit` presets.

## Short sleeves

Atlas alpha means cloth coverage, not transparency of the body. The
`skinsuit_coverage.gdshader` blends uncovered texels with the existing imported
skin color and keeps the mesh opaque. It works on both rigs with every
animation and morph, without painting fixed human skin tones into the PNG.
Opaque long-sleeve PNGs keep the StandardMaterial3D path. Default riders and
the existing Belgium texture are unaffected.

## Rebuild

Editable SVGs live in `assets/source_blender/national_kits/`. They use exact
UV-v1 rectangles, seam continuation and eight-pixel filter gutters, with no
photographed lighting or clothing silhouettes. `make_national_kits.py`
regenerates them, the catalog and example config. `render_national_kits.cjs`
rasterizes them to the final 1024x1024 PNGs.

From the repository root, with Python 3, Node.js, sharp and an Arial-compatible
font available (tested sharp 0.35.5 / Arial on Windows):

```powershell
python game/assets/source_blender/make_national_kits.py
# Install sharp in your development environment if necessary: npm install sharp@0.35.5
node game/assets/source_blender/render_national_kits.cjs
godot --headless --path game --editor --import --quit
godot --headless --path game --script res://tests/test_country_skins.gd
godot --headless --path game --script res://tests/test_national_kit_assets.gd
python game/tests/check_national_kit_pngs.py  # requires Pillow
```

For actual GPU captures, omit `--headless`:

```powershell
$env:NATIONAL_KIT_CAPTURES = Join-Path (Get-Location) "national_kit_captures"
godot --path game --rendering-method gl_compatibility --script res://tests/capture_national_kits.gd
```

This captures 40 views: ten countries, both rigs, front/back. A separate
Blender script is at `assets/source_blender/preview_national_kits.py`.
No Blender rebuild or GLB replacement is needed for these assets.

## Validation, 2026-10-26

- Godot 4.7.2 imports: PASS.
- Existing config/helmet/visor regression: PASS, zero failures.
- Ten-country test: PASS, zero failures across 10 countries x 2 rigs x 4 poses,
  six morphs, coverage, fallbacks and neighboring-rider isolation.
- PNG checks: PASS for all 20 images, opacity, sleeve lengths, Portugal colors
  and seam padding at collapsed pelvic UVs.
- Actual Godot GPU capture: PASS, 40 views inspected; OpenGL 3.3 Compatibility
  on Intel Iris Xe. No script, shader or render errors. The environment still
  logs its pre-existing certificate-store startup error.
- Blender 5.2.2: 40 studio previews completed during iteration; the final
  corrected atlas edges were verified in Godot GPU captures.
- Original GLBs, editable rigs, animations, shape keys, palettes and Belgium
  assets are unchanged. Full game/hardware integration was not rerun; these
  checks use the isolated rider scene.
