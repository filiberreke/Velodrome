"""
Velodrome shoulder-push clips ("schouderduwtje"), Blender 4.2+ / 5.x headless:

    blender -b -P build_shoulder_push.py

Re-uses the rig code of ../build_rider.py (executed, not modified; via ../madison/madison_common.py).
Both the original rider and the female rider share this skeleton, so ONE clip set serves both models.

Clips are ADDITIVE upper-body layers: every key is the bone's rotation delta from the neutral riding pose
(rest pose == "no push"). Godot (game/contact/shoulder_push_layer.gd) multiplies the delta on top of whatever
the rider is doing (cruise, seated sprint, standing sprint) and keeps both hands on the bars with IK.

    push_give_L   push a rider on your LEFT         push_take_L   get pushed by a rider on your LEFT
    push_give_R   push a rider on your RIGHT        push_take_R   get pushed by a rider on your RIGHT

All clips: 2.0 s at 30 fps (61 keys), keyed bones = spine, chest, neck, head, clavicle.*, upper_arm.*, forearm.*,
hand.* (rotation only). Timeline (seconds, see TIMING): the push goes out fast, the furthest point is HELD,
then it returns. Godot can lengthen or shorten only the hold, so the movement itself never slows down.

Outputs
    game/assets/riders/contact/shoulder_push_anims.glb   clips on the shared skeleton (tiny proxy mesh)
    game/contact/shoulder_push_profile.json              timing + measurements (contract with Godot)
Optional preview renders (front view, two riders side by side):
    SHOULDER_PUSH_PREVIEW=<dir> [RIDER_VARIANT=female] blender -b -P build_shoulder_push.py
    (preview runs never export)
"""
import os, sys, math, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "madison"))
import bpy
from mathutils import Vector, Quaternion
import madison_common as MC

REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
TMP = os.environ.get("SHOULDER_PUSH_TMP", os.path.join(HERE, "out"))
GLB_OUT = os.environ.get("SHOULDER_PUSH_GLB", os.path.join(REPO, "game", "assets", "riders", "contact", "shoulder_push_anims.glb"))
PROFILE_OUT = os.environ.get("SHOULDER_PUSH_PROFILE", os.path.join(REPO, "game", "contact", "shoulder_push_profile.json"))
PREVIEW = os.environ.get("SHOULDER_PUSH_PREVIEW", "")

ns = MC.load_rider_rig(os.path.join(TMP, "_rider"))
rig, pb, arm, J, D, scene = ns["rig"], ns["pb"], ns["arm_data"], ns["J"], ns["D"], ns["scene"]
evaluated_pose, q_world, loc_world, CTRL = ns["evaluated_pose"], ns["q_world"], ns["loc_world"], ns["CTRL"]
apply_controls = ns["apply_controls"]
WFWD, WZ = D(0, 1, 0), Vector((0, 0, 1))

FPS = 30
DURATION = 2.0
FRAMES = int(round(DURATION * FPS))
KEYED = ["spine", "chest", "neck", "head", "clavicle.L", "clavicle.R", "upper_arm.L", "upper_arm.R",
         "forearm.L", "forearm.R", "hand.L", "hand.R"]
# seconds. give: out -> furthest point reached at OUT_END, held until HOLD_END, back to neutral at DURATION.
# take: the shove arrives at CONTACT (the giver's shoulder meets yours), brace is held, released after the giver.
TIMING = dict(out_end=0.30, contact=0.22, hold_end=1.50, take_hold_end=1.55, end=DURATION)
CLIPS = [f"push_{role}_{side}" for role in ("give", "take") for side in ("L", "R")]

def smoothstep(x):
    x = max(0.0, min(1.0, x)); return x * x * (3 - 2 * x)

def give_curves(t):
    """amplitudes for the pushing rider (lean etc. towards the partner); 1.0 = furthest point of the push"""
    T = TIMING
    if t < T["out_end"]:
        a = smoothstep(t / T["out_end"])
    elif t < T["hold_end"]:
        h = t - T["out_end"]; env = smoothstep(h / 0.25) * smoothstep((T["hold_end"] - t) / 0.25)
        a = 1.0 + 0.10 * env * math.sin(2 * math.pi * 1.5 * h)          # keeps leaning in, in small pulses
    else:
        a = 1.0 - smoothstep((t - T["hold_end"]) / (T["end"] - T["hold_end"]))
    head = smoothstep(t / 0.18) * (1.0 - smoothstep((t - T["hold_end"]) / (T["end"] - T["hold_end"])))
    return dict(swing=14.0 * a, drop=6.0 * a, shrug=9.0 * a, flare=0.14 * a, head_yaw=12.0 * head)

