"""
build_dog.py – medium-sized, light cream labradoodle for the Velodrome 250 boost (canicross dog).
Skinned mesh + armature + baked gallop loop, exported to ../out/boost_dog.glb
  - body from a skin-modifier skeleton graph, covered with ~900 small curls (the doodle coat)
  - shaggy face with dark eyes, nose and tongue, floppy ears, plumed tail
  - dark harness with a yellow reflective tab and a back ring (bone 'harness_ring' = leash point)
  - animation 'gallop_loop' (0.4 s): rotary gallop, spine flex, body bob, ear flop, tail wag
Faces +Z in Godot (forward = -Y in Blender). Origin = ground under the middle of the dog.
"""
import bpy, bmesh, os, sys, math, random
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import importlib, vlib
importlib.reload(vlib)
from vlib import *
from mathutils import Vector, Matrix, Quaternion

OUT = os.environ.get("CROWD_OUT", os.path.join(HERE, "..", "out"))
FPS = 30
LOOP = 12                      # frames per stride (0.4 s)
COLORS = dict(
    fur_base=(0.86, 0.75, 0.60), fur_1=(0.95, 0.87, 0.75), fur_2=(0.91, 0.81, 0.66), fur_3=(0.98, 0.93, 0.85),
    fur_ear=(0.88, 0.74, 0.56), nose=(0.17, 0.12, 0.11), eye=(0.12, 0.07, 0.05), eye_shine=(0.95, 0.95, 0.95),
    tongue=(0.90, 0.50, 0.56), harness=(0.24, 0.22, 0.21), harness_trim=(0.40, 0.37, 0.34),
    reflect=(0.85, 0.95, 0.15), ring=(0.75, 0.76, 0.78), pad=(0.20, 0.16, 0.15),
)

def P(f, z, x=0.0):
    return D(x, f, z)

# ------------------------------------------------------------------ skeleton (standing rest pose)
J = dict(
    pelvis=P(-0.30, 0.50), spine1=P(-0.14, 0.52), spine2=P(0.02, 0.53), chest=P(0.18, 0.51),
    neck_base=P(0.27, 0.58), neck_top=P(0.34, 0.69), head=P(0.40, 0.74), head_tip=P(0.50, 0.75),
    tail1=P(-0.38, 0.56), tail2=P(-0.45, 0.64), tail3=P(-0.48, 0.74), tail_tip=P(-0.45, 0.82),
)
for s in (1, -1):
    n = "L" if s > 0 else "R"
    J[f"shoulder.{n}"] = P(0.22, 0.45, s * 0.085)
    J[f"elbow.{n}"] = P(0.17, 0.32, s * 0.09)
    J[f"wrist.{n}"] = P(0.20, 0.12, s * 0.085)
    J[f"fpaw.{n}"] = P(0.235, 0.035, s * 0.085)
    J[f"hip.{n}"] = P(-0.30, 0.46, s * 0.08)
    J[f"stifle.{n}"] = P(-0.22, 0.30, s * 0.09)
    J[f"hock.{n}"] = P(-0.36, 0.14, s * 0.085)
    J[f"hpaw.{n}"] = P(-0.33, 0.035, s * 0.085)
    J[f"ear_top.{n}"] = P(0.38, 0.79, s * 0.07)
    J[f"ear_tip.{n}"] = P(0.40, 0.63, s * 0.088)

