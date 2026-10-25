"""
build_flag_official.py – the female official who waves the chequered flag (Velodrome 250).
Skinned mesh + armature + two baked loops, exported to ../out/flag_official.glb
    flag_ready_loop  (2.0 s)  flag raised, gentle flutter – shown during the last lap
    flag_wave_loop   (1.0 s)  big overhead figure-of-eight waving – when riders reach the line
Faces +Z in Godot (forward = -Y in Blender). Origin = floor between her feet.
"""
import bpy, os, sys, math
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import importlib, vlib, people
importlib.reload(vlib); importlib.reload(people)
from vlib import *
from people import build_person, bone_segments, SIDE
from mathutils import Vector, Matrix, Quaternion

OUT = os.environ.get("CROWD_OUT", os.path.join(HERE, "..", "out"))
FPS = 30
SPEC = dict(sex="f", pose="stand_flag_rest", hair="ponytail", top="blazer", bottom="trousers", acc=["lanyard"])
REGION_MATS = {  # region id -> (material name, sRGB colour)
    SKIN: ("skin", (0.96, 0.74, 0.60)), HAIR: ("hair", (0.36, 0.20, 0.10)), TOP: ("blazer", (0.10, 0.16, 0.32)),
    BOTTOM: ("trousers", (0.16, 0.17, 0.20)), SHOE: ("shoes", (0.08, 0.08, 0.09)), PUPIL: ("pupil", (0.10, 0.08, 0.07)),
    WHITE: ("shirt", (0.97, 0.97, 0.97)), MOUTH: ("mouth", (0.45, 0.20, 0.17)), ACCENT: ("accent", (0.86, 0.12, 0.18)),
    DARK: ("dark", (0.12, 0.12, 0.13)), TOP2: ("blazer_lapel", (0.06, 0.10, 0.22)), METAL: ("metal", (0.75, 0.76, 0.78)),
    LIPS: ("lips", (0.80, 0.32, 0.38)), BROW: ("brow", (0.28, 0.16, 0.09)),
}

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene; scene.render.fps = FPS
    mb, J, B = build_person(SPEC, lod=0, with_weights=True)
    # ---------------------------------------------------------------- flag (pole + chequered cloth)
    wr, hd = J["wr-1"], J["hdir-1"]
    grip = wr + hd * 0.06
    pole_dir = hd.normalized()
    pole_a, pole_b = grip - pole_dir * 0.16, grip + pole_dir * 0.92
    flag = MB()
    cyl(flag, pole_a, pole_b, 0.011, "flag_pole", "flag_pole", 10)
    sphere(flag, pole_b, (0.018,) * 3, "flag_pole", "flag_pole", (8, 5))
    W, H, NX, NY = 0.78, 0.56, 8, 6
    out_dir = Vector((-1, 0, 0))                      # cloth hangs to her right (outside)
    out_dir = (out_dir - pole_dir * out_dir.dot(pole_dir)).normalized()
    top = pole_b - pole_dir * 0.03
    seg_w = W / 3.0
    cloth_bones = [(f"flag_{i + 1}", top + out_dir * (seg_w * i), top + out_dir * (seg_w * (i + 1))) for i in range(3)]
    sub = 3
    for ix in range(NX):
        for iy in range(NY):
            tag = "flag_white" if (ix + iy) % 2 == 0 else "flag_black"
            verts, faces, weights = [], [], []
            for a in range(sub + 1):
                for b in range(sub + 1):
                    u = (ix + a / sub) / NX; v = (iy + b / sub) / NY
                    p = top + out_dir * (u * W) - pole_dir * (v * H)
                    verts.append(p)
                    x = u * 3.0
                    w = {}
                    for k in range(3):
                        c = k + 0.5; d = abs(x - c)
                        if d < 1.0: w[f"flag_{k + 1}"] = 1.0 - d
                    if u < 0.04: w = {"flag_pole": 1.0}
                    tot = sum(w.values()) or 1.0
                    weights.append({k2: v2 / tot for k2, v2 in w.items()})
            for a in range(sub):
                for b in range(sub):
                    i0 = a * (sub + 1) + b
                    faces.append([i0, i0 + 1, i0 + sub + 2, i0 + sub + 1])
            flag.add(verts, faces, tag, weights, smooth=True)
    # ---------------------------------------------------------------- objects with materials
    for rid, (name, col) in REGION_MATS.items():
        make_mat(name, col, rough=0.6)
    make_mat("flag_white", (0.97, 0.97, 0.97), rough=0.8); make_mat("flag_black", (0.07, 0.07, 0.08), rough=0.8)
    make_mat("flag_pole", (0.80, 0.81, 0.83), rough=0.35, metal=0.6)
    mb.ft = [REGION_MATS[t][0] for t in mb.ft]
    body = build_object(mb, "FlagOfficial", mode="materials")
    flag_ob = build_object(flag, "ChequeredFlag", mode="materials")
    for m in (bpy.data.materials["flag_white"], bpy.data.materials["flag_black"]):
        pass
    # ---------------------------------------------------------------- armature
    arm = bpy.data.armatures.new("FlagRig"); rig = bpy.data.objects.new("FlagRig", arm)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.edit_bones
    def bone(name, h, t, parent=None, connect=False):
        b = eb.new(name); b.head = h; b.tail = t; b.roll = 0.0
        if parent: b.parent = eb[parent]; b.use_connect = connect
        return b
    bone("root", Vector((0, 0, 0)), Vector((0, 0, 0.25)))
    parents = dict(pelvis="root", spine="pelvis", chest="spine", neck="chest", head="neck")
    for n in ("pelvis", "spine", "chest", "neck", "head"):
        bone(n, *B[n], parents[n])
    for s in "LR":
        bone(f"clavicle.{s}", *B[f"clavicle.{s}"], "chest")
        bone(f"upper_arm.{s}", *B[f"upper_arm.{s}"], f"clavicle.{s}")
        bone(f"forearm.{s}", *B[f"forearm.{s}"], f"upper_arm.{s}")
        bone(f"hand.{s}", *B[f"hand.{s}"], f"forearm.{s}")
        bone(f"thigh.{s}", *B[f"thigh.{s}"], "pelvis")
        bone(f"shin.{s}", *B[f"shin.{s}"], f"thigh.{s}")
        bone(f"foot.{s}", *B[f"foot.{s}"], f"shin.{s}")
    bone("flag_pole", pole_a, pole_b, "hand.R")
    prev = "flag_pole"
    for name, h, t in cloth_bones:
        bone(name, h, t, prev); prev = name
    bpy.ops.object.mode_set(mode='OBJECT')
    for ob, src in ((body, mb), (flag_ob, flag)):
        add_weights(ob, src)
        ob.parent = rig
        mod = ob.modifiers.new("Armature", 'ARMATURE'); mod.object = rig
    # ---------------------------------------------------------------- animation
    pb = rig.pose.bones
    rest = {b.name: b.matrix_local.copy() for b in arm.bones}
    S = J["sh-1"]; UA, FA = J["dm"]["ua"], J["dm"]["fa"]
    pole_rest_dir = (pole_b - pole_a).normalized()
    hand_rest = rest["hand.R"]

    def pose_mat(name, head, ydir):
        R0 = rest[name].to_3x3()
        y0 = R0.col[1].normalized()
        q = y0.rotation_difference(ydir.normalized())
        M = (q.to_matrix() @ R0).to_4x4(); M.translation = head
        return M

    def set_right_arm(wrist_target, pole_world_dir, elbow_hint):
        elb, wrist = two_bone(S, wrist_target, UA, FA, elbow_hint)
        Mu = pose_mat("upper_arm.R", S, elb - S)
        Mf = pose_mat("forearm.R", elb, wrist - elb)
        # hand orientation: rotate the rest hand so the pole (rigidly attached) points along pole_world_dir
        q = pole_rest_dir.rotation_difference(pole_world_dir.normalized())
        Mh = (q.to_matrix() @ hand_rest.to_3x3()).to_4x4(); Mh.translation = wrist
        parent_clav = rest["clavicle.R"]
        mats = {"upper_arm.R": (Mu, parent_clav), "forearm.R": (Mf, Mu), "hand.R": (Mh, Mf)}
        parents = {"upper_arm.R": "clavicle.R", "forearm.R": "upper_arm.R", "hand.R": "forearm.R"}
        for n, (M, Pm) in mats.items():
            local = rest[parents[n]].inverted() @ rest[n]
            basis = (Pm @ local).inverted() @ M
            loc, rot, _ = basis.decompose()
            pb[n].location = loc; pb[n].rotation_quaternion = rot

    def set_cloth(phase, amp, lag):
        for i in range(3):
            a = lag * (0.6 + 0.4 * i) + amp * math.sin(phase - 1.1 * i) * (0.6 + 0.3 * i)
            twist = amp * 0.6 * math.sin(phase * 1.3 - 0.9 * i)
            pb[f"flag_{i + 1}"].rotation_quaternion = Quaternion((0, 0, 1), a) @ Quaternion((0, 1, 0), twist)

    def set_body(t, energy):
        # only the head moves: the right-arm solve assumes a static chest/clavicle
        pb["head"].rotation_quaternion = Quaternion((0, 1, 0), 0.10 * energy * math.sin(t)) @ Quaternion((1, 0, 0), 0.05)

    rig.animation_data_create()
    for p in pb: p.rotation_mode = 'QUATERNION'
    actions = {}
    def key_all(fr):
        for p in pb:
            p.keyframe_insert("location", frame=fr); p.keyframe_insert("rotation_quaternion", frame=fr)

    def person(x, f, z): return D(x, f, z)
    # READY: flag held up high beside the head, small sway + flutter (60 frames)
    act = bpy.data.actions.new("flag_ready_loop"); act.use_fake_user = True
    rig.animation_data.action = act
    N = 60
    for fr in range(N + 1):
        t = 2 * math.pi * fr / N
        for p in pb:
            p.location = (0, 0, 0); p.rotation_quaternion = (1, 0, 0, 0)
        sway = 0.10 * math.sin(t)
        w = S + D(-0.06 + 0.03 * math.sin(t), 0.10, 0.42)
        pdir = D(-0.15 + sway, 0.10, 1.0)
        set_right_arm(w, pdir, D(-1, -0.2, -0.4))
        set_cloth(t * 2, 0.22, 0.25 * math.sin(t))
        set_body(t, 0.3)
        key_all(fr)
    actions["ready"] = act
    # WAVE: vigorous up-and-down waving towards the riders (20 frames = 0.67 s)
    act = bpy.data.actions.new("flag_wave_loop"); act.use_fake_user = True
    rig.animation_data.action = act
    N = 20
    for fr in range(N + 1):
        t = 2 * math.pi * fr / N
        for p in pb:
            p.location = (0, 0, 0); p.rotation_quaternion = (1, 0, 0, 0)
        up = math.sin(t)                                  # +1 high, -1 low
        w = S + D(-0.07, 0.16 + 0.10 * (1 - up) * 0.5, 0.30 + 0.16 * up)
        pitch = 0.35 - 0.85 * math.sin(t - 0.6)          # pole whips forward (down) and back (up)
        pdir = D(-0.18, math.sin(pitch), math.cos(pitch))
        set_right_arm(w, pdir, D(-1, -0.2, -0.4))
        set_cloth(t * 2, 0.40, 0.7 * math.cos(t - 0.6))
        set_body(t, 1.0)
        key_all(fr)
    actions["wave"] = act
    rig.animation_data.action = None
    for a in actions.values():
        tr = rig.animation_data.nla_tracks.new(); tr.name = a.name
        st = tr.strips.new(a.name, 0, a)
        try:
            if st.action_slot is None and len(a.slots): st.action_slot = a.slots[0]
        except AttributeError:
            pass
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "flag_official_rig.blend"))
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "flag_official.glb"), export_format='GLB', export_animations=True,
                              export_animation_mode='ACTIONS', export_force_sampling=True, export_yup=True)
    print("exported flag_official.glb", mb.tris() + flag.tris(), "tris")

if __name__ == "__main__":
    main()