def take_curves(t):
    """amplitudes for the rider being pushed: jolt AWAY at contact, then brace back INTO the pusher and hold"""
    T = TIMING; c = T["contact"]
    if t < c:
        j = 0.0
    elif t < c + 0.12:
        j = math.sin(0.5 * math.pi * (t - c) / 0.12)
    else:
        j = max(0.0, math.cos(0.5 * math.pi * min(1.0, (t - c - 0.12) / 0.33)))
    b = smoothstep((t - c - 0.10) / 0.35)
    if T["contact"] + 0.45 < t < T["take_hold_end"]:
        h = t - c - 0.45; env = smoothstep(h / 0.25) * smoothstep((T["take_hold_end"] - t) / 0.25)
        b *= 1.0 - 0.08 * env * math.sin(2 * math.pi * 1.5 * h)          # gives a little with every pulse
    b *= 1.0 - smoothstep((t - T["take_hold_end"]) / (T["end"] - T["take_hold_end"]))
    swing = 5.0 * b - 9.0 * j                                           # + = upper body towards the pusher
    return dict(swing=swing, drop=3.0 * b, shrug=6.0 * b + 3.0 * j, flare=0.08 * b, head_yaw=14.0 * b, whip=8.0 * j)

# ------------------------------------------------------------------ sign calibration (no guessing about axes)
def reset_ctrl():
    for n in CTRL + ["elbow_pole.L", "elbow_pole.R"]:
        pb[n].location = (0, 0, 0); pb[n].rotation_quaternion = (1, 0, 0, 0)

def _probe(fn, measure):
    reset_ctrl(); a = measure(evaluated_pose()); fn(); b = measure(evaluated_pose()); reset_ctrl(); return b - a

# The torso of a rider is nearly horizontal, so moving the shoulders SIDEWAYS is a swing about the vertical
# axis (pivot near the saddle); a roll about the forward axis only twists the torso (dips one shoulder).
SWING = 1.0 if _probe(lambda: setattr(pb["spine"], "rotation_quaternion", q_world("spine", WZ, 0.2)),
                      lambda P: P["neck"].tail.x) > 0 else -1.0           # +SWING*angle moves the chest to the left
YAW = SWING                                                             # same axis: used to aim the head
DROP = {s: (1.0 if _probe(lambda: setattr(pb["chest"], "rotation_quaternion", q_world("chest", WFWD, 0.2)),
                          lambda P: -P[f"upper_arm.{s}"].head.z) > 0 else -1.0) for s in ("L", "R")}
CLAV = {}
for s in ("L", "R"):
    CLAV[s] = 1.0 if _probe(lambda: setattr(pb[f"clavicle.{s}"], "rotation_quaternion", q_world(f"clavicle.{s}", WFWD, 0.2)),
                            lambda P: P[f"upper_arm.{s}"].head.z) > 0 else -1.0
print(f"axis signs: swing {SWING:+.0f}, drop L {DROP['L']:+.0f} R {DROP['R']:+.0f}, clavicle L {CLAV['L']:+.0f} R {CLAV['R']:+.0f}")

def rot(n, axis, deg):
    return q_world(n, axis, math.radians(deg))

