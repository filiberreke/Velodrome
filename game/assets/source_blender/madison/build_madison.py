"""
Velodrome Madison hand-sling clips (Blender 4.2+ / 5.x, headless):

    blender -b -P build_madison.py

Re-uses the rig code of ../build_rider.py (executed, NOT modified - see madison_common.load_rider_rig),
adds a shared `HandContact` empty and drives the grab-hand IK target through a Child Of constraint
(influence curve: bars -> HandContact), bakes the result to plain FK and exports

    game/assets/riders/madison/madison_anims.glb      (same skeleton / bone names as velodrome_rider.glb)
    game/assets/source_blender/madison/madison_rig.blend   (baked FK rig + madison actions, with meshes)
    game/madison/madison_profile.json                 (contract shared with Godot: curves, contact, anchors)
    docs/madison/measurements/sling_contact_log.csv   (hand-to-HandContact distances, measured on the BAKED clips)

Clips (keyed bones: spine, chest, neck, head, clavicle.*, upper_arm.*, forearm.*, hand.*; rotation only;
never root / bike / bars / crank / pedal.* / wheel_* / pelvis / legs):
    madison_giver_approach, madison_receiver_approach   looked up with approach_t 0..1   (31 frames @30 fps)
    madison_giver_release,  madison_receiver_release    looked up with release_t  0..1   (31 frames; starts at the sling_t=0 hold pose)
    madison_giver_sling,    madison_receiver_sling      looked up with sling_t     0..1  (61 frames @30 fps)
Rider-space convention used everywhere: x = rider's left, f = forward, z = up (Godot: Vector3(x, z, f)).
"""
import os, sys, math, json, csv
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix, Quaternion
import madison_common as MC
from madison_common import REF_GAP, HAND_ANCHOR, PEAK_T, E_END, efficiency

HERE = MC.HERE
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
TMP = os.environ.get("MADISON_TMP", os.path.join(HERE, "out"))
GLB_OUT = os.environ.get("MADISON_GLB", os.path.join(REPO, "game", "assets", "riders", "madison", "madison_anims.glb"))
BLEND_OUT = os.environ.get("MADISON_BLEND", os.path.join(HERE, "madison_rig.blend"))
PROFILE_OUT = os.environ.get("MADISON_PROFILE", os.path.join(REPO, "game", "madison", "madison_profile.json"))
LOG_OUT = os.environ.get("MADISON_LOG", os.path.join(REPO, "docs", "madison", "measurements", "sling_contact_log.csv"))
for p in (GLB_OUT, BLEND_OUT, PROFILE_OUT, LOG_OUT, os.path.join(TMP, "x")):
    os.makedirs(os.path.dirname(p), exist_ok=True)

ns = MC.load_rider_rig(os.path.join(TMP, "_rider"))
rig, pb, arm, J, D, scene = ns["rig"], ns["pb"], ns["arm_data"], ns["J"], ns["D"], ns["scene"]
evaluated_pose, q_world, rest_rot = ns["evaluated_pose"], ns["q_world"], ns["rest_rot"]
UARM, FARM, CTRL = ns["UARM"], ns["FARM"], ns["CTRL"]
WX, WFWD, WZ = Vector((1, 0, 0)), D(0, 1, 0), Vector((0, 0, 1))
FPS = 30
APPROACH_FRAMES, SLING_FRAMES, RELEASE_FRAMES = 30, 60, 30
KEYED = ["spine", "chest", "neck", "head", "clavicle.L", "clavicle.R", "upper_arm.L", "upper_arm.R",
         "forearm.L", "forearm.R", "hand.L", "hand.R"]
ROLES = {"giver": dict(side="R", sx=-1), "receiver": dict(side="L", sx=+1)}
REACH_SHORT = 0.10          # at the end of APPROACH the clasp points are 0.10 m short of the contact point
HD_GIVER = Vector((-0.94, 0.30, -0.15)).normalized()   # rider-space hand axis wrist->anchor, giver right hand
HD = {"giver": HD_GIVER, "receiver": -HD_GIVER}          # the two hands point at each other (anti-parallel)