BONES = [  # name, head, tail, parent
    ("root", P(0, 0), P(0, 0.2), None),
    ("pelvis", J["pelvis"], J["spine1"], "root"),
    ("spine1", J["spine1"], J["spine2"], "pelvis"),
    ("spine2", J["spine2"], J["chest"], "spine1"),
    ("chest", J["chest"], J["neck_base"], "spine2"),
    ("neck", J["neck_base"], J["neck_top"], "chest"),
    ("head", J["neck_top"], J["head_tip"], "neck"),
    ("tail1", J["tail1"], J["tail2"], "pelvis"),
    ("tail2", J["tail2"], J["tail3"], "tail1"),
    ("tail3", J["tail3"], J["tail_tip"], "tail2"),
]
for n in ("L", "R"):
    BONES += [
        (f"upper_arm.{n}", J[f"shoulder.{n}"], J[f"elbow.{n}"], "chest"),
        (f"forearm.{n}", J[f"elbow.{n}"], J[f"wrist.{n}"], f"upper_arm.{n}"),
        (f"fpaw.{n}", J[f"wrist.{n}"], J[f"fpaw.{n}"], f"forearm.{n}"),
        (f"thigh.{n}", J[f"hip.{n}"], J[f"stifle.{n}"], "pelvis"),
        (f"shin.{n}", J[f"stifle.{n}"], J[f"hock.{n}"], f"thigh.{n}"),
        (f"hpaw.{n}", J[f"hock.{n}"], J[f"hpaw.{n}"], f"shin.{n}"),
        (f"ear.{n}", J[f"ear_top.{n}"], J[f"ear_tip.{n}"], "head"),
    ]
RING = P(0.10, 0.758)
BONES.append(("harness_ring", RING, RING + D(0, 0, 0.05), "spine2"))
SEG = {b[0]: (b[1], b[2]) for b in BONES if b[0] not in ("root", "harness_ring")}
BODY_BONES = [b for b in SEG if not b.startswith("ear")]

def weights_for(p, bones=None, side_lock=True):
    cand = []
    for n in (bones or BODY_BONES):
        if side_lock and p.x > 0.03 and n.endswith(".R"): continue
        if side_lock and p.x < -0.03 and n.endswith(".L"): continue
        d, _ = seg_dist(p, *SEG[n]); cand.append((d, n))
    cand.sort(); dmin = cand[0][0] + 1e-4
    sel = [(d, n) for d, n in cand[:3] if d < dmin * 1.4 + 0.01]
    ws = {n: 1.0 / (d + 0.006) ** 4 for d, n in sel}
    tot = sum(ws.values())
    return {n: w / tot for n, w in ws.items()}

# ------------------------------------------------------------------ geometry
def _curl_field(p, mask=1.0):
    """curly 'doodle' coat: soft domes from cell noise at two scales + low-frequency clumps (0..1)"""
    from mathutils import noise
    q = p * 38.0
    d1 = noise.voronoi(q, distance_metric='DISTANCE')[0][0]
    d2 = noise.voronoi(q * 2.1 + Vector((3.1, 1.7, 5.2)), distance_metric='DISTANCE')[0][0]
    dome1 = max(0.0, 1.0 - d1 * 1.25) ** 0.6
    dome2 = max(0.0, 1.0 - d2 * 1.25) ** 0.6
    clump = 0.5 + 0.5 * noise.noise(p * 7.0)
    return (0.62 * dome1 + 0.38 * dome2) * (0.65 + 0.35 * clump) * mask

FUR_LOW = Vector((0.80, 0.66, 0.50))     # sRGB, deep in the curls
FUR_MID = Vector((0.92, 0.82, 0.68))
FUR_TIP = Vector((0.98, 0.94, 0.87))
FUR_EAR = Vector((0.86, 0.70, 0.52))