def apply_push(role, side, t):
    """add the push on top of the current control pose. side = where the OTHER rider is (L = rider's left)."""
    sx = 1.0 if side == "L" else -1.0
    c = give_curves(t) if role == "give" else take_curves(t)
    near = side
    swing, drop = c["swing"] * sx * SWING, c["drop"] * DROP[near]
    for n, k in (("spine", 0.5), ("chest", 0.5)):
        pb[n].rotation_quaternion = rot(n, WZ, swing * k) @ rot(n, WFWD, drop * k) @ pb[n].rotation_quaternion
    # head: cancels the swing (keeps looking ahead), then turns towards the other rider; when shoved it lags (whip)
    whip = c.get("whip", 0.0) * sx * SWING
    pb["neck"].rotation_quaternion = rot("neck", WZ, -swing * 0.5 + whip * 0.4) @ rot("neck", WFWD, -drop * 0.5) @ \
        pb["neck"].rotation_quaternion
    pb["head"].rotation_quaternion = rot("head", WZ, -swing * 0.5 + c["head_yaw"] * sx * YAW + whip * 0.6) @ \
        rot("head", WFWD, -drop * 0.5) @ pb["head"].rotation_quaternion
    pb[f"clavicle.{near}"].rotation_quaternion = rot(f"clavicle.{near}", WFWD, c["shrug"] * CLAV[near]) @ \
        rot(f"clavicle.{near}", WZ, -0.4 * c["shrug"] * sx * YAW) @ pb[f"clavicle.{near}"].rotation_quaternion
    # elbow on the contact side goes out and slightly up (pole target moves; hands stay on the bars via IK)
    pb[f"elbow_pole.{near}"].location = loc_world(f"elbow_pole.{near}", D(sx * c["flare"], 0, 0.4 * c["flare"]))

def basis_of(n, mats):
    b = arm.bones[n]
    if b.parent:
        local = b.parent.matrix_local.inverted() @ b.matrix_local
        basis = (mats[b.parent.name] @ local).inverted() @ mats[n]
    else:
        basis = b.matrix_local.inverted() @ mats[n]
    return basis.decompose()

DEFORM = [b.name for b in arm.bones if b.use_deform]

def sample(role, side, t, base=None):
    if base is None:
        reset_ctrl()
    else:
        apply_controls(base, 0)
        for s in ("L", "R"):
            pb[f"elbow_pole.{s}"].location = (0, 0, 0)
    apply_push(role, side, t)
    return evaluated_pose()

# ------------------------------------------------------------------ preview renders (no export)
if PREVIEW:
    import importlib.util
    os.makedirs(PREVIEW, exist_ok=True)
    sc = scene; sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 24
    sc.render.film_transparent = True; sc.render.resolution_x, sc.render.resolution_y = 520, 520
    w = bpy.data.worlds.new("w"); sc.world = w
    w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (0.93, 0.94, 0.96, 1)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN')); sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(-15), math.radians(200)); sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = 2.0
    cam.location = (0, -4.0, 1.05); cam.rotation_euler = (math.radians(90), 0, 0)      # in front, looking back at the rider
    for o in bpy.data.objects:
        if o.name == "Hair_ponytail": o.hide_render = False
        elif o.name.startswith("Hair_"): o.hide_render = True
    jobs = [(role, side, t) for (role, side) in (("give", "L"), ("take", "R")) for t in (0.0, 0.22, 0.5, 1.2, 1.75)]
    for role, side, t in jobs:
        sample(role, side, t, base="cruise")
        sc.render.filepath = os.path.join(PREVIEW, f"{role}_{side}_{int(t*100):03d}.png")
        bpy.ops.render.render(write_still=True)
    print("PREVIEW done", PREVIEW)
    sys.exit(0)

# ------------------------------------------------------------------ bake deltas
neutral = sample("give", "L", 0.0)
q_neutral = {n: basis_of(n, {m: neutral[m].matrix.copy() for m in DEFORM})[1] for n in KEYED}
baked, stats = {}, {}
for clip in CLIPS:
    _, role, side = clip.split("_")
    frames, prev, st = [], {}, []
    for fr in range(FRAMES + 1):
        t = fr / FPS
        P = sample(role, side, t)
        mats = {n: P[n].matrix.copy() for n in DEFORM}
        qf = {}
        for n in KEYED:
            loc, q, _ = basis_of(n, mats)
            d = q_neutral[n].inverted() @ q
            if n in prev and d.dot(prev[n]) < 0: d.negate()
            prev[n] = d; qf[n] = d.copy()
        frames.append(qf)
        # measurements in rider space (x left, f forward, z up)
        sh = P[f"upper_arm.{side}"].head; wr = P[f"forearm.{side}"].tail
        tgt = P[f"hand_tgt.{side}"].head
        st.append(dict(t=t, shoulder_x=abs(sh.x), shoulder_z=sh.z, ik=(wr - tgt).length,
                       chest_roll=math.degrees((q_neutral["chest"].inverted() @ basis_of("chest", mats)[1]).angle)))
    baked[clip] = frames; stats[clip] = st
    worst_ik = max(s["ik"] for s in st)
    print(f"{clip}: {len(frames)} keys, hands on bars (IK miss) max {worst_ik*1000:.2f} mm, "
          f"contact shoulder x {min(s['shoulder_x'] for s in st):.3f}..{max(s['shoulder_x'] for s in st):.3f} m")