# ------------------------------------------------------------------ profile (rider space: x left, f fwd, z up)
def smoothstep(x):
    x = max(0.0, min(1.0, x)); return x * x * (3 - 2 * x)

def delta_f(t):
    """nominal forward offset of the receiver w.r.t. the giver (m): small lag while loading, then flung ahead."""
    dip = -0.08 * math.sin(math.pi * t / 0.3) if t < 0.3 else 0.0
    return 0.32 * efficiency(t) + dip

def contact_giver(t):
    e = efficiency(t)
    return Vector((-REF_GAP / 2, 0.25 + 0.10 * e, 1.12 - 0.06 * e))

def contact_receiver(t):
    c = contact_giver(t)
    return Vector((REF_GAP / 2, c.y - delta_f(t), c.z))

def contact(role, t):
    return contact_giver(t) if role == "giver" else contact_receiver(t)

def B(v):  # rider-space (x, f, z) -> Blender
    return D(v[0], v[1], v[2])

# ------------------------------------------------------------------ control rig additions: HandContact + Child Of
hc = bpy.data.objects.new("HandContact", None); hc.empty_display_type = 'SPHERE'; hc.empty_display_size = 0.04
scene.collection.objects.link(hc)
wrist_tgt = {}
for role, cfg in ROLES.items():
    e = bpy.data.objects.new(f"HC_wrist_{role}", None); e.empty_display_type = 'ARROWS'; e.empty_display_size = 0.05
    scene.collection.objects.link(e); e.parent = hc
    wrist_tgt[role] = e
child_of = {}
for role, cfg in ROLES.items():
    n = f"hand_tgt.{cfg['side']}"
    c = pb[n].constraints.new('CHILD_OF'); c.name = "Madison_HandContact"
    c.target = wrist_tgt[role]
    c.inverse_matrix = arm.bones[n].matrix_local.inverted()   # empty frame == rest wrist frame -> bone sits on the empty
    c.influence = 0.0
    child_of[role] = c

def reset_ctrl():
    for n in CTRL:
        pb[n].location = (0, 0, 0); pb[n].rotation_quaternion = (1, 0, 0, 0)

def hand_rot_delta(role):
    """world rotation that takes the rest hand (fingers forward, thumb inward) to: fingers along HD, thumb up."""
    side = ROLES[role]["side"]; x = 1 if side == "L" else -1
    bn = arm.bones[f"hand_tgt.{side}"]
    a0 = (bn.tail_local - bn.head_local).normalized(); t0 = D(-x, 0, 0.33)
    a1 = B(HD[role]).normalized(); t1 = Vector((0, 0, 1))
    def frame(a, t):
        e1 = a.normalized(); e2 = (t - e1 * e1.dot(t)).normalized(); e3 = e1.cross(e2)
        return Matrix((e1, e2, e3)).transposed()
    return (frame(a1, t1) @ frame(a0, t0).inverted()).to_quaternion()

def torso_params(role, u, e):
    """yaw / roll (lean to partner) / pitch (drive) in degrees, from approach amount u and efficiency e."""
    if role == "giver":
        return u * 14 * (1 - 0.45 * e), u * 5 * (1 - 0.5 * e), u * (3 + 5 * e)
    return u * 14 * (1 - 0.30 * e), u * 4 * (1 - 0.5 * e), u * (4 + 7 * e)