def build():
    rnd = random.Random(250)
    fur = MB()          # displaced coat (vertex coloured)
    mb = MB()           # eyes, nose, tongue, pads, harness
    # body skin graph
    pts, rad, edges = [], [], []
    def node(p, r):
        pts.append(p); rad.append((r, r) if not isinstance(r, tuple) else r); return len(pts) - 1
    def chain(i0, lst):
        prev = i0
        for p, r in lst:
            i = node(p, r); edges.append((prev, i)); prev = i
        return prev
    pel = node(J["pelvis"], 0.135)
    s1 = chain(pel, [(J["spine1"], 0.14)])
    s2 = chain(s1, [(J["spine2"], 0.155)])
    ch = chain(s2, [(J["chest"], 0.165)])
    chain(ch, [(P(0.22, 0.37), 0.115)])                                   # deep brisket
    chain(ch, [(J["neck_base"], 0.115), (J["neck_top"], 0.095), (J["head"], 0.075)])
    chain(pel, [(J["tail1"], 0.045), (J["tail2"], 0.042), (J["tail3"], 0.036), (J["tail_tip"], 0.026)])
    for n in ("L", "R"):
        chain(ch, [(J[f"shoulder.{n}"], 0.085), (J[f"elbow.{n}"], 0.066), (J[f"wrist.{n}"], 0.046), (J[f"fpaw.{n}"] + D(0, 0.0, 0.012), 0.045)])
        chain(pel, [(J[f"hip.{n}"], 0.105), (J[f"stifle.{n}"], 0.08), (J[f"hock.{n}"], 0.046), (J[f"hpaw.{n}"] + D(0, 0.0, 0.012), 0.045)])
    bv, bf = skin_mesh(pts, rad, edges, pel, subsurf=2)
    fur.add(bv, bf, "fur", [weights_for(v) for v in bv])
    H = J["head"]
    sphere(fur, H, (0.095, 0.098, 0.088), "fur", "head", (40, 28))
    muz = H + D(0, 0.088, -0.035)
    sphere(fur, muz, (0.06, 0.08, 0.055), "fur", "head", (32, 20))
    for n, sgn in (("L", 1), ("R", -1)):
        top, tip = J[f"ear_top.{n}"], J[f"ear_tip.{n}"]
        c = top.lerp(tip, 0.5) + D(sgn * 0.012, 0, 0)
        Me = look_matrix(Vector(), Vector((sgn, 0, 0))).to_3x3()
        n0 = len(fur.v)
        sphere(fur, c, (0.058, 0.095, 0.03), "fur_ear", f"ear.{n}", (24, 18), M=Me)
    # paws: pads only (the coat covers the foot)
    for n in ("L", "R"):
        for key in (f"fpaw.{n}", f"hpaw.{n}"):
            c = J[key] + D(0, 0.02, -0.012)
            sphere(mb, c + D(0, 0, 0.004), (0.026, 0.034, 0.006), "pad", key, (10, 5))
    nose = H + D(0, 0.170, -0.022)
    eyes = [H + D(sg * 0.042, 0.075, 0.026) for sg in (1, -1)]
    tongue_root = H + D(0, 0.115, -0.085)
    # ---------------- displacement + vertex colours on the coat
    vn = [Vector() for _ in fur.v]
    for f in fur.f:
        a, b2, c = fur.v[f[0]], fur.v[f[1]], fur.v[f[2]]
        nrm = (b2 - a).cross(c - a)
        if len(f) == 4: nrm += (c - a).cross(fur.v[f[3]] - a)
        for k in f: vn[k] += nrm
    cols = []
    for i, v in enumerate(fur.v):
        n_ = vn[i].normalized() if vn[i].length > 1e-12 else Vector((0, 0, 1))
        mask = 1.0
        dn = (v - nose).length; mask *= min(1.0, max(0.15, (dn - 0.02) / 0.05))
        for e in eyes:
            de = (v - e).length; mask *= min(1.0, max(0.0, (de - 0.012) / 0.03))
        if v.z < 0.07: mask *= max(0.3, v.z / 0.07)                 # less fluff at the paws
        h = _curl_field(v, mask)
        amp = 0.026 if v.z > 0.25 else 0.020
        if v.y < -0.30 and v.z > 0.66: amp = 0.030                   # fluffy top of the head (y<0 = forward)
        fur.v[i] = v + n_ * (amp * h - 0.004)
        base = FUR_EAR if fur.vw[i].get("ear.L", 0) + fur.vw[i].get("ear.R", 0) > 0.5 else FUR_LOW
        t = min(1.0, h * 1.35)
        col = base.lerp(FUR_MID, min(1.0, t * 1.6)) if t < 0.62 else FUR_MID.lerp(FUR_TIP, (t - 0.62) / 0.38)
        cols.append(col)
    fur.colors = cols
    # ---------------- face details (on top of the displaced coat)
    sphere(mb, nose, (0.024, 0.018, 0.019), "nose", "head", (14, 9))
    for e, sg in zip(eyes, (1, -1)):
        sphere(mb, e, (0.014, 0.013, 0.014), "eye", "head", (12, 8))
        sphere(mb, e + D(sg * 0.003, 0.011, 0.006), (0.0032,) * 3, "eye_shine", "head", (6, 4))
    tube(mb, [tongue_root, tongue_root + D(0, 0.022, -0.025), tongue_root + D(0, 0.026, -0.05)], [0.015, 0.016, 0.013], "tongue", "head", 12)
    # ---------------- harness (outside the coat)
    def ring(center, axis, a, b, tube_r, tag, seg=32):
        M = look_matrix(center, axis)
        verts, faces = [], []
        rs = 6
        for i in range(seg):
            t = math.tau * i / seg
            c = Vector((a * math.cos(t), b * math.sin(t), 0))
            tang = Vector((-a * math.sin(t), b * math.cos(t), 0)).normalized()
            nrm = Vector((tang.y, -tang.x, 0))
            for j in range(rs):
                u = math.tau * j / rs
                q = c + nrm * (tube_r * math.cos(u)) + Vector((0, 0, tube_r * 1.7 * math.sin(u)))
                verts.append(M @ q)
        for i in range(seg):
            for j in range(rs):
                i2, j2 = (i + 1) % seg, (j + 1) % rs
                faces.append([i * rs + j, i2 * rs + j, i2 * rs + j2, i * rs + j2])
        mb.add(verts, faces, tag, [weights_for(v, ["spine2", "chest", "spine1", "neck"]) for v in verts])
    ring(P(0.09, 0.505), D(0, 1, 0), 0.188, 0.212, 0.011, "harness")
    ring(P(0.265, 0.575), _n(D(0, 1, 0.55)), 0.132, 0.138, 0.010, "harness")
    box(mb, P(0.12, 0.735), (0.12, 0.21, 0.02), "harness_trim", None, M=Matrix.Rotation(math.radians(-6), 3, 'X'), bevel=0.25)
    for sg in (1, -1):
        box(mb, P(0.09, 0.47, sg * 0.206), (0.006, 0.075, 0.038), "reflect", None, bevel=0.2)
    torus(mb, RING, D(0, 1, 0), 0.022, 0.0045, "ring", None, 14, 5)
    for q in range(len(mb.vw)):
        if not mb.vw[q]:
            mb.vw[q] = {"spine2": 1.0}
    return fur, mb

