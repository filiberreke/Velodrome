# Arena roof and Infinity Screen — phase 1

Integrated into `arena.gd`; procedural Godot geometry needs no Blender source.
The existing canopy, stands, crowd density, track, infield, commentary suite,
race rules, light energies and wave implementation are retained.

## Geometry and placement

The actual track API is `main._at(distance, offset)`, with counter-clockwise
traversal, radius 18 m and straights `(250 - 2π × 18) / 2` = 68.45 m.
Its long axis is Z. The finish is distance 0 on the right-hand straight;
the commentary suite remains at offset 27.83 on tier 2.
The canopy crown remains at Y = 27.5 m; its rim follows existing stand heights.

The screen follows a compact capsule derived from `_at(s, -7)` with X scaled
by 7/11 and Z by 0.39: **14 m wide × 35.28 m long**, centred at X/Z = 0.
Following review, its **lower edge is at Y = 13 m**, upper edge at 15.6 m,
and cabinet thickness is 0.6 m. It covers only the central portion of the infield.
The original larger design was replaced before delivery.

`arena_roof.gd` supplies 24 Warren trusses, compression rings, longitudinal
ties, diagonal bracing, gussets, a service ring and two access bridges.
Hangers connect that service ring to nearby actual radial truss chords.
Twelve paired cable hoists connect the screen to the service ring at Y = 24 m.
No supports enter the track, seating or infield.

`arena_floodlights.gd` supplies 24 clusters with three or four fixtures each,
eight LED cells per fixture, cooling fins, reflectors and mounting brackets.
All original effective arena lights are retained: four OmniLights and eight
SpotLights, with their existing settings. The new components add **zero lights**.

`arena_steel.gd` batches static geometry by material in shared unit-box
MultiMeshes. The three additions use 16 draw calls in the measured view,
including the two continuous screen meshes; new geometry casts no shadows.

## Display content

`arena.get_node("InfinityScreen").set_content(texture)` updates both faces.
Pass any Texture2D, including a future SubViewportTexture. Race data is not
coupled to the display. Phase 1 has no animated content or timing information.

The exact existing `assets/boarding/velodrome-boarding.png` is reused; the
light variant was also inspected and used in the content-switch test. No new
logo, text nodes or font dependencies were introduced. UV.x measures physical
arc length separately for each face; inner-face traversal is reversed. Each
closed strip fits an integer number of artwork repeats. The shader contains
the artwork at its original aspect ratio, adding narrow navy gaps as needed.
Unshaded output and restrained edge emission keep content clear without adding
environment lighting. Cabinet joints and underside vents remain visible nearby.

## Intro

The checked-in intro actually lasts **44 seconds**, rather than the six seconds
mentioned in the initial brief. Its duration, flight positions, commentary
dialogue, tent corridor, discipline-specific finish approach and skip controls
are preserved. Only the look target briefly blends inward between 12–19 s,
revealing the roof and ring during the existing north-bend passage.

## Verification

Godot 4.7.2, Compatibility renderer. Real GPU captures at 1600 × 1000, 4× MSAA,
are in `verification/arena_roof/`; run `tests/capture_arena_roof.gd` to reproduce.
Views include the cabin passage, intro reveal, start, track, stands, underside,
full roof and screen detail. The final compact screen and readable inner/outer
artwork were visually inspected. The cabin remains unobstructed.

`tests/test_arena_roof.gd` checks integrated components, requested height,
scale, closed geometry and UV repeat, original branding, two-sided content
replacement, absence of new lights, LED segments, intro framing, sampled
camera clearance and skip handoff. `tests/arena_roof_test_game.gd` binds an
ephemeral UDP port so checks can run beside an already running game.
Existing regression assertions were executed with only their main-game preload
redirected to this network-isolated subclass; production network code is unchanged.
See `verification/arena_roof/test_results*.json` and `VALIDATION.md` for results.

The paired GPU check (`tests/benchmark_arena_roof.gd`) toggles only the three new
components in the same stadium view. Across two pairs: components hidden
39.53/39.84 ms per frame, visible 40.64/40.83 ms; draw calls 1782 → 1798 and
primitives 1,069,126 → 1,165,566. This is about 1.05 ms / 2.7% added frame time
in this local run, not a full historical-build or long-race performance guarantee.

The Windows runner reports a root-certificate-store error; the first clean
asset import also reports existing GLB tangent-generation warnings. Neither
originates in these procedural components. Physical trainer hardware, prolonged
manual play at all graphics settings and a tifo deployment were not verified.
The current baseline's stadium-show script has flags/wave but no active tifo
construction; those files and assets are left unchanged.