def pose_frame(role, kind, x):
    """Set the control rig for one frame. kind: 'approach' (x = approach_t) or 'sling' (x = sling_t)."""
    cfg = ROLES[role]; side, sx = cfg["side"], cfg["sx"]
    reset_ctrl()
    if kind == "approach":
        w = smoothstep(x); u = w; t = 0.0; e = 0.0; short = REACH_SHORT; lift = 0.08 * math.sin(math.pi * x)
    elif kind == "release":     # grab/hold pose (= sling_t 0) -> hands open and retract -> back to the bike posture
        sm = smoothstep(x); w = 1.0 - sm; u = 1.0 - sm; t = 0.0; e = 0.0; short = 0.18 * sm; lift = 0.04 * math.sin(math.pi * x)
    else:
        w = 1.0; u = 1.0; t = x; e = efficiency(x); short = 0.0; lift = 0.0
    yaw, roll, pitch = torso_params(role, u, e)
    yaw *= sx; roll *= -sx
    for n, k in (("spine", 0.4), ("chest", 0.6)):
        pb[n].rotation_quaternion = (q_world(n, WZ, math.radians(yaw * k)) @ q_world(n, WFWD, math.radians(roll * k)) @
                                     q_world(n, WX, math.radians(pitch * k)))
    pb["neck"].rotation_quaternion = q_world("neck", WZ, math.radians(-0.4 * yaw))
    pb["head"].rotation_quaternion = q_world("head", WZ, math.radians(-0.5 * yaw))
    # shared contact point + this hand's wrist frame (child of HandContact)
    C = contact(role, t)
    hc.location = B(C) + Vector((0, 0, lift))
    bpy.context.view_layer.update()      # parent matrix must be current before the child's matrix_world is set
    hd = B(HD[role]).normalized()
    Rd = Quaternion().slerp(hand_rot_delta(role), w) if w < 1.0 else hand_rot_delta(role)
    Mrest = arm.bones[f"hand_tgt.{side}"].matrix_local
    m = Rd.to_matrix() @ Mrest.to_3x3()
    wm = m.to_4x4(); wm.translation = hc.location - hd * (HAND_ANCHOR + short)
    wrist_tgt[role].matrix_world = wm
    child_of[role].influence = w
    bpy.context.view_layer.update()
    return C

def basis_of(n, mats):
    b = arm.bones[n]
    if b.parent:
        local = b.parent.matrix_local.inverted() @ b.matrix_local
        basis = (mats[b.parent.name] @ local).inverted() @ mats[n]
    else:
        basis = b.matrix_local.inverted() @ mats[n]
    return basis.decompose()

DEFORM = [b.name for b in arm.bones if b.use_deform]
baked = {}      # clip name -> list of {bone: quaternion}
stats = {}      # clip name -> per-frame dict(ik_err, stretch, elbow)
worst_loc = 0.0
for role in ROLES:
    side = ROLES[role]["side"]
    for kind, nfr in (("approach", APPROACH_FRAMES), ("sling", SLING_FRAMES), ("release", RELEASE_FRAMES)):
        name = f"madison_{role}_{kind}"
        frames, st, prevq = [], [], {}
        for fr in range(nfr + 1):
            pose_frame(role, kind, fr / nfr)
            P = evaluated_pose()
            mats = {n: P[n].matrix.copy() for n in DEFORM}
            q_frame = {}
            for n in KEYED:
                loc, q, _ = basis_of(n, mats)
                worst_loc = max(worst_loc, loc.length)
                if n in prevq and q.dot(prevq[n]) < 0: q.negate()
                prevq[n] = q; q_frame[n] = q.copy()
            frames.append(q_frame)
            sh, elb, wr = P[f"upper_arm.{side}"].head, P[f"upper_arm.{side}"].tail, P[f"forearm.{side}"].tail
            tgt = P[f"hand_tgt.{side}"].head
            ang = math.degrees(math.acos(max(-1, min(1, (sh - elb).normalized().dot((wr - elb).normalized())))))
            ha = P[f"hand.{side}"].matrix @ Vector((0, HAND_ANCHOR, 0)); ha = Vector((ha.x, -ha.y, ha.z))
            st.append(dict(anchor_err=(ha - contact(role, fr / nfr if kind == 'sling' else 0.0)).length, ik_err=(wr - tgt).length, stretch=(wr - sh).length / (UARM + FARM), elbow=ang))
        baked[name] = frames; stats[name] = st
        if kind == "sling": print(f"   {name} IK-rig anchor error before FK bake: max {max(s['anchor_err'] for s in st)*1000:.3f} mm")
        print(f"{name}: {len(frames)} frames, worst IK miss {max(s['ik_err'] for s in st)*1000:.2f} mm, "
              f"max arm stretch {max(s['stretch'] for s in st)*100:.1f}% of straight, min elbow {min(s['elbow'] for s in st):.0f} deg")
