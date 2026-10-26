"""Dedicated Velodrome 250 X pursuit rider and bicycle.
Derived from the project's editable rider generator. Blender 5.2 tested.
Run blender -b -P build_pursuit_rider.py; RIDER_OUT selects output folder.
Creates an editable IK .blend, GLB with four aero-compatible pedal loops,
and two actual Blender preview renders. +Z forward in Godot, metres.
"""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix, Quaternion

try:
    HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:
    HERE = os.path.dirname(bpy.data.filepath) or os.getcwd()
OUT = os.environ.get("RIDER_OUT", os.path.join(HERE, "out"))
os.makedirs(OUT, exist_ok=True)

# ----------------------------------------------------------------- config
COLORS = dict(  # sRGB 0-1
    suit=(0.07, 0.22, 0.62), accent=(1.00, 0.80, 0.08), panel=(0.04, 0.10, 0.30),
    skin=(0.96, 0.72, 0.56), cheek=(0.98, 0.55, 0.50), sock=(0.98, 0.98, 0.98),
    glove=(0.12, 0.12, 0.14), shoe=(0.98, 0.98, 0.98), sole=(0.10, 0.10, 0.11),
    helmet=(0.94, 0.96, 0.98), helmet2=(0.16, 0.30, 0.50), visor=(0.30, 0.42, 0.62), visor_frame=(0.08, 0.08, 0.09),
    eye=(1.0, 1.0, 1.0), pupil=(0.10, 0.08, 0.07), brow=(0.28, 0.17, 0.10), mouth=(0.45, 0.20, 0.17), hair=(0.30, 0.19, 0.11),
    frame=(0.08, 0.12, 0.19), frame2=(0.98, 0.98, 0.98), tire=(0.10, 0.10, 0.11),
    rim=(0.20, 0.20, 0.22), disc=(0.14, 0.14, 0.16), metal=(0.78, 0.79, 0.81),
    saddle=(0.10, 0.10, 0.11), chain=(0.40, 0.40, 0.42),
)
FPS = 30
LOOP = 30            # frames per crank revolution
GEAR = 3             # wheel revolutions per crank revolution (48x16)

def D(x, f, z):
    """rider-space vector: x = rider's left, f = forward, z = up  ->  Blender coords"""
    return Vector((x, -f, z))

# bike geometry (metres)
BB = D(0, 0, 0.29); CRANK = 0.165; PEDAL_X = 0.115
WHEEL_R = 0.335
REAR_AX = D(0, -0.40, WHEEL_R); FRONT_AX = D(0, 0.58, WHEEL_R)
SEAT_CL = D(0, -0.152, 0.82); SADDLE = D(0, -0.19, 0.955)
HT_TOP = D(0, 0.47, 0.84); HT_BOT = D(0, 0.51, 0.70)
BAR_CLAMP = D(0, 0.58, 0.885); BAR_X = 0.19
# rider geometry (cartoon proportions: big head, big hands & feet)
PELV = D(0, -0.13, 1.06); BELLY = D(0, 0.01, 1.10); CHEST = D(0, 0.17, 1.13)
UCHEST = D(0, 0.30, 1.145); NECK_T = D(0, 0.42, 1.20); HEAD_TIP = D(0, 0.54, 1.43)
HEAD_C = D(0, 0.49, 1.30); HEAD_R = 0.135
THIGH, SHIN = 0.47, 0.44
UARM, FARM = 0.27, 0.26
ANKLE_OFS = D(0, -0.07, 0.078)   # ankle relative to pedal spindle (pedal level)
TOE_OFS = D(0, 0.11, 0.035)
PHI0 = math.pi / 2               # rest crank angle: left pedal forward
WRIST_TOPS = D(0.075, 0.62, 1.01); GRIP_TOPS = D(0.075, 0.70, 1.05)
WRIST_DROPS = D(BAR_X, 0.565, 0.800); GRIP_DROPS = D(BAR_X, 0.640, 0.778)

def lin(c):
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)

def mirror(v, s):
    return Vector((v.x * s, v.y, v.z))

# ----------------------------------------------------------------- scene reset
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS
scene.frame_start, scene.frame_end = 0, LOOP

# ----------------------------------------------------------------- materials
MATS = {}
def mat(name):
    if name not in MATS:
        m = bpy.data.materials.new(name)
        c = lin(COLORS[name]) + (1.0,)
        m.diffuse_color = c
        try:
            m.use_nodes = True
        except Exception:
            pass
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = c
        rough = {"visor": 0.15, "metal": 0.3, "helmet": 0.35, "frame": 0.35, "eye": 0.3, "pupil": 0.2}.get(name, 0.65)
        bsdf.inputs["Roughness"].default_value = rough
        if name == "metal":
            bsdf.inputs["Metallic"].default_value = 0.8
        if name == "visor":
            bsdf.inputs["Alpha"].default_value = 0.5
            bsdf.inputs["Roughness"].default_value = 0.05
            try:
                m.surface_render_method = 'BLENDED'
            except Exception:
                m.blend_method = 'BLEND'
            m.diffuse_color = c[:3] + (0.5,)
        MATS[name] = m
    return MATS[name]

# ----------------------------------------------------------------- mesh builder
class MB:
    def __init__(s):
        s.v, s.f, s.fm, s.fs, s.vw = [], [], [], [], []
    def add(s, verts, faces, matname, weights, smooth=True, flat=None):
        o = len(s.v)
        s.v += [Vector(v) for v in verts]
        for i, fc in enumerate(faces):
            s.f.append([o + k for k in fc]); s.fm.append(mat(matname))
            s.fs.append(smooth and not (flat and i in flat))
        s.vw += ([{weights: 1.0}] * len(verts)) if isinstance(weights, str) else weights
    def add_bm(s, bm, matname, bone, M=Matrix(), smooth=True, flat_axis=None):
        bm.transform(M)
        bm.verts.index_update()
        verts = [v.co.copy() for v in bm.verts]
        faces, flat = [], set()
        bm.normal_update()
        for i, f in enumerate(bm.faces):
            faces.append([v.index for v in f.verts])
            if flat_axis is not None and abs(f.normal.dot(flat_axis)) > 0.95:
                flat.add(i)
        bm.free()
        s.add(verts, faces, matname, bone, smooth, flat)
    def build(s, name):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in s.v], [], s.f)
        mats = []
        for m in s.fm:
            if m not in mats: mats.append(m)
        for m in mats: me.materials.append(m)
        for p, m, sm in zip(me.polygons, s.fm, s.fs):
            p.material_index = mats.index(m); p.use_smooth = sm
        me.validate(); me.update()
        ob = bpy.data.objects.new(name, me)
        scene.collection.objects.link(ob)
        groups = {}
        for i, w in enumerate(s.vw):
            for b, val in w.items():
                if b not in groups: groups[b] = ob.vertex_groups.new(name=b)
                groups[b].add([i], val, 'REPLACE')
        return ob

def look_matrix(origin, axis_z, up_hint=Vector((0, 0, 1))):
    z = axis_z.normalized()
    if abs(z.dot(up_hint)) > 0.99: up_hint = Vector((0, 1, 0))
    x = up_hint.cross(z).normalized(); y = z.cross(x)
    M = Matrix((x, y, z)).transposed().to_4x4(); M.translation = origin
    return M

