"""
Madison demo scene (Blender 4.2+ / 5.x, headless):   blender -b -P build_madison_demo.py

Builds game/assets/source_blender/madison/madison_demo.blend: two existing Velodrome riders (appended from
madison_rig.blend, i.e. the unchanged rig + meshes) with ONE TIMELINE PER SCENARIO (marker per scenario).
The timelines are not re-implemented here: they are the per-frame states recorded from the real Godot MadisonExchange
controller (docs/madison/measurements/timeline_*.json, written by tests/test_madison_flow.gd with MADISON_WRITE_DOCS=1),
so the Blender animation is the same animation Godot plays (approach_t / sling_t / release_t, crossfades, overlay, visual offsets).
The poses are the baked FK clips only (clip_samples.json) - NO IK. That is deliberate: the hand distances measured here
(docs/madison/measurements/blender_fk_hand_distance.csv) show where Godot's IK / visual corrections have to do the work.
Scene fps = 30 (timeline recorded at 60 fps, every 2nd frame is keyed, so playback time is exact).
"""
import os, sys, json, math, csv
import bpy
from mathutils import Vector, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
MEAS = os.path.join(REPO, "docs", "madison", "measurements")
SHOTS = os.environ.get("MADISON_SHOTS", os.path.join(REPO, "docs", "madison", "screenshots"))
BLEND_IN = os.path.join(HERE, "madison_rig.blend")
BLEND_OUT = os.path.join(HERE, "madison_demo.blend")
samples = json.load(open(os.path.join(HERE, "clip_samples.json")))
CLIPS, CRUISE, DEFORM, ANCHOR = samples["clips"], samples["cruise"], samples["deform_order"], samples["hand_anchor"]
KEYED = ["spine", "chest", "neck", "head", "clavicle.L", "clavicle.R", "upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R",
         "hand.L", "hand.R"]
SCENARIOS = [("A", 1.20, "A_perfect"), ("B", 1.20, "B_too_early"), ("C", 1.20, "C_too_long"),
             ("D", 0.60, "D_gap_0.60"), ("D", 1.20, "D_gap_1.20"), ("D", 1.80, "D_gap_1.80")]
SUIT = {"giver": dict(suit=(0.918, 0.780, 0.212), accent=(1.0, 0.95, 0.66), helmet=(0.918, 0.780, 0.212), helmet2=(1.0, 0.95, 0.74), panel=(0.145, 0.16, 0.2)),
        "receiver": dict(suit=(0.149, 0.549, 0.827), accent=(0.55, 0.835, 1.0), helmet=(0.094, 0.494, 0.76), helmet2=(0.68, 0.87, 1.0), panel=(0.09, 0.165, 0.294))}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30

def lin(c):
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)

def load_rider(role):
    with bpy.data.libraries.load(BLEND_IN, link=False) as (src, dst):
        dst.objects = list(src.objects)
    objs = [o for o in dst.objects if o is not None]
    for o in objs:
        scene.collection.objects.link(o)
    rig = next(o for o in objs if o.type == 'ARMATURE')
    for o in objs:
        o.name = f"{role}_{o.name.split('.')[0]}"
    for o in objs:
        if o.type != 'MESH': continue
        for slot in o.material_slots:
            m = slot.material
            base = m.name.split(".")[0]
            if base in SUIT[role]:
                m = m.copy(); slot.material = m          # unique per rider (the two loads may share datablocks)
                c = lin(SUIT[role][base]) + (1.0,)
                m.diffuse_color = c
                if m.node_tree and "Principled BSDF" in m.node_tree.nodes:
                    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = c
    rig.rotation_mode = 'XYZ'
    return rig

riders = {"giver": load_rider("giver"), "receiver": load_rider("receiver")}

def cruise_pose(phase):
    x = (phase / (2 * math.pi) * 30.0) % 30.0
    i = int(x); f = x - i
    a, b = CRUISE[i], CRUISE[i + 1]
    out = {}
    for n in DEFORM:
        la, lb = Vector(a[n][:3]), Vector(b[n][:3])
        qa, qb = Quaternion(a[n][3:]), Quaternion(b[n][3:])
        out[n] = (la.lerp(lb, f), qa.slerp(qb, f))
    return out

def clip_pose(name, t):
    frames = CLIPS[name]
    x = max(0.0, min(1.0, t)) * (len(frames) - 1)
    i = min(int(x), len(frames) - 2); f = x - i
    return {n: Quaternion(frames[i][n]).slerp(Quaternion(frames[i + 1][n]), f) for n in KEYED}

def pose_for(role, fr):
    base = cruise_pose(fr["phase_g" if role == "giver" else "phase_r"])
    ap = clip_pose(f"madison_{role}_approach", fr["approach_t"])
    sl = clip_pose(f"madison_{role}_sling", fr["sling_t"])
    re = clip_pose(f"madison_{role}_release", fr["release_t"])
    out = dict(base)
    for n in KEYED:
        m = ap[n].slerp(sl[n], fr["mix_sling"]).slerp(re[n], fr["mix_release"])      # same tree as MadisonRiderRig
        out[n] = (base[n][0], base[n][1].slerp(m, fr["overlay"]))
    return out