print(f"max baked bone translation (must be ~0 for rotation-only clips): {worst_loc*1000:.4f} mm")

# ---- clip samples for the Blender demo (build_madison_demo.py): Madison quaternions + the existing cruise pose (legs/pedalling)
SAMPLES_OUT = os.environ.get("MADISON_SAMPLES", os.path.join(HERE, "clip_samples.json"))
for role in ROLES:
    child_of[role].influence = 0.0
cruise = []
for fr in range(ns["LOOP"] + 1):
    ns["apply_controls"]("cruise", fr)
    P = evaluated_pose()
    mats = {n: P[n].matrix.copy() for n in DEFORM}
    row = {}
    for n in DEFORM:
        loc, q, _ = basis_of(n, mats)
        row[n] = [loc.x, loc.y, loc.z, q.w, q.x, q.y, q.z]
    cruise.append(row)
json.dump({"cruise": cruise, "clips": {k: [{n: [q.w, q.x, q.y, q.z] for n, q in fr.items()} for fr in v] for k, v in baked.items()},
           "deform_order": DEFORM, "hand_anchor": HAND_ANCHOR},
          open(SAMPLES_OUT, "w"))

# ------------------------------------------------------------------ strip to the game rig (same as build_rider.py)
bpy.data.objects.remove(wrist_tgt["giver"]); bpy.data.objects.remove(wrist_tgt["receiver"]); bpy.data.objects.remove(hc)
for p in pb:
    for c in list(p.constraints): p.constraints.remove(c)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for b in list(arm.edit_bones):
    if not b.use_deform: arm.edit_bones.remove(b)
bpy.ops.object.mode_set(mode='OBJECT')
for p in pb:
    p.location = (0, 0, 0); p.rotation_quaternion = (1, 0, 0, 0); p.scale = (1, 1, 1)

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

# ------------------------------------------------------------------ verification on the BAKED clips
def anchor_rider_space(side):
    dg = bpy.context.evaluated_depsgraph_get()
    m = rig.evaluated_get(dg).pose.bones[f"hand.{side}"].matrix
    p = m @ Vector((0, HAND_ANCHOR, 0))
    return Vector((p.x, -p.y, p.z))

def play(act, fr):
    rig.animation_data.action = act
    try:
        if act.slots: rig.animation_data.action_slot = act.slots[0]
    except Exception:
        pass
    scene.frame_set(fr)
    bpy.context.view_layer.update()

rows, worst = [], 0.0
for fr in range(SLING_FRAMES + 1):
    t = fr / SLING_FRAMES
    play(ACTIONS["madison_giver_sling"], fr); ag = anchor_rider_space("R")
    play(ACTIONS["madison_receiver_sling"], fr); ar_local = anchor_rider_space("L")
    ar = ar_local + Vector((-REF_GAP, delta_f(t), 0))          # receiver origin relative to giver origin
    C = contact_giver(t)
    dg_, dr_, dh = (ag - C).length, (ar - C).length, (ag - ar).length
    worst = max(worst, dg_, dr_)
    sg, sr = stats["madison_giver_sling"][fr], stats["madison_receiver_sling"][fr]
    rows.append([f"{t:.4f}", f"{efficiency(t):.4f}", f"{delta_f(t):.4f}", f"{dg_*1000:.3f}", f"{dr_*1000:.3f}", f"{dh*1000:.3f}",
                 f"{sg['stretch']*100:.1f}", f"{sr['stretch']*100:.1f}", f"{sg['elbow']:.0f}", f"{sr['elbow']:.0f}"])
with open(LOG_OUT, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["sling_t", "efficiency", "delta_f_m", "giver_hand_to_contact_mm", "receiver_hand_to_contact_mm",
                "hand_to_hand_mm", "giver_arm_stretch_pct", "receiver_arm_stretch_pct", "giver_elbow_deg", "receiver_elbow_deg"])
    w.writerows(rows)