def sphere(mb, c, radii, matname, bone, segs=(24, 14), M=None, shape=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs[0], v_segments=segs[1], radius=1.0)
    for v in bm.verts:
        if shape: v.co = shape(v.co)
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))
    T = Matrix.Translation(c) @ (M.to_4x4() if M is not None else Matrix())
    mb.add_bm(bm, matname, bone, T)

def superellipse(e):
    def f(co):
        return Vector(tuple(math.copysign(abs(k) ** e, k) for k in co))
    return f

def cyl(mb, a, b, r, matname, bone, segs=16, r2=None):
    axis = b - a; L = axis.length
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r2 if r2 else r, depth=L)
    M = look_matrix((a + b) / 2, axis)
    mb.add_bm(bm, matname, bone, M, flat_axis=axis.normalized())

def tube(mb, pts, r, matname, bone, segs=14):
    for a, b in zip(pts, pts[1:]):
        cyl(mb, a, b, r, matname, bone, segs)
    for p in pts[1:-1]:
        sphere(mb, p, (r, r, r), matname, bone, (segs, 8))
    for p in (pts[0], pts[-1]):
        sphere(mb, p, (r, r, r), matname, bone, (segs, 8))

def torus(mb, center, axis, R, r, matname, bone, seg=48, rseg=10):
    M = look_matrix(center, axis)
    verts, faces = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        for j in range(rseg):
            b = 2 * math.pi * j / rseg
            p = Vector(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
            verts.append(M @ p)
    for i in range(seg):
        for j in range(rseg):
            i2, j2 = (i + 1) % seg, (j + 1) % rseg
            faces.append([i * rseg + j, i2 * rseg + j, i2 * rseg + j2, i * rseg + j2])
    mb.add(verts, faces, matname, bone)

# ----------------------------------------------------------------- IK helpers
def two_bone(root, target, a, b, hint):
    dv = target - root; d = min(dv.length, a + b - 1e-4); u = dv.normalized()
    ca = max(-1, min(1, (a * a + d * d - b * b) / (2 * a * d)))
    v = (hint - u * hint.dot(u)).normalized()
    return root + u * (a * ca) + v * (a * math.sqrt(1 - ca * ca))

def spindle(phi, s):  # s=+1 left, -1 right
    ph = phi if s > 0 else phi + math.pi
    return BB + D(s * PEDAL_X, CRANK * math.sin(ph), CRANK * math.cos(ph))

# rest joints
J = {}
for s, sfx in ((1, "L"), (-1, "R")):
    hip = D(s * 0.10, -0.17, 1.03)
    sp = spindle(PHI0, s)
    ank = sp + ANKLE_OFS; toe = sp + TOE_OFS
    knee = two_bone(hip, ank, THIGH, SHIN, D(s * 0.08, 1, 0.25))
    sh = D(s * 0.16, 0.30, 1.145)
    wr = mirror(WRIST_TOPS, s); grip = mirror(GRIP_TOPS, s)
    elb = two_bone(sh, wr, UARM, FARM, D(0.0, -0.10, -1.0))
    J.update({f"hip.{sfx}": hip, f"knee.{sfx}": knee, f"ank.{sfx}": ank, f"toe.{sfx}": toe, f"sp.{sfx}": sp,
              f"sh.{sfx}": sh, f"elb.{sfx}": elb, f"wr.{sfx}": wr, f"grip.{sfx}": grip})

# ----------------------------------------------------------------- armature
arm_data = bpy.data.armatures.new("RiderRig")
rig = bpy.data.objects.new("RiderRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
eb = arm_data.edit_bones
BONES = []
def bone(name, head, tail, parent=None, deform=True, connect=False):
    b = eb.new(name); b.head = head; b.tail = tail; b.roll = 0
    if parent: b.parent = eb[parent]; b.use_connect = connect
    b.use_deform = deform
    BONES.append(name)
    return b

X = D(1, 0, 0)
bone("root", D(0, 0, 0), D(0, 0, 0.25))
bone("bike", D(0, 0, 0), D(0, 0.3, 0), "root")
bone("wheel_f", FRONT_AX, FRONT_AX + X * 0.08, "bike")
bone("wheel_r", REAR_AX, REAR_AX + X * 0.08, "bike")
bone("crank", BB, BB + X * 0.06, "bike")
bone("bars", BAR_CLAMP, BAR_CLAMP + D(0, 0.1, 0), "bike")
bone("pelvis", PELV, BELLY, "root")
bone("spine", BELLY, CHEST, "pelvis", connect=True)
bone("chest", CHEST, UCHEST, "spine", connect=True)
bone("neck", UCHEST, NECK_T, "chest", connect=True)
bone("head", NECK_T, HEAD_TIP, "neck", connect=True)
for s, x in (("L", 1), ("R", -1)):
    bone(f"pedal.{s}", J[f"sp.{s}"], J[f"sp.{s}"] + X * 0.05, "crank")
    bone(f"clavicle.{s}", UCHEST + D(x * 0.03, 0, 0), J[f"sh.{s}"], "chest")
    bone(f"upper_arm.{s}", J[f"sh.{s}"], J[f"elb.{s}"], f"clavicle.{s}", connect=True)
    bone(f"forearm.{s}", J[f"elb.{s}"], J[f"wr.{s}"], f"upper_arm.{s}", connect=True)
    bone(f"hand.{s}", J[f"wr.{s}"], J[f"grip.{s}"], f"forearm.{s}", connect=True)
    bone(f"thigh.{s}", J[f"hip.{s}"], J[f"knee.{s}"], "pelvis")
    bone(f"shin.{s}", J[f"knee.{s}"], J[f"ank.{s}"], f"thigh.{s}", connect=True)
    bone(f"foot.{s}", J[f"ank.{s}"], J[f"toe.{s}"], f"shin.{s}", connect=True)
    # control bones (not exported)
    bone(f"foot_tgt.{s}", J[f"ank.{s}"], J[f"toe.{s}"], f"pedal.{s}", deform=False)
    bone(f"hand_tgt.{s}", J[f"wr.{s}"], J[f"grip.{s}"], "bars", deform=False)
    kp = J[f"knee.{s}"] + D(x * 0.03, 0.5, 0.05)
    bone(f"knee_pole.{s}", kp, kp + D(0, 0, 0.05), "pelvis", deform=False)
    ep = J[f"elb.{s}"] + D(x * 0.35, -0.12, -0.25)
    bone(f"elbow_pole.{s}", ep, ep + D(0, 0, 0.05), "chest", deform=False)
bpy.ops.object.mode_set(mode='OBJECT')
arm_data.display_type = 'STICK'

def seg_dist(p, a, b):
    ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length, t

# ----------------------------------------------------------------- rider body (skin modifier)
def build_body():
    pts, rad, edges = [], [], []
    def P(p, r):
        pts.append(p); rad.append(r if isinstance(r, tuple) else (r, r)); return len(pts) - 1
    def chain(idx_from, plist):
        prev = idx_from
        for p, r in plist:
            i = P(p, r); edges.append((prev, i)); prev = i
        return prev
    pel = P(PELV, (0.18, 0.17))
    chain(pel, [(BELLY, (0.16, 0.145)), (CHEST, (0.195, 0.16))])
    uc = chain(len(pts) - 1, [(UCHEST, (0.17, 0.13))])
    chain(uc, [(UCHEST.lerp(NECK_T, 0.5), 0.062), (NECK_T, 0.056)])
    for s in ("L", "R"):
        hip, knee, ank = J[f"hip.{s}"], J[f"knee.{s}"], J[f"ank.{s}"]
        chain(pel, [(hip, 0.125), (hip.lerp(knee, 0.3), 0.122), (hip.lerp(knee, 0.62), 0.104), (knee, 0.068),
                    (knee.lerp(ank, 0.28), 0.084), (knee.lerp(ank, 0.72), 0.052), (ank, 0.04)])
        sh, elb, wr = J[f"sh.{s}"], J[f"elb.{s}"], J[f"wr.{s}"]
        chain(uc, [(sh, 0.085), (sh.lerp(elb, 0.45), 0.072), (elb, 0.053), (elb.lerp(wr, 0.4), 0.053), (wr, 0.037)])
    me = bpy.data.meshes.new("skin_src")
    me.from_pydata([tuple(p) for p in pts], edges, [])
    ob = bpy.data.objects.new("skin_src", me); scene.collection.objects.link(ob)
    sk = ob.modifiers.new("Skin", 'SKIN'); sk.branch_smoothing = 0.6
    if len(me.skin_vertices) == 0:
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.skin_root_mark()  # creates skin layer
    assert len(me.skin_vertices) > 0
    for i, r in enumerate(rad):
        d = me.skin_vertices[0].data[i]; d.radius = r; d.use_root = (i == pel)
    ss = ob.modifiers.new("Sub", 'SUBSURF'); ss.levels = 2; ss.render_levels = 2
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    em = bpy.data.meshes.new_from_object(ev)
    verts = [v.co.copy() for v in em.vertices]
    faces = [list(p.vertices) for p in em.polygons]
    bpy.data.objects.remove(ob); bpy.data.meshes.remove(me); bpy.data.meshes.remove(em)
    return verts, faces

# Smooth watertight body for the tightly folded pursuit silhouette.
# Capsule union avoids self-intersecting Skin-modifier branches at the hips.
def build_body():
    body = MB()
    def ball(c, r):
        radii = r if isinstance(r, tuple) else (r, r, r)
        sphere(body, c, radii, "suit", "pelvis", (20, 12))
    def limb(a, b, r1, r2):
        cyl(body, a, b, r1, "suit", "pelvis", 20, r2)
        ball(a, r1); ball(b, r2)
    ball(PELV + D(0, -0.01, -0.015), (0.17, 0.145, 0.14))
    ball(BELLY, (0.16, 0.15, 0.115))
    ball(CHEST, (0.18, 0.155, 0.12))
    ball(UCHEST, (0.17, 0.12, 0.115))
    limb(UCHEST, NECK_T, 0.065, 0.055)
    for side in ("L", "R"):
        hip, knee, ank = J[f"hip.{side}"], J[f"knee.{side}"], J[f"ank.{side}"]
        mid = hip.lerp(knee, 0.48)
        limb(hip, mid, 0.112, 0.105)
        limb(mid, knee, 0.105, 0.065)
        calf = knee.lerp(ank, 0.32)
        limb(knee, calf, 0.065, 0.075)
        limb(calf, ank, 0.075, 0.038)
        sh, elbow, wrist = J[f"sh.{side}"], J[f"elb.{side}"], J[f"wr.{side}"]
        limb(sh, elbow, 0.078, 0.052)
        limb(elbow, wrist, 0.052, 0.035)
    ob = body.build("PursuitBodyUnion")
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True); bpy.context.view_layer.objects.active = ob
    ob.data.remesh_voxel_size = 0.012
    bpy.ops.object.voxel_remesh()
    smooth = ob.modifiers.new("SurfaceSmooth", 'SMOOTH')
    smooth.factor = 0.8; smooth.iterations = 5
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    mesh = ob.data
    verts = [v.co.copy() for v in mesh.vertices]
    faces = [list(face.vertices) for face in mesh.polygons]
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.meshes.remove(mesh)
    return verts, faces

DEFORM_BODY = ["pelvis", "spine", "chest", "neck"] + [f"{b}.{s}" for s in "LR" for b in
              ("clavicle", "upper_arm", "forearm", "hand", "thigh", "shin", "foot")]
def bone_seg(n):
    b = arm_data.bones[n]; return b.head_local, b.tail_local

def body_weights(verts):
    segs = {n: bone_seg(n) for n in DEFORM_BODY}
    out = []
    for p in verts:
        cand = []
        for n, (a, b) in segs.items():
            if p.x > 0.03 and n.endswith(".R"): continue
            if p.x < -0.03 and n.endswith(".L"): continue
            d, _ = seg_dist(p, a, b); cand.append((d, n))
        cand.sort(); dmin = cand[0][0] + 1e-4
        sel = [(d, n) for d, n in cand[:3] if d < dmin * 1.5 + 0.015]
        ws = {n: 1.0 / (d + 0.01) ** 4 for d, n in sel}
        tot = sum(ws.values()); out.append({n: w / tot for n, w in ws.items()})
    return out

def body_material(c):
    segs = {n: bone_seg(n) for n in DEFORM_BODY}
    best = min(((seg_dist(c, a, b), n) for n, (a, b) in segs.items()), key=lambda x: x[0][0])
    (d, t), n = best
    base = n.split(".")[0]
    if base == "forearm" or base == "hand": return "suit"
    if base == "upper_arm": return "accent" if t > 0.78 else "suit"
    if base == "thigh": return "accent" if t > 0.84 else "suit"
    if base == "shin": return "sock" if t > 0.66 else "skin"
    if base == "foot": return "sock"
    if base == "neck": return "skin" if t > 0.55 else "suit"
    if base == "spine" and 0.45 < t < 0.8: return "accent"
    if base in ("pelvis", "spine", "chest") and abs(c.x) > 0.135: return "panel"
    return "suit"

rider = MB()
bv, bf = build_body()
rider.add(bv, bf, "suit", body_weights(bv))
# per-face materials for the body
for i in range(len(bf)):
    c = sum((bv[k] for k in bf[i]), Vector()) / len(bf[i])
    rider.fm[i] = mat(body_material(c))

# ---- head & face (all weighted to 'head')
hb = arm_data.bones["head"]
head_up = (hb.tail_local - hb.head_local).normalized()
fwd = D(0, 1, 0)
face_fwd = (fwd * 0.97 + D(0, 0, -0.12)).normalized()
side = D(1, 0, 0)
fup = face_fwd.cross(side).normalized()  # face up
Mface = Matrix((side, fup, face_fwd)).transposed()  # columns: x=left, y=up, z=forward(out of face)
def fp(x, y, z):  # point in face frame (head-radius units)
    return HEAD_C + Mface @ Vector((x, y, z)) * HEAD_R
# Clean, friendly avatar-style face: soft egg-shaped head, painted-on features (flush decals)
HEAD_SHAPE = (1.0, 1.07, 0.97)            # head ellipsoid in face frame (x=width, y=height, z=depth), x HEAD_R
def head_shape(co):
    co = Vector(co)
    co.x *= 1.0 - 0.13 * max(0.0, -co.y) ** 2          # softer, narrower jaw
    co.z *= 1.0 - 0.06 * max(0.0, -co.y) ** 2
    return co
sphere(rider, HEAD_C, tuple(k * HEAD_R for k in HEAD_SHAPE), "skin", "head", (40, 24), M=Mface, shape=head_shape)

def surf(u, v, lift=0.0):
    """point + frame on the face surface; u = left/right, v = up/down (roughly in head radii)"""
    a, b, c = HEAD_SHAPE
    d = Vector((u, v, 0.92)).normalized()
    t = 1.0 / math.sqrt((d.x / a) ** 2 + (d.y / b) ** 2 + (d.z / c) ** 2)
    p = d * t
    p = head_shape(p) if p.y < 0 else p
    n = Vector((p.x / a ** 2, p.y / b ** 2, p.z / c ** 2)).normalized()
    tx = Vector((1, 0, 0)); tx = (tx - n * tx.dot(n)).normalized(); ty = n.cross(tx)
    R = Matrix((tx, ty, n)).transposed()
    return fp(*(p + n * lift)), Mface @ R

def decal(u, v, w, h, depth, matname, lift=0.0, segs=(20, 10)):
    p, R = surf(u, v, lift)
    sphere(rider, p, (w * HEAD_R, h * HEAD_R, depth * HEAD_R), matname, "head", segs, M=R)

def surf_line(points, r, matname, lift=0.012):
    pts = [surf(u, v, lift)[0] for u, v in points]
    tube(rider, pts, r * HEAD_R, matname, "head", 8)

for s in (1, -1):
    decal(0.27 * s, 0.04, 0.07, 0.11, 0.035, "pupil")                     # eyes: simple dark ovals
    decal(0.27 * s + 0.02 * s, 0.09, 0.03, 0.034, 0.02, "eye", lift=0.028, segs=(10, 6))  # catch light
    surf_line([(0.17 * s, 0.25), (0.27 * s, 0.285), (0.38 * s, 0.26)], 0.022, "brow")  # thin, relaxed brows
decal(0.0, -0.13, 0.085, 0.075, 0.07, "skin", segs=(16, 10))                 # small button nose
surf_line([(-0.14, -0.33), (-0.07, -0.37), (0.0, -0.38), (0.07, -0.37), (0.14, -0.33)], 0.02, "mouth")  # small smile
# short hair peeking out under the helmet at the nape (ears sit under the helmet shell)
sphere(rider, fp(0, -0.05, -0.42), (0.92 * HEAD_R, 0.62 * HEAD_R, 0.62 * HEAD_R), "hair", "head", (24, 14), M=Mface)


# ---- modern track helmet: compact rounded shell with short tail, wraparound visor, chin strap
def helmet_shell(scale, planes):
    """unit sphere in face frame, cut cleanly by planes (n, d): keeps n.p >= d, then shaped like a modern track lid"""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=64, v_segments=40, radius=1.0)
    for n, d in planes:
        n = Vector(n); nn = n.normalized()
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=nn * (d / n.length), plane_no=nn, clear_inner=True)
    for v in bm.verts:
        x, y, z = v.co  # x=left, y=up, z=forward (face frame)
        back = max(0.0, -z)
        z2 = z * 1.06 if z >= 0 else z * (1.0 + 0.55 * back ** 2.2)    # short tail
        y2 = y - 0.28 * back ** 2 * max(0.0, y) - 0.10 * back ** 3      # rear of the dome slopes down
        x2 = x * (1.0 - 0.14 * back ** 2)
        v.co = Vector((x2 * 1.07, y2 * 1.05 + 0.07, z2 * 1.07 - 0.03)) * scale
    T = Matrix.Translation(HEAD_C) @ Mface.to_4x4() @ Matrix.Scale(HEAD_R, 4)
    bm.transform(T)
    return bm


