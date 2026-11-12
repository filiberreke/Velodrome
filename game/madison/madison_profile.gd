class_name MadisonProfile
extends RefCounted
## Shared Madison contract (mirrors build_madison.py / madison_profile.json).
## The SAME efficiency curve drives the HUD slider width and the pose strength of the sling clips:
## efficiency(0.6) == 1.0 is both the maximum slider width and the visual peak of the animation.

const PROFILE_PATH := "res://madison/madison_profile.json"
const PEAK_T := 0.6
const E_END := 0.35
const REF_GAP := 1.20          # m between the two bike centre lines the clips were authored for
const HAND_ANCHOR := 0.11      # m from wrist along hand bone +Y = clasp point
const REACH_SHORT := 0.10
## upper-body bones the Madison clips may key (Blend2 filter + test whitelist)
const KEYED_BONES: Array[String] = ["spine", "chest", "neck", "head", "clavicle.L", "clavicle.R",
	"upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "hand.L", "hand.R"]
const FORBIDDEN_TRACK_PARTS: Array[String] = ["root", "bike", "bars", "crank", "pedal", "wheel"]
const GLB_PATH := "res://assets/riders/madison/madison_anims.glb"
const LIBRARY_NAME := "madison"
const MIN_SLIDER_WIDTH := 0.12  # fraction of the bar (HUD debug bar)
const MAX_SLIDER_WIDTH := 1.0

static func _smoother(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

static func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

## 0..1, exactly 1.0 at sling_t == PEAK_T, controlled fall-off to E_END at 1.0.
static func efficiency(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t <= PEAK_T:
		return _smoother(t / PEAK_T)
	return 1.0 - (1.0 - E_END) * _smooth((t - PEAK_T) / (1.0 - PEAK_T))

## HUD slider width (fraction of the bar). Same variable as the animation intensity.
static func slider_width(t: float) -> float:
	return lerpf(MIN_SLIDER_WIDTH, MAX_SLIDER_WIDTH, efficiency(t))

## RELEASE crossfade (sling pose -> release start pose) in seconds. The further the sling pose is from the hold pose
## (i.e. the closer to the peak), the longer it takes, so arm speed stays natural from every sling_t.
static func release_crossfade_seconds(t: float) -> float:
	return 0.20 + 0.20 * efficiency(t)

## nominal forward offset of the receiver w.r.t. the giver (m)
static func delta_f(t: float) -> float:
	var dip := -0.08 * sin(PI * t / 0.3) if t < 0.3 else 0.0
	return 0.32 * efficiency(t) + dip

## rider space (x left, f forward, z up) -> Godot (x, y up, z forward)
static func to_godot(v: Array) -> Vector3:
	return Vector3(v[0], v[2], v[1])

static func contact_giver(t: float) -> Vector3:
	var e := efficiency(t)
	return Vector3(-REF_GAP / 2.0, 1.12 - 0.06 * e, 0.25 + 0.10 * e)   # Godot axes

static func contact_receiver(t: float) -> Vector3:
	var c := contact_giver(t)
	return Vector3(REF_GAP / 2.0, c.y, c.z - delta_f(t))

static func load_profile() -> Dictionary:
	var f := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

## clip names per role: "madison_giver_sling" ...
static func clip_name(role: String, kind: String) -> StringName:
	return StringName("madison_%s_%s" % [role, kind])

static func grab_side(role: String) -> String:
	return "R" if role == "giver" else "L"

## Loads madison_anims.glb and returns its AnimationLibrary (animations non-looping, pose strips).
static func load_library() -> AnimationLibrary:
	var scene := load(GLB_PATH) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate()
	var player := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var lib := AnimationLibrary.new()
	if player != null:
		for n in player.get_animation_list():
			var a := player.get_animation(n).duplicate() as Animation
			a.loop_mode = Animation.LOOP_NONE
			lib.add_animation(n, a)
	inst.free()
	return lib