print(f"SLING contact log (baked FK clips, gap {REF_GAP} m): worst hand-to-HandContact distance {worst*1000:.3f} mm over {SLING_FRAMES+1} samples -> {LOG_OUT}")

# ------------------------------------------------------------------ profile json (contract with Godot)
N = 100
def tab(fn): return [fn(i / N) for i in range(N + 1)]
profile = dict(
    version=1, ref_gap=REF_GAP, hand_anchor=HAND_ANCHOR, peak_t=PEAK_T, e_end=E_END, reach_short=REACH_SHORT,
    fps=FPS, approach_frames=APPROACH_FRAMES, sling_frames=SLING_FRAMES, release_frames=RELEASE_FRAMES,
    coords="rider space [x=left, f=forward, z=up]; Godot Vector3(x, z, f)",
    receiver_origin_rel_giver="[-gap, delta_f, 0]",
    hand_axis_giver=list(HD_GIVER), hand_axis_receiver=list(-HD_GIVER),
    grab_side=dict(giver="R", receiver="L"),
    clips=["madison_giver_approach", "madison_receiver_approach", "madison_giver_sling", "madison_receiver_sling",
           "madison_giver_release", "madison_receiver_release"],
    keyed_bones=KEYED,
    table_n=N,
    efficiency=tab(efficiency), delta_f=tab(delta_f),
    contact_giver=[list(contact_giver(i / N)) for i in range(N + 1)],
    contact_receiver=[list(contact_receiver(i / N)) for i in range(N + 1)],
    measured=dict(worst_contact_mm=worst * 1000,
                  giver_max_stretch_pct=max(s["stretch"] for s in stats["madison_giver_sling"]) * 100,
                  receiver_max_stretch_pct=max(s["stretch"] for s in stats["madison_receiver_sling"]) * 100),
)
json.dump(profile, open(PROFILE_OUT, "w"), indent=1)

# ------------------------------------------------------------------ save rig blend (with meshes), then export GLB
rig.animation_data.action = None
for ob in list(scene.objects): ob.select_set(False)
bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
print("saved", BLEND_OUT)

# GLB: same armature (27 deform bones, same names / hierarchy) with a tiny proxy mesh weighted to every bone
# so the glTF keeps its skin; the big Rider/Bike meshes are not duplicated in the animation file.
for nme in ("Rider", "Bike"):
    bpy.data.objects.remove(bpy.data.objects[nme])
verts, faces, groups = [], [], {}
for b in arm.bones:
    o = len(verts); h = b.head_local
    verts += [h, h + Vector((0.001, 0, 0)), h + Vector((0, 0.001, 0))]
    faces.append((o, o + 1, o + 2)); groups[b.name] = (o, o + 1, o + 2)
me = bpy.data.meshes.new("MadisonProxy"); me.from_pydata([tuple(v) for v in verts], [], faces)
px = bpy.data.objects.new("MadisonProxy", me); scene.collection.objects.link(px)
for bn, idx in groups.items():
    g = px.vertex_groups.new(name=bn); g.add(list(idx), 1.0, 'REPLACE')
px.parent = rig
md = px.modifiers.new("Armature", 'ARMATURE'); md.object = rig

ad = rig.animation_data; ad.action = None
for name, act in ACTIONS.items():
    tr = ad.nla_tracks.new(); tr.name = name
    st_ = tr.strips.new(name, 0, act); tr.mute = False
    try:
        if st_.action_slot is None and len(act.slots): st_.action_slot = act.slots[0]
    except AttributeError:
        pass
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=GLB_OUT, export_format='GLB', export_animations=True,
                          export_animation_mode='ACTIONS', export_force_sampling=True, export_yup=True, export_apply=False)
print("exported", GLB_OUT)
n_removed = MC.filter_glb_channels(GLB_OUT, set(KEYED))
print(f"removed {n_removed} static non-upper-body channels from the GLB (exporter artefact)")