def solid_shell(bm, thick, matname, bone):
    bm.normal_update()
    vs = [v.co.copy() for v in bm.verts]; ns = [v.normal.copy() for v in bm.verts]
    bm.verts.index_update()
    faces = [[v.index for v in f.verts] for f in bm.faces]
    n = len(vs)
    verts = vs + [vs[i] - ns[i] * thick for i in range(n)]
    allf = faces + [list(reversed([k + n for k in f])) for f in faces]
    # boundary edges -> rim walls
    for e in bm.edges:
        if e.is_boundary:
            a, b = e.verts[0].index, e.verts[1].index
            f = e.link_faces[0]; fv = [v.index for v in f.verts]
            ia = fv.index(a)
            if fv[(ia + 1) % len(fv)] != b: a, b = b, a
            allf.append([b, a, a + n, b + n])
    bm.free()
    rider.add(verts, allf, matname, bone)

LOWER_EDGE = ((0, 1, -0.25), -0.45)     # lower rim: low at the nape, higher towards the face
VISOR_TOP, VISOR_SIDE, STRIPE_W = 0.56, 0.28, 0.13
# The shell is split into flush panels that share exact seams (same sphere, same shaping, scale 1.0),
# so nothing overlaps: rear/side shell | crown + centre stripe | visor.
PANELS = [
    ("helmet",      0.010, [((0, -1, 0), -VISOR_TOP), ((0, 0, -1), -VISOR_SIDE), LOWER_EDGE]),  # sides & rear
    ("helmet",      0.010, [((0, 1, 0), VISOR_TOP), ((1, 0, 0), STRIPE_W)]),                     # crown left
    ("helmet",      0.010, [((0, 1, 0), VISOR_TOP), ((-1, 0, 0), STRIPE_W)]),                    # crown right
    ("helmet2",     0.010, [((0, 1, 0), VISOR_TOP), ((1, 0, 0), -STRIPE_W), ((-1, 0, 0), -STRIPE_W)]),  # centre stripe
    ("visor",       0.004, [LOWER_EDGE, ((0, -1, 0), -VISOR_TOP), ((0, 0, 1), VISOR_SIDE)]),   # wraparound lens
]
for matname, thick, planes in PANELS:
    solid_shell(helmet_shell(1.0, planes), thick, matname, "head")