def place(role, fr):
    rig = riders[role]
    # Godot (x, y, z=forward) -> Blender (x, -z, y)
    if role == "giver":
        rig.location = (fr["off_g"], 0.0, 0.0); rig.rotation_euler = (0.0, -fr["lean"], 0.0)
    else:
        rig.location = (fr["recv_x"] + fr["off_r"], -fr["recv_z"], 0.0); rig.rotation_euler = (0.0, fr["lean"], 0.0)

def apply(role, fr):
    rig = riders[role]
    place(role, fr)
    for n, (loc, q) in pose_for(role, fr).items():
        pb = rig.pose.bones[n]
        pb.location = loc; pb.rotation_quaternion = q

def key(role, frame):
    rig = riders[role]
    rig.keyframe_insert("location", frame=frame); rig.keyframe_insert("rotation_euler", frame=frame)
    for pb in rig.pose.bones:
        pb.keyframe_insert("location", frame=frame); pb.keyframe_insert("rotation_quaternion", frame=frame)

def anchor_world(role, side):
    rig = riders[role]
    dg = bpy.context.evaluated_depsgraph_get()
    ev = rig.evaluated_get(dg)
    m = ev.pose.bones[f"hand.{side}"].matrix
    return ev.matrix_world @ (m @ Vector((0, ANCHOR, 0)))

rows = [["scenario", "gap_m", "sling_frames", "fk_hand_distance_min_mm", "fk_hand_distance_mean_mm", "fk_hand_distance_max_mm", "visual_gap_m"]]
start = 1
peaks = {}
for sc, gap, label in SCENARIOS:
    data = json.load(open(os.path.join(MEAS, f"timeline_{sc}_gap{gap:.2f}.json")))
    tl = data["timeline"]
    scene.timeline_markers.new(label, frame=start)
    dists = []
    for fr in tl:
        frame = start + fr["f"] // 2
        measure = fr["state"] == 3 and fr["f"] % 4 == 0
        keyed = fr["f"] % 2 == 0
        if not (keyed or measure):
            continue
        for role in riders:
            apply(role, fr)
        if keyed:
            for role in riders:
                key(role, frame)
        if measure:
            bpy.context.view_layer.update()
            dists.append((anchor_world("giver", "R") - anchor_world("receiver", "L")).length)
        if fr["state"] == 3 and fr["sling_t"] >= 0.58 and label not in peaks:
            peaks[label] = frame
    vgap = None
    if dists:
        rows.append([sc, f"{gap:.2f}", len(dists), f"{min(dists)*1000:.1f}", f"{sum(dists)/len(dists)*1000:.1f}", f"{max(dists)*1000:.1f}", ""])
    start += len(tl) // 2 + 20
scene.frame_start, scene.frame_end = 1, start
with open(os.path.join(MEAS, "blender_fk_hand_distance.csv"), "w", newline="") as f:
    csv.writer(f).writerows(rows)
print("FK hand distances (no IK):")
for r in rows: print("  ", r)

# ---- camera, light, floor, preview stills
world = bpy.data.worlds.new("w"); scene.world = world; world.color = (0.56, 0.68, 0.80)
floor = bpy.data.objects.new("Floor", bpy.data.meshes.new("Floor"))
floor.data.from_pydata([(-20, -20, 0), (20, -20, 0), (20, 20, 0), (-20, 20, 0)], [], [(0, 1, 2, 3)]); scene.collection.objects.link(floor)
fm = bpy.data.materials.new("floor"); fm.diffuse_color = lin((0.74, 0.55, 0.36)) + (1,); floor.data.materials.append(fm)
tgt = bpy.data.objects.new("CamTarget", None); scene.collection.objects.link(tgt); tgt.location = (-0.6, -0.35, 0.95)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera")); scene.collection.objects.link(cam)
cam.location = (1.0, -3.4, 1.4); cam.data.lens = 50
c = cam.constraints.new('TRACK_TO'); c.target = tgt; c.track_axis = 'TRACK_NEGATIVE_Z'; c.up_axis = 'UP_Y'
scene.camera = cam
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'; scene.display.shading.color_type = 'MATERIAL'
scene.render.resolution_x, scene.render.resolution_y = 960, 540
os.makedirs(SHOTS, exist_ok=True)
bpy.context.view_layer.update()
for label, frame in peaks.items():
    scene.frame_set(frame)
    mid = ((riders["giver"].location + riders["receiver"].location) * 0.5)
    tgt.location = (mid.x, mid.y - 0.35, 0.95); cam.location = (mid.x + 1.6, mid.y - 3.0, 1.4)
    scene.render.filepath = os.path.join(SHOTS, f"blender_fk_{label}_peak.png")
    try:
        bpy.ops.render.render(write_still=True)
    except Exception as e:
        print("render skipped:", e)
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
print("saved", BLEND_OUT)