def _n(v): return v.normalized()

# ------------------------------------------------------------------ animation
def animate(rig):
    pb = rig.pose.bones
    arm = rig.data
    rest = {b.name: b.matrix_local.copy() for b in arm.bones}
    parent = {b.name: (b.parent.name if b.parent else None) for b in arm.bones}
    order = []
    def walk(b):
        order.append(b.name)
        for c in b.children: walk(c)
    for b in arm.bones:
        if b.parent is None: walk(b)
    L = {k: (SEG[k][1] - SEG[k][0]).length for k in SEG}

    def follow(name, M):
        p = parent[name]
        return M[p] @ rest[p].inverted() @ rest[name] if p else rest[name].copy()

    def aim(name, M, ydir, head=None):
        F = follow(name, M)
        h = F.translation if head is None else head
        R0 = F.to_3x3().normalized()
        q = R0.col[1].normalized().rotation_difference(ydir.normalized())
        out = (q.to_matrix() @ R0).to_4x4(); out.translation = h
        return out

    def rot_local(name, M, axis_world, angle, pivot_shift=Vector()):
        F = follow(name, M)
        R = Matrix.Rotation(angle, 4, axis_world)
        out = Matrix.Translation(F.translation) @ R @ Matrix.Translation(-F.translation) @ F
        return out

    LEGS = {  # leg: (upper, lower, foot, phase offset, paw centre f, stride half, lift, hint)
        "fpaw.L": ("upper_arm.L", "forearm.L", "fpaw.L", 0.42, 0.25, 0.25, 0.15, D(0, -1, 0.2)),
        "fpaw.R": ("upper_arm.R", "forearm.R", "fpaw.R", 0.52, 0.25, 0.25, 0.15, D(0, -1, 0.2)),
        "hpaw.L": ("thigh.L", "shin.L", "hpaw.L", 0.00, -0.31, 0.21, 0.11, D(0, 1, -0.1)),
        "hpaw.R": ("thigh.R", "shin.R", "hpaw.R", 0.08, -0.31, 0.21, 0.11, D(0, 1, -0.1)),
    }
    STANCE = 0.40

    def paw_target(p, off, fc, R, lift, x):
        u = (p + off) % 1.0
        if u < STANCE:
            t = u / STANCE
            f = fc + R * (1 - 2 * t); z = 0.035
            tilt = -0.6 * t                       # paw rolls over at the end of the stance
        else:
            t = (u - STANCE) / (1 - STANCE)
            s = t * t * (3 - 2 * t)
            f = fc - R + 2 * R * s; z = 0.035 + lift * math.sin(math.pi * t) ** 0.8
            tilt = -1.2 * math.sin(math.pi * t)  # paw folds back during the swing
        return P(f, z, x), tilt

    act = bpy.data.actions.new("gallop_loop"); act.use_fake_user = True
    rig.animation_data_create(); rig.animation_data.action = act
    for b in pb: b.rotation_mode = 'QUATERNION'
    X = Vector((1, 0, 0)); Z = Vector((0, 0, 1)); FW = D(0, 1, 0)
    for fr in range(LOOP + 1):
        p = fr / LOOP; w = math.tau * p
        M = {}
        bob = 0.028 * math.cos(w - 0.6 * math.tau) + 0.008
        flex = 0.13 * math.cos(w - 0.1 * math.tau)       # +: back rounds (gather), -: stretch
        for name in order:
            if name == "root":
                M[name] = Matrix.Translation(D(0, 0, bob)) @ rest[name]
            elif name == "pelvis":
                M[name] = rot_local(name, M, X, -flex * 0.9)
            elif name in ("spine1",):
                M[name] = rot_local(name, M, X, flex * 0.5)
            elif name == "spine2":
                M[name] = rot_local(name, M, X, flex * 0.5)
            elif name == "chest":
                M[name] = rot_local(name, M, X, flex * 0.6)
            elif name == "neck":
                M[name] = rot_local(name, M, X, -flex * 0.9 + 0.05 * math.sin(w))
            elif name == "head":
                M[name] = rot_local(name, M, X, -flex * 0.5 - 0.06 * math.sin(w + 0.5))
            elif name.startswith("ear."):
                s = 1 if name.endswith("L") else -1
                ang = 0.45 * math.sin(w - 0.25 * math.tau) + 0.25
                M[name] = rot_local(name, M, X, -ang)
            elif name.startswith("tail"):
                k = int(name[-1])
                F = follow(name, M); h = F.translation
                R = Matrix.Rotation(0.22 * math.sin(2 * w - 0.6 * k), 4, Z) @ Matrix.Rotation(0.08 * math.cos(w - 0.4 * k), 4, X)
                M[name] = Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ F
            elif name in ("upper_arm.L", "upper_arm.R", "thigh.L", "thigh.R"):
                paw = "fpaw." + name[-1] if name.startswith("upper") else "hpaw." + name[-1]
                up, lo, ft, off, fc, R, lift, hint = LEGS[paw]
                F = follow(up, M); root_j = F.translation
                x = J[paw].x
                tgt, tilt = paw_target(p, off, fc, R, lift, x)
                foot_len = L[ft]
                # wrist/hock target: above the paw, tilted with the paw roll
                back = D(0, -1, 0) if paw.startswith("h") else D(0, -0.35, 0)
                fdir = (Vector((0, 0, 1)) * math.cos(tilt) + (D(0, 1, 0) if paw.startswith("f") else D(0, -1, 0)) * -math.sin(tilt)).normalized()
                if paw.startswith("h"):
                    fdir = (Vector((0, 0, 1)) * 0.96 + D(0, -1, 0) * 0.27).normalized()
                    fdir = Matrix.Rotation(tilt * 0.6, 3, X) @ fdir
                wrist_t = tgt + fdir * foot_len
                mid, wrist = two_bone(root_j, wrist_t, L[up], L[lo], hint)
                M[up] = aim(up, M, mid - root_j)
                M[lo] = aim(lo, M, wrist - mid, head=mid)
                M[ft] = aim(ft, M, tgt - wrist, head=wrist)
            elif name in M:
                continue
            else:
                M[name] = follow(name, M)
        for name in order:
            if name not in M: M[name] = follow(name, M)
            pn = parent[name]
            local = (rest[pn].inverted() @ rest[name]) if pn else rest[name]
            basis = ((M[pn] @ local).inverted() if pn else local.inverted()) @ M[name]
            loc, rq, _ = basis.decompose()
            pb[name].location = loc; pb[name].rotation_quaternion = rq
            pb[name].keyframe_insert("location", frame=fr); pb[name].keyframe_insert("rotation_quaternion", frame=fr)
    return act