def head_pt(d, lift):
    """point on the head surface in face-frame direction d, lifted along the normal (head radii)"""
    a, b, c = HEAD_SHAPE
    d = Vector(d).normalized()
    t = 1.0 / math.sqrt((d.x / a) ** 2 + (d.y / b) ** 2 + (d.z / c) ** 2)
    p = d * t
    if p.y < 0: p = head_shape(p)
    n = Vector((p.x / a ** 2, p.y / b ** 2, p.z / c ** 2)).normalized()
    return fp(*(p + n * lift))
strap_dirs = [(1.0, -0.30, 0.02), (0.85, -0.65, 0.18), (0.55, -0.90, 0.33), (0.2, -1.0, 0.40)]
strap = [head_pt(d, 0.03) for d in strap_dirs] + [head_pt((0.0, -1.0, 0.42), 0.03)]
strap += [head_pt((-x, y, z), 0.03) for x, y, z in reversed(strap_dirs)]
tube(rider, strap, 0.022 * HEAD_R, "visor_frame", "head", 8)
for s in (1, -1):
    sphere(rider, head_pt((0.92 * s, -0.48, 0.10), 0.06), (0.045 * HEAD_R, 0.07 * HEAD_R, 0.05 * HEAD_R),
           "visor_frame", "head", (12, 8), M=Mface)  # side buckle