rest_shoulder = abs(J["sh.L"].x)

# ------------------------------------------------------------------ strip to the game rig, key deltas, export
reset_ctrl()
for p in pb:
    for c in list(p.constraints): p.constraints.remove(c)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for b in list(arm.edit_bones):
    if not b.use_deform: arm.edit_bones.remove(b)
bpy.ops.object.mode_set(mode='OBJECT')
for p in pb:
    p.location = (0, 0, 0); p.rotation_quaternion = (1, 0, 0, 0); p.scale = (1, 1, 1)
for o in list(scene.objects):
    if o.type == 'MESH': bpy.data.objects.remove(o)

rig.animation_data_create()
ACTIONS = {}
for name, frames in baked.items():
    act = bpy.data.actions.new(name); act.use_fake_user = True
    rig.animation_data.action = act
    for fr, qf in enumerate(frames):
        for n in KEYED:
            pb[n].rotation_quaternion = qf[n]
            pb[n].keyframe_insert("rotation_quaternion", frame=fr)
    ACTIONS[name] = act
for p in pb: p.rotation_quaternion = (1, 0, 0, 0)

verts, faces, groups = [], [], {}
for b in arm.bones:
    o = len(verts); h = b.head_local
    verts += [h, h + Vector((0.001, 0, 0)), h + Vector((0, 0.001, 0))]
    faces.append((o, o + 1, o + 2)); groups[b.name] = (o, o + 1, o + 2)
me = bpy.data.meshes.new("ContactProxy"); me.from_pydata([tuple(v) for v in verts], [], faces)
px = bpy.data.objects.new("ContactProxy", me); scene.collection.objects.link(px)
for bn, idx in groups.items():
    g = px.vertex_groups.new(name=bn); g.add(list(idx), 1.0, 'REPLACE')
px.parent = rig
md = px.modifiers.new("Armature", 'ARMATURE'); md.object = rig
ad = rig.animation_data; ad.action = None
for name, act in ACTIONS.items():
    tr = ad.nla_tracks.new(); tr.name = name
    st_ = tr.strips.new(name, 0, act)
    try:
        if st_.action_slot is None and len(act.slots): st_.action_slot = act.slots[0]
    except AttributeError:
        pass
for p in (GLB_OUT, PROFILE_OUT):
    os.makedirs(os.path.dirname(p), exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=GLB_OUT, export_format='GLB', export_animations=True,
                          export_animation_mode='ACTIONS', export_force_sampling=True, export_yup=True, export_apply=False)
n_removed = MC.filter_glb_channels(GLB_OUT, set(KEYED))
print("exported", GLB_OUT, f"(removed {n_removed} static channels)")

peak = lambda clip, key, fn: fn(s[key] for s in stats[clip])
profile = dict(
    version=1, fps=FPS, duration=DURATION, frames=FRAMES, timing=TIMING, clips=CLIPS, keyed_bones=KEYED,
    additive="key = rotation delta from the neutral riding pose (identity = no push)",
    side="L/R = where the OTHER rider is, seen from this rider",
    measured=dict(
        rest_shoulder_x=rest_shoulder,
        give_shoulder_x_peak=peak("push_give_L", "shoulder_x", max),
        take_shoulder_x_min=peak("push_take_R", "shoulder_x", min),
        max_hand_ik_miss_mm=max(max(s["ik"] for s in st) for st in stats.values()) * 1000,
        give_chest_rotation_peak_deg=peak("push_give_L", "chest_roll", max),
        take_chest_rotation_peak_deg=peak("push_take_L", "chest_roll", max),
    ),
)
json.dump(profile, open(PROFILE_OUT, "w"), indent=1)
print("profile", PROFILE_OUT, json.dumps(profile["measured"]))