# ------------------------------------------------------------------ main
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene; scene.render.fps = FPS
    for k, c in COLORS.items():
        kw = dict(rough=0.9)
        if k in ("eye", "nose", "eye_shine"): kw = dict(rough=0.25)
        if k == "ring": kw = dict(rough=0.3, metal=0.8)
        if k == "reflect": kw = dict(rough=0.4, emit=0.4)
        make_mat(k, c, **kw)
    fur, mb = build()
    fm = make_mat("fur", (0.92, 0.82, 0.68), rough=0.95)
    nt = fm.node_tree; ca = nt.nodes.new("ShaderNodeVertexColor"); ca.layer_name = "Col"
    nt.links.new(ca.outputs[0], nt.nodes["Principled BSDF"].inputs["Base Color"])
    fe = make_mat("fur_ear", (0.86, 0.70, 0.52), rough=0.95)
    nt = fe.node_tree; ca = nt.nodes.new("ShaderNodeVertexColor"); ca.layer_name = "Col"
    nt.links.new(ca.outputs[0], nt.nodes["Principled BSDF"].inputs["Base Color"])
    coat = build_object(fur, "LabradoodleCoat", mode="materials", colors=COLORS)
    col = coat.data.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
    for i, c in enumerate(fur.colors):
        col.data[i].color = lin(tuple(c)) + (1.0,)
    dog = build_object(mb, "LabradoodleDetails", mode="materials", colors=COLORS)
    arm = bpy.data.armatures.new("DogRig"); rig = bpy.data.objects.new("DogRig", arm)
    scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for name, h, t, par in BONES:
        b = arm.edit_bones.new(name); b.head = h; b.tail = t; b.roll = 0
        if par: b.parent = arm.edit_bones[par]
    bpy.ops.object.mode_set(mode='OBJECT')
    for ob, src in ((coat, fur), (dog, mb)):
        add_weights(ob, src)
        ob.parent = rig
        mod = ob.modifiers.new("Armature", 'ARMATURE'); mod.object = rig
    act = animate(rig)
    rig.animation_data.action = None
    tr = rig.animation_data.nla_tracks.new(); tr.name = act.name
    st = tr.strips.new(act.name, 0, act)
    try:
        if st.action_slot is None and len(act.slots): st.action_slot = act.slots[0]
    except AttributeError:
        pass
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "boost_dog_rig.blend"))
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "boost_dog.glb"), export_format='GLB', export_animations=True,
                              export_animation_mode='ACTIONS', export_force_sampling=True, export_yup=True)
    print("exported boost_dog.glb", fur.tris() + mb.tris(), "tris")

if __name__ == "__main__":
    main()