# ---- gloves (mittens) and shoes
for s, x in (("L", 1), ("R", -1)):
    wr, grip = J[f"wr.{s}"], J[f"grip.{s}"]
    hd = (grip - wr).normalized()
    Mh = look_matrix(Vector(), hd, D(0, 0, 1)).to_3x3()
    c = wr + hd * 0.065
    sphere(rider, c, (0.055, 0.045, 0.075), "glove", f"hand.{s}", (20, 12), M=Mh, shape=superellipse(0.85))
    sphere(rider, wr + hd * 0.035 + D(-x * 0.045, 0, 0.015), (0.022, 0.022, 0.035), "glove", f"hand.{s}", (12, 8), M=Mh)  # thumb
    cyl(rider, wr - hd * 0.02, wr + hd * 0.02, 0.040, "accent", f"hand.{s}", 16)  # cuff
    # shoe
    ank, toe, sp = J[f"ank.{s}"], J[f"toe.{s}"], J[f"sp.{s}"]
    sole_z = sp.z + 0.018
    fwdv = D(0, 1, 0)
    sc = Vector((sp.x, (sp + D(0, -0.03, 0)).y, sole_z + 0.045))
    sphere(rider, sc, (0.058, 0.155, 0.055), "shoe", f"foot.{s}", (24, 14), shape=superellipse(0.7))
    sphere(rider, Vector((sp.x, sc.y, sole_z + 0.008)), (0.060, 0.158, 0.014), "sole", f"foot.{s}", (24, 8), shape=superellipse(0.6))
    for k in (-0.04, 0.0, 0.04):  # strap stripes
        sphere(rider, sc + D(0, k, 0.035), (0.059, 0.012, 0.024), "accent", f"foot.{s}", (12, 6))

# ----------------------------------------------------------------- decal areas (logo / number printing)
# Four thin patches that lie 4 mm above the skinsuit, copied from the body mesh so they follow the
# skin weights and the body shape keys. Each patch has its own material + UV (0..1 over the print area),
# so Godot can put any PNG on it (transparent = no print). Default images: ./decals/*.png
DECAL_DIR = os.path.join(HERE, "decals")
DECAL_OFFSET = 0.004
decal_uv = {}            # decal vertex index -> (u, v)
decal_src = []           # (decal vertex index, source body vertex index)

def _decal_material(name, image_file):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree; bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.6
    path = os.path.join(DECAL_DIR, image_file)
    if os.path.exists(path):
        img = bpy.data.images.load(path, check_existing=True)
        tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.extension = 'CLIP'
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    else:
        bsdf.inputs["Alpha"].default_value = 0.0
    try:
        m.surface_render_method = 'BLENDED'
    except Exception:
        m.blend_method = 'BLEND'
    MATS[name] = m
    return m

def _body_vertex_normals(nv, faces):
    vn = [Vector() for _ in range(nv)]
    for f in faces:
        a, b, c = rider.v[f[0]], rider.v[f[1]], rider.v[f[2]]
        n_ = (b - a).cross(c - a)
        if len(f) == 4: n_ += (c - a).cross(rider.v[f[3]] - a)
        for k in f: vn[k] += n_
    return [n_.normalized() if n_.length > 1e-12 else Vector((0, 0, 1)) for n_ in vn]

def add_decal(name, image_file, test, centre, u_axis, v_axis, size):
    """test(face_centre, face_normal, nearest_bone, t) -> bool; size = (width, height) in metres"""
    _decal_material(name, image_file)
    nb = len(bv)
    picked = []
    for fi in range(len(bf)):
        f = rider.f[fi]
        c = sum((rider.v[k] for k in f), Vector()) / len(f)
        n_ = sum((VN[k] for k in f), Vector()).normalized()
        best = min(((seg_dist(c, *bone_seg(b)), b) for b in DEFORM_BODY), key=lambda x: x[0][0])
        if not test(c, n_, best[1], best[0][1]):
            continue
        uvs = [((rider.v[k] - centre).dot(u_axis) / size[0] + 0.5, (rider.v[k] - centre).dot(v_axis) / size[1] + 0.5) for k in f]
        if all(u < -0.05 or u > 1.05 or v < -0.05 or v > 1.05 for u, v in uvs) and \
           not (-0.05 < sum(u for u, _ in uvs) / len(uvs) < 1.05 and -0.05 < sum(v for _, v in uvs) / len(uvs) < 1.05):
            continue
        picked.append(fi)
    remap = {}
    verts, faces, weights = [], [], []
    for fi in picked:
        nf = []
        for k in rider.f[fi]:
            if k not in remap:
                remap[k] = len(verts)
                verts.append(rider.v[k] + VN[k] * DECAL_OFFSET)
                weights.append(rider.vw[k])
            nf.append(remap[k])
        faces.append(nf)
    o = len(rider.v)
    rider.add(verts, faces, name, weights)
    for k, i in remap.items():
        p = rider.v[k]
        decal_uv[o + i] = ((p - centre).dot(u_axis) / size[0] + 0.5, (p - centre).dot(v_axis) / size[1] + 0.5)
        decal_src.append((o + i, k))
    print(f"decal {name}: {len(faces)} faces")

VN = _body_vertex_normals(len(bv), rider.f[:len(bf)])
TORSO_A = (UCHEST - PELV).normalized()
BACK_N = (Vector((0, 0, 1)) - TORSO_A * TORSO_A.z).normalized()       # skinsuit back faces this way
XV = Vector((1, 0, 0))
torso_mid = PELV.lerp(UCHEST, 0.42)
add_decal("decal_back", "decal_back_1.png",
          lambda c, n_, b, t: b in ("pelvis", "spine", "chest") and n_.dot(BACK_N) > 0.45 and abs(c.x) < 0.15,
          torso_mid + BACK_N * 0.15, -XV, TORSO_A, (0.25, 0.25))
add_decal("decal_chest", "decal_chest.png",
          lambda c, n_, b, t: b in ("spine", "chest", "clavicle.L", "clavicle.R", "pelvis") and n_.dot(-BACK_N) > 0.15 and abs(c.x) < 0.17,
          CHEST.lerp(UCHEST, 0.35) - BACK_N * 0.14, XV, TORSO_A, (0.24, 0.12))
for s_, n_side in ((1, "L"), (-1, "R")):
    hip, knee = J[f"hip.{n_side}"], J[f"knee.{n_side}"]
    ta = (knee - hip); ta = (ta - XV * ta.dot(XV)).normalized()
    u_ax = -ta if s_ > 0 else ta                    # reads left-to-right seen from that side
    v_ax = XV.cross(u_ax).normalized()
    if v_ax.z < 0: v_ax = -v_ax
    mid = hip.lerp(knee, 0.47) + XV * (s_ * 0.11)
    add_decal(f"decal_thigh_{n_side}", "decal_thigh.png",
              (lambda sgn, side: (lambda c, n_, b, t: b == f"thigh.{side}" and 0.12 < t < 0.85 and n_.x * sgn > 0.45))(s_, n_side),
              mid, u_ax, v_ax, (0.22, 0.085))

rider_ob = rider.build("Rider")
if decal_uv:
    uvl = rider_ob.data.uv_layers.new(name="UVMap")
    for poly in rider_ob.data.polygons:
        for li in poly.loop_indices:
            vi = rider_ob.data.loops[li].vertex_index
            if vi in decal_uv:
                u, v = decal_uv[vi]
                uvl.data[li].uv = (u, v)

# Shared UV contract on existing rest-space clothing polygons only.
import sys
if HERE not in sys.path:
    sys.path.insert(0, HERE)
