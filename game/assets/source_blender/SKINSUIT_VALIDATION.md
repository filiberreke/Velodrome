# Skinsuit / helmet / visor validation

Base: `94095e91f00d7297fccd38b210dd22e1433483ed` on main.
Rider sources were inspected at `845f132caa3d432941d94367ccd3557b1c306aff`.
The later upstream commit changes unrelated simulation/import files and removes
one trailing blank line from main.gd; those upstream changes are preserved.
Validated 2026-10-26 with Blender 5.2.2 LTS and Godot 4.7.2 stable, Windows.

- PASS: both generators run headlessly with --python-exit-code 1 (exit 0).
- PASS: Godot imports both rebuilt GLBs and the sample atlas (exit 0).
- PASS: test_country_skins.gd, 0 failures, exit 0. Both rigs, all four clips,
  six morphs, UV range/availability, per-instance material isolation with the
  same profile index, suit and helmet PNG selection/fallback, relative/imported/
  user/absolute PNG paths, independent resets, visor donker/doorzichtig, invalid
  values, and config metadata initialization.
- PASS: check_skinsuit_exports.py compares against separately rebuilt unmodified
  generators. Node transforms, skins/bind matrices and animation samples match
  exactly; positions, weights and six morph deltas match at 1e-6, default
  material colors unchanged. UV vertex splits and exporter tessellation/normal
  variation on unchanged helmet/bike polygons are allowed.
- PASS: Python compilation of both generators, shared UV module, texture
  generator and export comparison.
- PASS: actual Blender front/back renders of the Belgium kit inspected on both
  models. Light-blue shirt, horizontal black/yellow/red band and black shorts;
  corrected a seam color leak before final builds.
- Godot emits the environment warning/error "Failed to read the root certificate
  store" at startup. No script/parse/assertion errors in the rider tests. Missing
  PNG/invalid visor test cases deliberately emit fallback warnings.
- Full game integration/smoke run was not completed. Automatic approval review
  rejected restoring unrelated environment-details and trainer-control scripts
  into the local test snapshot. Those scripts are not included in this change;
  the isolated rider project was used instead. Main config wiring was inspected.
- No personal riders_config.cfg is in the commit manifest; game/.gitignore
  already ignores riders_config.cfg and strava_config.cfg.

## Exact changed files

- `game/rider_visual.gd`
- `game/main.gd`
- `game/riders_config.example.cfg`
- `game/assets/source_blender/build_rider.py`
- `game/assets/source_blender/build_pursuit_rider.py`
- `game/assets/source_blender/skinsuit_uv.py`
- `game/assets/source_blender/make_skinsuit_texture.py`
- `game/assets/source_blender/skinsuit_uv_template.svg`
- `game/assets/source_blender/helmet_uv_template.svg`
- `game/assets/source_blender/README.md`
- `game/assets/source_blender/SKINSUIT.md`
- `game/assets/riders/national_kits/belgium/skinsuit.png`
- `game/assets/riders/velodrome_rider.glb`
- `game/assets/riders/velodrome_pursuit.glb`
- `game/assets/source_blender/velodrome_rider_rig.blend`
- `game/assets/source_blender/velodrome_pursuit_rig.blend`
- `game/tests/test_country_skins.gd`
- `game/tests/check_skinsuit_exports.py`
- `game/assets/source_blender/SKINSUIT_VALIDATION.md`