from skinsuit_uv import apply_skinsuit_uv, apply_helmet_uv
apply_skinsuit_uv(rider_ob, len(bf), bone_seg, DEFORM_BODY)
apply_helmet_uv(rider_ob, HEAD_C, Mface, HEAD_R)

# ----------------------------------------------------------------- body shape keys (morph targets)
# Value 1.0 = clearly more mass/width, -1.0 = slimmer (sliders allow -1..1). Only the skin body is
# affected; head, helmet, gloves and shoes stay as they are. Bones are not moved, so the rig still fits.
SHAPE_KEYS = {  # name: strength at value 1.0
    "ShoulderWidth": 0.045,   # metres sideways at the shoulders / upper back
    "TorsoMass": 0.16,        # radial scale of chest & trunk
    "HipWidth": 0.22,         # sideways scale of the pelvis
    "ThighMass": 0.28,        # radial scale of the upper legs
    "CalfMass": 0.28,         # radial scale of the calves
    "ArmMass": 0.25,          # radial scale of upper arms & forearms
}

def add_body_shape_keys(ob, nverts, weights):
    base = [ob.data.vertices[i].co.copy() for i in range(nverts)]
    seg = {n: bone_seg(n) for n in DEFORM_BODY}
    def axis_offset(v, bone):
        a, b = seg[bone]
        d, t = seg_dist(v, a, b)
        return v - (a + (b - a) * t), t
    def smooth(e0, e1, x):
        x = max(0.0, min(1.0, (x - e0) / (e1 - e0))); return x * x * (3 - 2 * x)
    def side_bones(w, base_name):
        return [(f"{base_name}.{s}", w[f"{base_name}.{s}"]) for s in "LR" if f"{base_name}.{s}" in w]

    def shoulder(v, w, k):
        amt = sum(x for _, x in side_bones(w, "clavicle"))
        for b, x in side_bones(w, "upper_arm"):
            amt += x * (1.0 - smooth(0.15, 0.55, axis_offset(v, b)[1]))
        amt += w.get("chest", 0.0) * smooth(0.04, 0.16, abs(v.x))
        return Vector((math.copysign(k * min(1.0, amt), v.x), 0, 0))
    def torso(v, w, k):
        d = Vector()
        for b, f in (("pelvis", 0.5), ("spine", 1.0), ("chest", 1.0)):
            if b in w: d += axis_offset(v, b)[0] * (k * f * w[b])
        for b, x in side_bones(w, "clavicle"):
            d += axis_offset(v, "chest")[0] * (k * 0.6 * x)
        return d
    def hips(v, w, k):
        amt = w.get("pelvis", 0.0) + w.get("spine", 0.0) * 0.3
        for b, x in side_bones(w, "thigh"):
            amt += x * (1.0 - smooth(0.1, 0.45, axis_offset(v, b)[1]))
        return Vector((v.x * k * min(1.0, amt), 0, 0))
    def thighs(v, w, k):
        d = Vector()
        for b, x in side_bones(w, "thigh"):
            off, t = axis_offset(v, b)
            d += off * (k * x * (1.0 - smooth(0.72, 1.0, t)))
        return d
    def calves(v, w, k):
        d = Vector()
        for b, x in side_bones(w, "shin"):
            off, t = axis_offset(v, b)
            d += off * (k * x * math.exp(-((t - 0.32) / 0.22) ** 2))
        return d
    def arms(v, w, k):
        d = Vector()
        for b, x in side_bones(w, "upper_arm"):
            d += axis_offset(v, b)[0] * (k * x)
        for b, x in side_bones(w, "forearm"):
            off, t = axis_offset(v, b)
            d += off * (k * 0.85 * x * (1.0 - smooth(0.65, 1.0, t)))
        return d
    funcs = {"ShoulderWidth": shoulder, "TorsoMass": torso, "HipWidth": hips,
             "ThighMass": thighs, "CalfMass": calves, "ArmMass": arms}

    ob.shape_key_add(name="Basis", from_mix=False)
    for name, k in SHAPE_KEYS.items():
        key = ob.shape_key_add(name=name, from_mix=False)
        key.slider_min, key.slider_max = -1.0, 1.0
        f = funcs[name]
        for i in range(nverts):
            key.data[i].co = base[i] + f(base[i], weights[i], k)
    ob.data.shape_keys.use_relative = True

add_body_shape_keys(rider_ob, len(bv), rider.vw)
for key in rider_ob.data.shape_keys.key_blocks[1:]:
    for d, src in decal_src:
        delta = key.data[src].co - rider_ob.data.vertices[src].co
        key.data[d].co = rider_ob.data.vertices[d].co + delta

# ----------------------------------------------------------------- bike
bike = MB()
for s in (1, -1):
    pass
# frame
tube(bike, [BB, SEAT_CL], 0.042, "frame", "bike")
tube(bike, [SEAT_CL, HT_TOP], 0.022, "frame", "bike")
tube(bike, [BB, HT_BOT], 0.045, "frame", "bike")
tube(bike, [HT_BOT, HT_TOP + D(0, -0.008, 0.03)], 0.028, "frame2", "bike")
for s in (1, -1):
    tube(bike, [BB + D(s * 0.03, -0.03, 0), REAR_AX + D(s * 0.06, 0.0, 0)], 0.014, "frame", "bike")
    tube(bike, [SEAT_CL + D(s * 0.02, -0.01, -0.02), REAR_AX + D(s * 0.06, 0.0, 0)], 0.012, "frame", "bike")
    tube(bike, [HT_BOT + D(s * 0.035, 0, -0.01), FRONT_AX + D(s * 0.05, 0, 0)], 0.016, "frame", "bike")
sphere(bike, HT_BOT + D(0, 0, -0.01), (0.05, 0.035, 0.025), "frame", "bike")
cyl(bike, BB + D(-0.045, 0, 0), BB + D(0.045, 0, 0), 0.026, "frame2", "bike")
# seatpost + saddle
tube(bike, [SEAT_CL, SADDLE + D(0, 0, -0.01)], 0.015, "metal", "bike")
def saddle_shape(co):
    co = Vector(tuple(math.copysign(abs(k) ** 0.75, k) for k in co))
    if co.y < 0:  # nose (forward is -Y)
        co.x *= 1.0 - 0.62 * min(1, -co.y)
    return co
sphere(bike, SADDLE + D(0, 0.01, 0.0), (0.072, 0.135, 0.028), "saddle", "bike", (24, 12), shape=saddle_shape)
# Dedicated pursuit cockpit: base bar, two risers, padded cups and extensions.
stem_top = HT_TOP + D(0, -0.005, 0.045)
tube(bike, [HT_TOP, stem_top, BAR_CLAMP], 0.023, "disc", "bike")
for sign, side in ((1, "L"), (-1, "R")):
    elbow = J[f"elb.{side}"]
    pad = elbow + D(0, 0, -0.052)
    tube(bike, [BAR_CLAMP, D(sign * 0.20, 0.59, 0.89), D(sign * 0.21, 0.68, 0.91)], 0.018, "disc", "bike")
    tube(bike, [BAR_CLAMP + D(sign * 0.06, 0, 0), D(pad.x, -pad.y, 0.87), pad], 0.015, "disc", "bike")
    sphere(bike, pad, (0.066, 0.085, 0.016), "saddle", "bike", (24, 12), shape=superellipse(0.65))
    tube(bike, [pad + D(0, 0.025, -0.012), mirror(WRIST_TOPS, sign) + D(0, 0.0, -0.022), mirror(GRIP_TOPS, sign) + D(0, 0.07, -0.013)], 0.015, "disc", "bike")
# wheels
for ax, bone_name, disc in ((REAR_AX, "wheel_r", True), (FRONT_AX, "wheel_f", True)):
    torus(bike, ax, X, WHEEL_R - 0.017, 0.017, "tire", bone_name, 64, 12)
    torus(bike, ax, X, WHEEL_R - 0.045, 0.016, "rim", bone_name, 64, 10)
    cyl(bike, ax + D(-0.055, 0, 0), ax + D(0.055, 0, 0), 0.022, "metal", bone_name, 16)
    if disc:
        sphere(bike, ax, (0.032, WHEEL_R - 0.045, WHEEL_R - 0.045), "disc", bone_name, (48, 24))
        torus(bike, ax + D(0.012, 0, 0), X, 0.20, 0.012, "accent", bone_name, 48, 8)
        torus(bike, ax + D(-0.012, 0, 0), X, 0.20, 0.012, "accent", bone_name, 48, 8)
    else:
        for k in range(3):
            a = 2 * math.pi * k / 3
            dirv = D(0, math.cos(a), math.sin(a))
            Mb = look_matrix(Vector(), dirv, X).to_3x3()
            sphere(bike, ax + dirv * 0.155, (0.032, 0.012, 0.16), "frame2", bone_name, (16, 12), M=Mb, shape=superellipse(0.8))
# drivetrain (drive side = rider's right = -X)
cyl(bike, BB + D(-0.065, 0, 0), BB + D(-0.057, 0, 0), 0.105, "metal", "crank", 40)
cyl(bike, BB + D(-0.068, 0, 0), BB + D(-0.054, 0, 0), 0.045, "frame2", "crank", 24)
cyl(bike, REAR_AX + D(-0.064, 0, 0), REAR_AX + D(-0.058, 0, 0), 0.036, "metal", "wheel_r", 24)
for zsign in (1, -1):
    a = BB + D(-0.061, 0, zsign * 0.105); b = REAR_AX + D(-0.061, 0, zsign * 0.036)
    cyl(bike, a, b, 0.006, "chain", "bike", 8)
for s, sfx in ((1, "L"), (-1, "R")):
    sp = J[f"sp.{sfx}"]
    tube(bike, [BB + D(s * 0.075, 0, 0), sp + D(-s * 0.02, 0, 0)], 0.014, "metal", "crank", 12)
    sphere(bike, sp + D(s * 0.01, 0, 0), (0.035, 0.055, 0.011), "glove", f"pedal.{sfx}", (16, 8), shape=superellipse(0.6))
bike_ob = bike.build("Bike")

for ob in (rider_ob, bike_ob):
    ob.parent = rig
    m = ob.modifiers.new("Armature", 'ARMATURE'); m.object = rig

# ----------------------------------------------------------------- constraints (IK rig)
pb = rig.pose.bones
for s in ("L", "R"):
    for chain_bone, tgt, pole in ((f"shin.{s}", f"foot_tgt.{s}", f"knee_pole.{s}"),
                                  (f"forearm.{s}", f"hand_tgt.{s}", f"elbow_pole.{s}")):
        c = pb[chain_bone].constraints.new('IK')
        c.target = rig; c.subtarget = tgt; c.pole_target = rig; c.pole_subtarget = pole
        c.chain_count = 2; c.iterations = 500; c.use_stretch = False
    for b, t in ((f"foot.{s}", f"foot_tgt.{s}"), (f"hand.{s}", f"hand_tgt.{s}")):
        c = pb[b].constraints.new('COPY_ROTATION'); c.target = rig; c.subtarget = t

def evaluated_pose():
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    return rig.evaluated_get(dg).pose.bones

# calibrate pole angles so the rest pose is reproduced exactly
for s in ("L", "R"):
    for chain_bone, mid in ((f"shin.{s}", f"shin.{s}"), (f"forearm.{s}", f"forearm.{s}")):
        c = pb[chain_bone].constraints[0]; best = None
        for deg in range(-180, 180, 1):
            c.pole_angle = math.radians(deg)
            err = (evaluated_pose()[mid].head - arm_data.bones[mid].head_local).length
            if best is None or err < best[0]: best = (err, deg)
        c.pole_angle = math.radians(best[1])
        print(f"pole {chain_bone}: {best[1]} deg (err {best[0]*1000:.1f} mm)")

# ----------------------------------------------------------------- animation controls
WFWD = D(0, 1, 0); WX = Vector((1, 0, 0))
def rest_rot(n): return arm_data.bones[n].matrix_local.to_3x3()
def q_world(n, axis, ang):
    """rotation about a world axis expressed in the bone's local rest frame"""
    return Quaternion(rest_rot(n).inverted() @ axis, ang)
def loc_world(n, v): return rest_rot(n).inverted() @ v

CTRL = ["bike", "wheel_f", "wheel_r", "crank", "pedal.L", "pedal.R", "pelvis", "spine", "chest", "neck", "head",
        "clavicle.L", "clavicle.R", "hand_tgt.L", "hand_tgt.R"]

STYLES = {name: dict(pel=(0, 0), pel_pitch=0, spine=0, chest=0, neck=0, head=0,
    roll_bike=0.0, roll_chest=0.0, roll_pel=0.0, bob=0.0, lift=0.0, hands="tops", ankle=1.0)
    for name in ("cruise", "sprint_seated", "sprint_standing", "victory")}

def apply_controls(style, frame):
    st = STYLES[style]
    t = frame / LOOP; phi = PHI0 + 2 * math.pi * t; dphi = phi - PHI0
    for n in CTRL:
        pb[n].location = (0, 0, 0); pb[n].rotation_quaternion = (1, 0, 0, 0)
    pb["crank"].rotation_quaternion = Quaternion((0, 1, 0), dphi)
    pb["wheel_f"].rotation_quaternion = Quaternion((0, 1, 0), dphi * GEAR)
    pb["wheel_r"].rotation_quaternion = Quaternion((0, 1, 0), dphi * GEAR)
    for s, off in (("L", 0.0), ("R", math.pi)):
        ph = phi + off
        toe_down = math.radians(10 + 12 * st["ankle"] * math.sin(ph - math.pi / 2))
        pb[f"pedal.{s}"].rotation_quaternion = Quaternion((0, 1, 0), -dphi + toe_down)
    roll = math.sin(phi - PHI0 + math.pi / 2)  # +1 when left pedal pushes down (front of stroke)
    pb["bike"].rotation_quaternion = Quaternion((0, 1, 0), math.radians(st["roll_bike"]) * roll)
    f, z = st["pel"][0], st["pel"][1] if len(st["pel"]) > 1 else 0.0
    z += st["bob"] * math.cos(2 * dphi) + st["lift"] * math.sin(phi) ** 2
    pb["pelvis"].location = loc_world("pelvis", D(0, f, z))
    pb["pelvis"].rotation_quaternion = (q_world("pelvis", WX, math.radians(st["pel_pitch"])) @
                                        q_world("pelvis", WFWD, math.radians(st["roll_pel"]) * roll))
    pb["spine"].rotation_quaternion = q_world("spine", WX, math.radians(st["spine"]))
    pb["chest"].rotation_quaternion = (q_world("chest", WX, math.radians(st["chest"])) @
                                       q_world("chest", WFWD, math.radians(st["roll_chest"]) * roll))
    pb["neck"].rotation_quaternion = (q_world("neck", WX, math.radians(st["neck"])) @
                                      q_world("neck", WFWD, -math.radians(st["roll_chest"]) * roll * 0.6))
    pb["head"].rotation_quaternion = q_world("head", WX, math.radians(st["head"]))
    if st["hands"] == "up":
        wave = 0.03 * math.sin(2 * dphi)
        for s, x in (("L", 1), ("R", -1)):
            target = D(x * 0.36, -0.02, 2.02 + wave * x)          # beyond reach: straight arms in a V
            pb[f"hand_tgt.{s}"].location = loc_world(f"hand_tgt.{s}", target - J[f"wr.{s}"])
            a = (GRIP_TOPS - WRIST_TOPS).normalized(); b = D(x * 0.35, 0.05, 1).normalized()
            pb[f"hand_tgt.{s}"].rotation_quaternion = rest_rot(f"hand_tgt.{s}").inverted().to_quaternion() @ \
                a.rotation_difference(b) @ rest_rot(f"hand_tgt.{s}").to_quaternion()
    if st["hands"] == "drops":
        for s, x in (("L", 1), ("R", -1)):
            pb[f"hand_tgt.{s}"].location = loc_world(f"hand_tgt.{s}", mirror(WRIST_DROPS, x) - J[f"wr.{s}"])
            a = (GRIP_TOPS - WRIST_TOPS).normalized(); b = (GRIP_DROPS - WRIST_DROPS).normalized()
            pb[f"hand_tgt.{s}"].rotation_quaternion = rest_rot(f"hand_tgt.{s}").inverted().to_quaternion() @ \
                a.rotation_difference(b) @ rest_rot(f"hand_tgt.{s}").to_quaternion()

# keyed control actions for the editable .blend
rig.animation_data_create()
ctrl_actions = {}
for style in STYLES:
    act = bpy.data.actions.new(f"ctrl_{style}"); act.use_fake_user = True
    rig.animation_data.action = act
    for fr in range(LOOP + 1):
        apply_controls(style, fr)
        for n in CTRL:
            pb[n].keyframe_insert("location", frame=fr)
            pb[n].keyframe_insert("rotation_quaternion", frame=fr)
    ctrl_actions[style] = act
rig.animation_data.action = ctrl_actions["cruise"]
for ob in list(scene.objects):
    ob.select_set(False)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "velodrome_pursuit_rig.blend"))
print("saved rig blend")

# ----------------------------------------------------------------- bake to plain FK for the game
rig.animation_data.action = None
DEFORM = [b.name for b in arm_data.bones if b.use_deform]
baked = {}
for style in STYLES:
    frames = []
    worst = 0
    for fr in range(LOOP + 1):
        apply_controls(style, fr)
        ep = evaluated_pose()
        frames.append({n: ep[n].matrix.copy() for n in DEFORM})
        for s in "LR":
            worst = max(worst, (ep[f"shin.{s}"].tail - ep[f"foot_tgt.{s}"].head).length,
                        (ep[f"forearm.{s}"].tail - ep[f"hand_tgt.{s}"].head).length)
    print(f"{style}: max IK reach error {worst*1000:.1f} mm")
    baked[style] = frames

for p in pb:
    for c in list(p.constraints): p.constraints.remove(c)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for b in list(arm_data.edit_bones):
    if not b.use_deform: arm_data.edit_bones.remove(b)
bpy.ops.object.mode_set(mode='OBJECT')
for a in list(ctrl_actions.values()): bpy.data.actions.remove(a)

order = []
def walk(b):
    order.append(b.name)
    for c in b.children: walk(c)
for b in arm_data.bones:
    if b.parent is None: walk(b)

GAME_ACTIONS = []
for style, frames in baked.items():
    act = bpy.data.actions.new(f"{style}_loop"); act.use_fake_user = True
    rig.animation_data.action = act
    prevq = {}
    for fr, mats in enumerate(frames):
        for n in order:
            b = arm_data.bones[n]
            if b.parent:
                local = b.parent.matrix_local.inverted() @ b.matrix_local
                basis = (mats[b.parent.name] @ local).inverted() @ mats[n]
            else:
                basis = b.matrix_local.inverted() @ mats[n]
            loc, q, _ = basis.decompose()
            if n in prevq and q.dot(prevq[n]) < 0: q.negate()
            prevq[n] = q
            pb[n].location = loc; pb[n].rotation_quaternion = q; pb[n].scale = (1, 1, 1)
            pb[n].keyframe_insert("location", frame=fr)
            pb[n].keyframe_insert("rotation_quaternion", frame=fr)
    GAME_ACTIONS.append(act)

ad = rig.animation_data
ad.action = None
for act in GAME_ACTIONS:
    tr = ad.nla_tracks.new(); tr.name = act.name
    st = tr.strips.new(act.name, 0, act); tr.mute = False
    try:
        if st.action_slot is None and len(act.slots): st.action_slot = act.slots[0]
    except AttributeError:
        pass

bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "velodrome_pursuit.glb"), export_format='GLB',
                          export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
                          export_yup=True, export_apply=False)
print("exported glb")

if os.environ.get("RIDER_SKIP_PREVIEW") == "1":
    print("PURSUIT_MODEL_BUILD_OK")
    raise SystemExit(0)

# Actual Blender render for visual review; exported GLB contains no studio props.
for track in rig.animation_data.nla_tracks:
    track.mute = True
rig.animation_data.action = next(a for a in GAME_ACTIONS if a.name.startswith("cruise"))
scene.frame_set(6)
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 1200
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new("StudioWorld")
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (0.16, 0.19, 0.24, 1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = 0.45
bpy.ops.mesh.primitive_plane_add(size=200)
ground = bpy.context.object
ground.name = "PreviewFloor"
m = bpy.data.materials.new("PreviewFloorMaterial"); m.diffuse_color = (0.055, 0.065, 0.085, 1)
ground.data.materials.append(m)
def aim(ob, target):
    ob.rotation_euler = (Vector(target) - ob.location).to_track_quat('-Z','Y').to_euler()
for loc, energy, size in [((3,-4,5),700,4),((-3,-1,3),500,3),((1,3,4),900,3)]:
    bpy.ops.object.light_add(type='AREA', location=loc)
    light=bpy.context.object; light.data.energy=energy; light.data.shape='DISK'; light.data.size=size
    aim(light,(0,-0.1,0.8))
bpy.ops.object.camera_add(location=(-3.6,-2.7,1.7))
camera=bpy.context.object; camera.data.type='ORTHO'; camera.data.ortho_scale=2.25
aim(camera,(0,-0.12,0.80)); scene.camera=camera
scene.render.filepath=os.path.join(OUT, 'pursuit_preview_threequarter.png')
bpy.ops.render.render(write_still=True)
camera.location=(-4.0,0.0,1.05); aim(camera,(0,-0.1,0.82)); camera.data.ortho_scale=2.35
scene.render.filepath=os.path.join(OUT, 'pursuit_preview_side.png')
bpy.ops.render.render(write_still=True)
print('PURSUIT_MODEL_BUILD_OK')
