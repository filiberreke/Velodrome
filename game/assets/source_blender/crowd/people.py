"""
people.py – procedural cartoon people in the same style as the Velodrome 250 rider
(soft egg head, painted-on avatar face, skin-modifier body, mitten hands, chunky shoes).

build_person(spec, lod) -> (MB, info)
  spec: dict(sex='m'|'f', pose=..., hair=..., top=..., bottom=..., acc=[...], beard=bool, glasses=bool)
  lod 0 = detailed, 1 = light (for far away stands)
Every face gets a region id (see vlib) so one shader can colour thousands of instances.
"""
import math
from mathutils import Vector, Matrix
import bmesh
from vlib import *

HEAD_SHAPE = (1.0, 1.07, 0.97)

def _n(v):
    return v.normalized()

# ------------------------------------------------------------------ proportions
def body_dims(sex):
    if sex == "f":
        return dict(hw=0.10, sw=0.175, thigh=0.43, shin=0.41, ua=0.26, fa=0.24, head_r=0.128,
                    r_pel=(0.165, 0.14), r_belly=(0.125, 0.11), r_chest=(0.15, 0.125), r_uch=(0.13, 0.10), r_neck=0.046,
                    r_hip=0.098, r_thigh=0.084, r_knee=0.054, r_calf=0.058, r_shin=0.042, r_ank=0.036,
                    r_sh=0.058, r_ua=0.048, r_elb=0.040, r_fa=0.039, r_wr=0.031, hand=0.9)
    return dict(hw=0.095, sw=0.20, thigh=0.45, shin=0.43, ua=0.28, fa=0.26, head_r=0.132,
                r_pel=(0.155, 0.13), r_belly=(0.145, 0.125), r_chest=(0.17, 0.135), r_uch=(0.155, 0.115), r_neck=0.056,
                r_hip=0.098, r_thigh=0.086, r_knee=0.058, r_calf=0.063, r_shin=0.046, r_ank=0.040,
                r_sh=0.07, r_ua=0.058, r_elb=0.046, r_fa=0.045, r_wr=0.035, hand=1.0)

ANK_Z = 0.085
SEAT_Z = 0.43

# ------------------------------------------------------------------ poses
def pose_joints(spec):
    """Return joint dict in Blender coordinates; origin = floor (under seat centre / between feet)."""
    sex = spec["sex"]; dm = body_dims(sex); pose = spec["pose"]
    seated = pose.startswith("seat_")
    J = dict(dm=dm, seated=seated)
    if seated:
        pelv = D(0, -0.06, 0.56); td = _n(D(0, -0.06, 1)); nd = _n(D(0, 0.05, 1)); face = _n(D(0, 1, -0.08))
        hip_z, hip_f = 0.535, -0.03
        ank = {1: D(0.14, 0.47, ANK_Z), -1: D(-0.14, 0.47, ANK_Z)}; knee_hint = D(0, 1, 0.6)
    else:
        hip_z = ANK_Z + (dm["thigh"] + dm["shin"]) * 0.985; hip_f = 0.0
        pelv = D(0, -0.01, hip_z + 0.03); td = _n(D(0, -0.02, 1)); nd = _n(D(0, 0.04, 1)); face = _n(D(0, 1, -0.05))
        ank = {1: D(0.12, 0.0, ANK_Z), -1: D(-0.12, 0.01, ANK_Z)}; knee_hint = D(0, 1, 0)
    hz = hip_z
    wr, hint, hdir = {}, {}, {}
    props = []
    def relaxed(s):
        if seated:
            wr[s] = D(s * 0.15, 0.27, 0.62); hint[s] = D(s * 0.3, -0.5, -0.8); hdir[s] = D(0, 1, -0.35)
        else:
            wr[s] = D(s * 0.27, 0.04, hz - 0.30); hint[s] = D(s * 0.25, -1, -0.2); hdir[s] = D(s * 0.1, 0.15, -1)
    def up_arm(s, x=0.30, f=0.10, z=None):
        wr[s] = D(s * x, f, (1.45 if seated else hz + 0.98) if z is None else z)
        hint[s] = D(s * 0.9, -0.1, -0.3); hdir[s] = D(s * 0.15, 0.1, 1)

    if pose in ("seat_relaxed", "stand_relaxed"):
        relaxed(1); relaxed(-1)
    elif pose in ("seat_clap", "stand_clap"):
        z = 0.93 if seated else hz + 0.30
        for s in (1, -1):
            wr[s] = D(s * 0.035, 0.30, z); hint[s] = D(s * 0.7, -0.2, -0.6); hdir[s] = _n(D(-s * 0.25, 0.35, 0.9))
    elif pose in ("seat_cheer1",):
        relaxed(1); up_arm(-1, 0.22, 0.12, 1.47)
    elif pose in ("seat_cheer2", "stand_cheer2"):
        up_arm(1); up_arm(-1)
    elif pose in ("seat_phone", "stand_phone"):
        z = 1.00 if seated else hz + 0.45
        for s in (1, -1):
            wr[s] = D(s * 0.05, 0.31, z); hint[s] = D(s * 0.6, -0.3, -0.7); hdir[s] = _n(D(-s * 0.1, 0.2, 1))
        props.append(("phone", D(0, 0.37, z + 0.07)))
    elif pose == "seat_lean":
        td = _n(D(0, 0.55, 0.83)); nd = _n(D(0, 0.15, 1)); face = _n(D(0, 1, 0.05))
        for s in (1, -1):
            wr[s] = D(s * 0.06, 0.50, 0.82); hint[s] = D(s * 0.5, 0, -0.85); hdir[s] = _n(D(-s * 0.4, 0.3, 0.6))
    elif pose == "seat_crossed":
        wr[1] = D(-0.10, 0.18, 0.88); hint[1] = D(0.5, -0.3, -0.8); hdir[1] = _n(D(-0.7, -0.15, 0.45))
        wr[-1] = D(0.10, 0.16, 0.84); hint[-1] = D(-0.5, -0.3, -0.8); hdir[-1] = _n(D(0.7, -0.15, 0.45))
    elif pose in ("seat_drink", "stand_drink"):
        relaxed(1)
        wr[-1] = D(-0.13, 0.24, 0.86 if seated else hz + 0.13); hint[-1] = D(-0.4, -0.3, -0.8); hdir[-1] = _n(D(0.1, 0.25, 1))
        props.append(("cup", -1))
    elif pose == "seat_point":
        relaxed(1)
        wr[-1] = D(-0.14, 0.60, 1.10); hint[-1] = D(-0.4, 0, -1); hdir[-1] = D(0, 1, 0.05)
        props.append(("finger", -1))
    elif pose == "stand_rail":
        pelv = pelv + D(0, -0.04, -0.02)
        td = _n(D(0, 0.42, 0.91)); nd = _n(D(0, 0.15, 1)); face = _n(D(0, 1, -0.1))
        for s in (1, -1):
            wr[s] = D(s * 0.17, 0.52, 1.07); hint[s] = D(s * 0.4, -0.2, -1); hdir[s] = _n(D(-s * 0.3, 1, -0.1))
    elif pose == "stand_talk":
        relaxed(1)
        wr[-1] = D(-0.24, 0.32, hz + 0.16); hint[-1] = D(-0.5, -0.3, -0.8); hdir[-1] = _n(D(-0.3, 1, 0.1))
    elif pose == "stand_hips":
        for s in (1, -1):
            wr[s] = D(s * 0.22, 0.0, hz + 0.05); hint[s] = D(s * 1, -0.5, 0.1); hdir[s] = _n(D(-s * 0.2, 0.4, -1))
    elif pose == "stand_clipboard":
        wr[1] = D(0.04, 0.27, hz + 0.20); hint[1] = D(0.6, -0.2, -0.8); hdir[1] = _n(D(-1, 0.4, 0.1))
        wr[-1] = D(-0.10, 0.30, hz + 0.27); hint[-1] = D(-0.6, -0.2, -0.8); hdir[-1] = _n(D(0.5, 0.6, 0.3))
        props.append(("clipboard", D(0.0, 0.33, hz + 0.27)))
    elif pose == "stand_camera":
        for s in (1, -1):
            wr[s] = D(s * 0.085, 0.22, hz + 0.55); hint[s] = D(s * 0.8, -0.2, -0.6); hdir[s] = _n(D(-s * 0.2, 0.4, 0.8))
        props.append(("camera", D(0, 0.27, hz + 0.63)))
    elif pose == "stand_counter":
        td = _n(D(0, 0.15, 1))
        for s in (1, -1):
            wr[s] = D(s * 0.22, 0.40, 1.00); hint[s] = D(s * 0.6, -0.4, -0.6); hdir[s] = D(0, 1, -0.15)
    elif pose == "stand_mechanic":
        td = _n(D(0, 0.35, 0.94)); nd = _n(D(0, 0.5, 0.85)); face = _n(D(0, 1, -0.45))
        wr[1] = D(0.10, 0.48, 1.00); hint[1] = D(0.6, -0.2, -0.7); hdir[1] = D(0, 1, -0.3)
        wr[-1] = D(-0.16, 0.44, 0.93); hint[-1] = D(-0.6, -0.2, -0.7); hdir[-1] = D(0, 1, -0.4)
        props.append(("wrench", -1))
    elif pose == "stand_flag_rest":   # bind pose for the rigged flag official
        wr[1] = D(0.22, 0.0, hz + 0.05); hint[1] = D(1, -0.5, 0.1); hdir[1] = _n(D(-0.2, 0.4, -1))
        wr[-1] = D(-0.22, 0.22, hz + 0.12); hint[-1] = D(-0.6, -0.4, -0.7); hdir[-1] = _n(D(0, 0.3, 1))
    else:
        raise ValueError(pose)

    # torso chain
    belly = pelv + td * 0.13; chest = belly + td * 0.15; uchest = chest + td * 0.12
    neck_t = uchest + nd * 0.11; head_r = dm["head_r"]; head_c = neck_t + nd * (head_r * 0.92)
    J.update(PELV=pelv, BELLY=belly, CHEST=chest, UCHEST=uchest, NECK_T=neck_t, HEAD_C=head_c, head_r=head_r,
             face=face, nd=nd, td=td, props=props)
    side_axis = _n(Vector((1, 0, 0)) - td * td.x)
    for s in (1, -1):
        hip = D(s * dm["hw"], hip_f, hip_z)
        knee, a = two_bone(hip, ank[s], dm["thigh"], dm["shin"], knee_hint + D(s * 0.08, 0, 0))
        toe = a + D(s * 0.02, 0.15, -0.03)
        sh = uchest + side_axis * (s * dm["sw"]) - td * 0.02
        elb, w = two_bone(sh, wr[s], dm["ua"], dm["fa"], hint[s])
        J[f"hip{s}"], J[f"knee{s}"], J[f"ank{s}"], J[f"toe{s}"] = hip, knee, a, toe
        J[f"sh{s}"], J[f"elb{s}"], J[f"wr{s}"], J[f"hdir{s}"] = sh, elb, w, _n(hdir[s])
    return J

# ------------------------------------------------------------------ bones (segments)
SIDE = {1: "L", -1: "R"}
def bone_segments(J):
    B = dict(pelvis=(J["PELV"], J["BELLY"]), spine=(J["BELLY"], J["CHEST"]), chest=(J["CHEST"], J["UCHEST"]),
             neck=(J["UCHEST"], J["NECK_T"]), head=(J["NECK_T"], J["HEAD_C"] + J["nd"] * J["head_r"]))
    side_axis = _n(Vector((1, 0, 0)) - J["td"] * J["td"].x)
    for s in (1, -1):
        n = SIDE[s]
        B[f"clavicle.{n}"] = (J["UCHEST"] + side_axis * (s * 0.03), J[f"sh{s}"])
        B[f"upper_arm.{n}"] = (J[f"sh{s}"], J[f"elb{s}"])
        B[f"forearm.{n}"] = (J[f"elb{s}"], J[f"wr{s}"])
        B[f"hand.{n}"] = (J[f"wr{s}"], J[f"wr{s}"] + J[f"hdir{s}"] * 0.09)
        B[f"thigh.{n}"] = (J[f"hip{s}"], J[f"knee{s}"])
        B[f"shin.{n}"] = (J[f"knee{s}"], J[f"ank{s}"])
        B[f"foot.{n}"] = (J[f"ank{s}"], J[f"toe{s}"])
    return B

BODY_BONES = ["pelvis", "spine", "chest", "neck"] + [f"{b}.{s}" for s in "LR" for b in
              ("clavicle", "upper_arm", "forearm", "hand", "thigh", "shin", "foot")]

def body_weights(verts, B):
    out = []
    for p in verts:
        cand = []
        for n in BODY_BONES:
            if p.x > 0.03 and n.endswith(".R"): continue
            if p.x < -0.03 and n.endswith(".L"): continue
            d, _ = seg_dist(p, *B[n]); cand.append((d, n))
        cand.sort(); dmin = cand[0][0] + 1e-4
        sel = [(d, n) for d, n in cand[:3] if d < dmin * 1.5 + 0.015]
        ws = {n: 1.0 / (d + 0.01) ** 4 for d, n in sel}
        tot = sum(ws.values()); out.append({n: w / tot for n, w in ws.items()})
    return out

# ------------------------------------------------------------------ clothing regions on the body
def bone_radius(n, t, dm):
    """approximate body radius (rx, ry) of the skin mesh along a bone"""
    def lerp(a, b):
        a = a if isinstance(a, tuple) else (a, a); b = b if isinstance(b, tuple) else (b, b)
        return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
    base = n.split(".")[0]
    table = dict(pelvis=(dm["r_pel"], dm["r_belly"]), spine=(dm["r_belly"], dm["r_chest"]), chest=(dm["r_chest"], dm["r_uch"]),
                 neck=(dm["r_neck"], dm["r_neck"]), clavicle=(dm["r_uch"][1], dm["r_sh"]), upper_arm=(dm["r_sh"], dm["r_elb"]),
                 forearm=(dm["r_elb"], dm["r_wr"]), hand=(dm["r_wr"], dm["r_wr"]), thigh=(dm["r_hip"], dm["r_knee"]),
                 shin=(dm["r_knee"], dm["r_ank"]), foot=(dm["r_ank"], dm["r_ank"]))
    return lerp(*table[base])

def body_region(c, B, spec, J):
    dm = J["dm"]; best = None
    for n in BODY_BONES:
        a, b = B[n]
        d, t = seg_dist(c, a, b)
        rx, ry = bone_radius(n, t, dm)
        if rx != ry:   # elliptical torso: x = width
            rel = c - (a + (b - a) * t)
            dn = math.sqrt((rel.x / rx) ** 2 + ((rel.y ** 2 + rel.z ** 2) / ry ** 2))
        else:
            dn = d / rx
        if best is None or dn < best[0]: best = (dn, t, n)
    d, t, n = best
    base = n.split(".")[0]
    top, bottom = spec.get("top", "tshirt"), spec.get("bottom", "jeans")
    long_sleeve = top in ("longsleeve", "hoodie", "blazer", "jacket")
    if base == "hand": return SKIN
    if base == "forearm":
        if long_sleeve: return TOP2 if t > 0.86 else TOP
        return SKIN
    if base == "upper_arm":
        if long_sleeve: return TOP
        if top == "tank": return SKIN
        return TOP2 if (top == "polo" and 0.40 < t < 0.50) else (TOP if t < 0.50 else SKIN)
    if base == "neck":
        if top in ("hoodie", "blazer", "jacket") and t < 0.35: return TOP
        return SKIN if t > 0.45 else TOP
    if base in ("thigh",):
        if bottom == "shorts": return BOTTOM if t < 0.62 else SKIN
        if bottom == "skirt": return BOTTOM if t < 0.55 else SKIN
        return BOTTOM
    if base == "shin":
        if bottom in ("shorts", "skirt"): return WHITE if t > 0.80 else SKIN   # socks
        return BOTTOM
    if base == "foot": return BOTTOM if bottom not in ("shorts", "skirt") else WHITE
    if base == "pelvis":
        if t < 0.42: return BOTTOM
        if t < 0.50 and bottom == "jeans" and not J["seated"]: return DARK      # belt
        if t < 0.50 and top == "hoodie": return TOP2         # waistband
        return TOP
    # spine / chest / clavicle: torso
    if top == "blazer":
        fwd = J["face"]
        rel = c - (B[n][0] + (B[n][1] - B[n][0]) * t)
        frontness = rel.normalized().dot(_n(Vector((fwd.x, fwd.y, 0)))) if rel.length > 1e-6 else 0
        if frontness > 0.6 and abs(c.x) < 0.035 and base in ("chest", "spine"): return WHITE
        if frontness > 0.45 and abs(c.x) < 0.075 and base in ("chest", "spine"): return TOP2
    if top == "tank" and base == "clavicle": return SKIN
    return TOP

# ------------------------------------------------------------------ head
def face_frame(J):
    f = J["face"]; up = Vector((0, 0, 1))
    side = _n(up.cross(f))          # person's left
    fup = _n(f.cross(side))
    return Matrix((side, fup, f)).transposed()

def head_shape_fn(co):
    co = Vector(co)
    co.x *= 1.0 - 0.13 * max(0.0, -co.y) ** 2
    co.z *= 1.0 - 0.06 * max(0.0, -co.y) ** 2
    return co

def L(lod, *opts):
    """pick a value by level of detail (0, 1, 2)"""
    return opts[min(lod, len(opts) - 1)]

class Head:
    def __init__(s, mb, J, lod):
        s.mb, s.J, s.lod = mb, J, lod
        s.C, s.R, s.M = J["HEAD_C"], J["head_r"], face_frame(J)
    def fp(s, x, y, z):
        return s.C + s.M @ Vector((x, y, z)) * s.R
    def surf(s, u, v, lift=0.0):
        a, b, c = HEAD_SHAPE
        d = Vector((u, v, 0.92)).normalized()
        t = 1.0 / math.sqrt((d.x / a) ** 2 + (d.y / b) ** 2 + (d.z / c) ** 2)
        p = d * t
        if p.y < 0: p = head_shape_fn(p)
        n = Vector((p.x / a ** 2, p.y / b ** 2, p.z / c ** 2)).normalized()
        tx = Vector((1, 0, 0)); tx = (tx - n * tx.dot(n)).normalized(); ty = n.cross(tx)
        R = Matrix((tx, ty, n)).transposed()
        return s.fp(*(p + n * lift)), s.M @ R
    def decal(s, u, v, w, h, depth, tag, lift=0.0, segs=(16, 8)):
        p, R = s.surf(u, v, lift)
        sphere(s.mb, p, (w * s.R, h * s.R, depth * s.R), tag, "head", segs, M=R)
    def line(s, pts, r, tag, lift=0.012, segs=6):
        tube(s.mb, [s.surf(u, v, lift)[0] for u, v in pts], r * s.R, tag, "head", segs, joints=False)
    def build(s, spec):
        lod = s.lod; R = s.R
        sphere(s.mb, s.C, tuple(k * R for k in HEAD_SHAPE), SKIN, "head", L(lod, (24, 14), (12, 8), (10, 6)), M=s.M, shape=head_shape_fn)
        for sg in (1, -1):
            s.decal(0.27 * sg, 0.04, 0.072, 0.11, 0.035, PUPIL, segs=L(lod, (10, 6), (6, 4), (4, 3)))
            if lod == 0:
                s.decal(0.29 * sg, 0.09, 0.03, 0.034, 0.02, WHITE, lift=0.028, segs=(6, 4))
                s.line([(0.17 * sg, 0.25), (0.27 * sg, 0.285), (0.38 * sg, 0.26)], 0.024, BROW)
                if spec["sex"] == "f":
                    s.line([(0.31 * sg, 0.13), (0.37 * sg, 0.15), (0.42 * sg, 0.12)], 0.016, PUPIL, lift=0.02)
            if lod < 2:
                p, Rm = s.surf(14.0 * sg, -0.02)
                sphere(s.mb, p, (0.15 * R, 0.21 * R, 0.08 * R), SKIN, "head", L(lod, (8, 5), (5, 3)), M=Rm)
        if lod == 0:
            s.decal(0.0, -0.13, 0.085, 0.075, 0.07, SKIN, segs=(8, 5))
            mouth = LIPS if spec["sex"] == "f" else MOUTH
            s.line([(-0.14, -0.33), (-0.07, -0.37), (0.0, -0.38), (0.07, -0.37), (0.14, -0.33)], 0.022 if spec["sex"] == "f" else 0.02, mouth)
        elif lod == 1:
            s.decal(0.0, -0.36, 0.13, 0.04, 0.03, MOUTH if spec["sex"] == "m" else LIPS, segs=(6, 3))
        if spec.get("glasses") and lod < 2:
            for sg in (1, -1):
                p, Rm = s.surf(0.27 * sg, 0.05, 0.10)
                torus(s.mb, p, Rm @ Vector((0, 0, 1)), 0.13 * R, 0.014 * R * 1.4, DARK, "head", L(lod, 12, 6), 4)
            s.line([(-0.13, 0.08), (0.0, 0.10), (0.13, 0.08)], 0.018, DARK, lift=0.12)
        self_hair(s, spec)

# ------------------------------------------------------------------ hair & headwear
def shell(hd, planes, scale, tag, thick=0.0, segs=None, deform=None):
    bm = bmesh.new()
    segs = segs or L(hd.lod, (28, 16), (14, 8), (10, 6))
    bmesh.ops.create_uvsphere(bm, u_segments=segs[0], v_segments=segs[1], radius=1.0)
    for n, d in planes:
        n = Vector(n); nn = n.normalized()
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=nn * (d / n.length), plane_no=nn, clear_inner=True)
    a, b, c = HEAD_SHAPE
    for v in bm.verts:
        co = v.co.copy()
        if deform: co = deform(co)
        if co.y < 0: co = head_shape_fn(co)
        v.co = Vector((co.x * a * scale[0], co.y * b * scale[1], co.z * c * scale[2]))
    T = Matrix.Translation(hd.C) @ hd.M.to_4x4() @ Matrix.Scale(hd.R, 4)
    bm.transform(T)
    if len(bm.verts) == 0:
        bm.free(); return
    if thick > 0:
        verts, faces = solid_shell_bm(bm, thick)
        hd.mb.add(verts, faces, tag, "head")
    else:
        hd.mb.add_bm(bm, tag, "head")

HAIRLINE_SHORT = [((0, 1, -0.55), -0.02)]
def self_hair(hd, spec):
    hair = spec.get("hair", "short"); lod = hd.lod; R = hd.R
    if hair in ("short", "buzz"):
        sc = 1.06 if hair == "short" else 1.035
        shell(hd, HAIRLINE_SHORT, (sc, sc + 0.02, sc), HAIR)
        if hair == "short" and lod == 0:   # tuft / fringe
            hd.decal(0.12, 0.62, 0.38, 0.16, 0.12, HAIR, lift=0.02, segs=(8, 5))
    elif hair == "curly":
        import random
        rnd = random.Random(7)
        n = L(lod, 26, 12, 8)
        for i in range(n):
            th = rnd.uniform(0, 2 * math.pi); ph = rnd.uniform(0.05, 1.25)
            dvec = Vector((math.sin(ph) * math.cos(th), math.cos(ph), math.sin(ph) * math.sin(th)))
            if dvec.z > 0.55 and dvec.y < 0.62: continue
            if dvec.y < -0.1: continue
            sphere(hd.mb, hd.fp(*(dvec * 1.02)), (0.30 * R if lod == 0 else 0.36 * R,) * 3, HAIR, "head", L(lod, (8, 5), (5, 3), (4, 3)))
    elif hair == "bob":
        shell(hd, [((0, 0.9, -1), -0.62), ((0, 1, -0.25), -0.62)], (1.10, 1.07, 1.08), HAIR)
    elif hair in ("ponytail", "bun"):
        shell(hd, [((0, 1, -0.50), -0.02), ((0, 1, 0), -0.55)], (1.06, 1.08, 1.06), HAIR)
        if hair == "ponytail":
            pts = [hd.fp(0, 0.30, -1.02), hd.fp(0, 0.05, -1.30), hd.fp(0, -0.45, -1.35), hd.fp(0, -0.90, -1.20)]
            tube(hd.mb, pts, [0.30 * R, 0.33 * R, 0.25 * R, 0.10 * R], HAIR, "head", L(lod, 10, 6, 4), joints=lod == 0)
            if lod < 2:
                torus(hd.mb, hd.fp(0, 0.24, -1.08), hd.M @ Vector((0, 0.3, -1)), 0.24 * R, 0.07 * R, ACCENT, "head", L(lod, 10, 6), 4)
        else:
            sphere(hd.mb, hd.fp(0, 0.78, -0.62), (0.40 * R,) * 3, HAIR, "head", L(lod, (10, 6), (6, 4), (5, 3)))
    elif hair == "long":
        shell(hd, [((0, 0.9, -1), -0.62), ((0, 1, -0.25), -0.70)], (1.08, 1.07, 1.08), HAIR)
        sphere(hd.mb, hd.fp(0, -0.75, -0.55), (0.95 * R, 1.05 * R, 0.42 * R), HAIR, "head", L(lod, (12, 8), (8, 5), (6, 4)), M=hd.M)
    elif hair == "cap":
        shell(hd, HAIRLINE_SHORT + [((0, -1, 0), -0.25)], (1.05, 1.07, 1.05), HAIR)
        shell(hd, [((0, 1, -0.3), 0.18)], (1.09, 1.10, 1.09), ACCENT)
        sphere(hd.mb, hd.fp(0, 0.40, 1.02), (0.62 * R, 0.07 * R, 0.48 * R), ACCENT, "head", L(lod, (12, 5), (8, 4), (6, 3)), M=hd.M,
               shape=lambda co: Vector((co.x, co.y, co.z * (1.0 if co.z > 0 else 0.25))))
        if lod == 0:
            sphere(hd.mb, hd.fp(0, 1.16, -0.05), (0.08 * R,) * 3, ACCENT, "head", (6, 4))
    if spec.get("beard"):
        shell(hd, [((0, -1, -0.35), 0.07), ((0, 0, 1), -0.25)], (1.04, 1.04, 1.06), HAIR)

# ------------------------------------------------------------------ whole person
def build_person(spec, lod=0, with_weights=False):
    J = pose_joints(spec); dm = J["dm"]; B = bone_segments(J)
    mb = MB()
    # --- body via skin modifier
    pts, rad, edges = [], [], []
    def P(p, r):
        pts.append(p); rad.append(r if isinstance(r, tuple) else (r, r)); return len(pts) - 1
    def chain(i0, plist):
        prev = i0
        for p, r in plist:
            i = P(p, r); edges.append((prev, i)); prev = i
        return prev
    pel = P(J["PELV"], dm["r_pel"])
    chain(pel, [(J["BELLY"], dm["r_belly"]), (J["CHEST"], dm["r_chest"])])
    uc = chain(len(pts) - 1, [(J["UCHEST"], dm["r_uch"])])
    if lod >= 2:
        chain(uc, [(J["NECK_T"], dm["r_neck"])])
    else:
        chain(uc, [(J["UCHEST"].lerp(J["NECK_T"], 0.5), dm["r_neck"]), (J["NECK_T"], dm["r_neck"] * 0.95)])
    for s in (1, -1):
        hip, knee, ank = J[f"hip{s}"], J[f"knee{s}"], J[f"ank{s}"]
        sh, elb, wr = J[f"sh{s}"], J[f"elb{s}"], J[f"wr{s}"]
        if lod >= 2:   # far away: only the joints, no intermediate rings
            chain(pel, [(hip, dm["r_hip"]), (knee, dm["r_knee"] * 1.15), (ank, dm["r_ank"])])
            chain(uc, [(sh, dm["r_sh"]), (elb, dm["r_elb"] * 1.1), (wr, dm["r_wr"])])
            continue
        chain(pel, [(hip, dm["r_hip"]), (hip.lerp(knee, 0.5), dm["r_thigh"]), (knee, dm["r_knee"]),
                    (knee.lerp(ank, 0.3), dm["r_calf"]), (knee.lerp(ank, 0.72), dm["r_shin"]), (ank, dm["r_ank"])])
        chain(uc, [(sh, dm["r_sh"]), (sh.lerp(elb, 0.5), dm["r_ua"]), (elb, dm["r_elb"]), (elb.lerp(wr, 0.5), dm["r_fa"]), (wr, dm["r_wr"])])
    bv, bf = skin_mesh(pts, rad, edges, pel, subsurf=1 if lod == 0 else 0)
    weights = body_weights(bv, B) if with_weights else [{"body": 1.0}] * len(bv)
    o = len(mb.v)
    mb.add(bv, bf, TOP, weights)
    for i, f in enumerate(bf):
        c = sum((bv[k] for k in f), Vector()) / len(f)
        mb.ft[o + i] = body_region(c, B, spec, J)
    # --- head, face, hair
    Head(mb, J, lod).build(spec)
    # --- hands (mittens) and shoes
    hs = dm["hand"]
    for s in (1, -1):
        n = SIDE[s]; wr, hd = J[f"wr{s}"], J[f"hdir{s}"]
        Mh = look_matrix(Vector(), hd, Vector((0, 0, 1)) if abs(hd.z) < 0.9 else Vector((0, -1, 0))).to_3x3()
        sphere(mb, wr + hd * 0.055 * hs, (0.042 * hs, 0.034 * hs, 0.064 * hs), SKIN, f"hand.{n}", L(lod, (10, 7), (6, 4), (5, 3)), M=Mh,
               shape=superellipse(0.85))
        if lod == 0:
            side_v = (Mh @ Vector((1, 0, 0))) * (-s)
            sphere(mb, wr + hd * 0.035 * hs + side_v * 0.035 * hs, (0.018 * hs, 0.018 * hs, 0.032 * hs), SKIN, f"hand.{n}", (6, 4), M=Mh)
        ank, toe = J[f"ank{s}"], J[f"toe{s}"]
        fwd = _n(Vector((toe.x - ank.x, toe.y - ank.y, 0)))
        Ms = Matrix((fwd.cross(Vector((0, 0, 1))), fwd, Vector((0, 0, 1)))).transposed()
        sole_z = 0.012
        c = Vector((ank.x, ank.y, 0)) + fwd * 0.045 + Vector((0, 0, sole_z + 0.045))
        sz = 0.92 if spec["sex"] == "f" else 1.0
        sphere(mb, c, (0.052 * sz, 0.125 * sz, 0.05), SHOE, f"foot.{n}", L(lod, (12, 8), (7, 4), (5, 3)), M=Ms, shape=superellipse(0.72))
        if lod == 0:
            sphere(mb, Vector((c.x, c.y, sole_z + 0.008)), (0.055 * sz, 0.128 * sz, 0.013), WHITE, f"foot.{n}", (12, 4), M=Ms,
                   shape=superellipse(0.6))
    # --- clothing extras & props
    acc = spec.get("acc", [])
    top = spec.get("top", "tshirt")
    neck_axis = _n(J["NECK_T"] - J["UCHEST"])
    if top == "polo" or top == "blazer":
        torus(mb, J["UCHEST"].lerp(J["NECK_T"], 0.38), neck_axis, dm["r_neck"] + 0.012, 0.016, TOP2 if top == "polo" else WHITE, "neck", L(lod, 14, 8, 6), L(lod, 5, 4, 3))
    if top == "hoodie":
        back = -_n(Vector((J["face"].x, J["face"].y, 0)))
        sphere(mb, J["UCHEST"].lerp(J["NECK_T"], 0.3) + back * 0.09, (0.13, 0.07, 0.09), TOP2, "chest", L(lod, (10, 6), (6, 4), (5, 3)),
               M=look_matrix(Vector(), back).to_3x3())
        if lod == 0:
            fwdh = _n(Vector((J["face"].x, J["face"].y, 0)))
            for s in (1, -1):
                a = J["UCHEST"] + fwdh * (dm["r_uch"][1] + 0.005) + Vector((s * 0.045, 0, -0.01))
                tube(mb, [a, a + Vector((0, 0, -0.13)) + fwdh * 0.01], 0.006, WHITE, "chest", 6)
    if "scarf" in acc:
        torus(mb, J["UCHEST"].lerp(J["NECK_T"], 0.25), neck_axis, dm["r_neck"] + 0.03, 0.03, ACCENT, "neck", L(lod, 14, 8, 6), L(lod, 6, 4, 3))
        fwdh = _n(Vector((J["face"].x, J["face"].y, 0)))
    if "lanyard" in acc:
        fwdh = _n(Vector((J["face"].x, J["face"].y, 0)))
        front = J["CHEST"] + fwdh * (dm["r_chest"][1] + 0.012)
        for s in (1, -1):
            a = J["UCHEST"].lerp(J["NECK_T"], 0.3) + Vector((s * dm["r_neck"], 0, 0)) + fwdh * 0.01
            tube(mb, [a, a.lerp(front, 0.5) + fwdh * 0.04, front + Vector((s * 0.01, 0, 0.03))], 0.006, ACCENT, "chest", 6)
        box(mb, front + Vector((0, 0, -0.03)) + fwdh * 0.004, (0.07, 0.09, 0.006), WHITE, "chest", M=look_matrix(Vector(), fwdh).to_3x3())
    if "apron" in acc:
        fwdh = _n(Vector((J["face"].x, J["face"].y, 0)))
        c = J["BELLY"].lerp(J["PELV"], 0.5) + fwdh * (dm["r_belly"][1] + 0.01) + Vector((0, 0, -0.08))
        box(mb, c, (0.30, 0.50, 0.025), ACCENT, "pelvis", M=look_matrix(Vector(), fwdh).to_3x3(), bevel=0.25)
        for s in (1, -1):
            tube(mb, [c + Vector((s * 0.12, 0, 0.24)), J["NECK_T"] + Vector((s * 0.05, 0, -0.03))], 0.008, ACCENT, "chest", 6)
    if spec.get("bottom") == "skirt" and not J["seated"]:
        waist = J["PELV"].lerp(J["BELLY"], 0.35)
        hem = Vector((0, J["PELV"].y, (J["hip1"].z + J["knee1"].z) * 0.5 - 0.06))
        cyl(mb, waist, hem, dm["r_pel"][0] + 0.005, BOTTOM, "pelvis", L(lod, 16, 10, 8), r2=dm["r_pel"][0] + 0.075)
    for prop in J["props"]:
        kind = prop[0]
        if kind == "phone":
            c = prop[1]; fwdh = _n(Vector((J["face"].x, J["face"].y, 0)))
            box(mb, c, (0.075, 0.15, 0.012), DARK, "hand.L", M=look_matrix(Vector(), fwdh).to_3x3(), bevel=0.2)
        elif kind == "cup":
            s = prop[1]; wr, hd = J[f"wr{s}"], J[f"hdir{s}"]
            c = wr + hd * 0.06 + Vector((0, 0, 0.01))
            cyl(mb, c - Vector((0, 0, 0.06)), c + Vector((0, 0, 0.065)), 0.033, WHITE, f"hand.{SIDE[s]}", L(lod, 10, 6), r2=0.04)
            if lod == 0:
                cyl(mb, c - Vector((0, 0, 0.01)), c + Vector((0, 0, 0.03)), 0.0375, ACCENT, f"hand.{SIDE[s]}", 10, r2=0.039)
        elif kind == "finger":
            s = prop[1]; wr, hd = J[f"wr{s}"], J[f"hdir{s}"]
            tube(mb, [wr + hd * 0.09, wr + hd * 0.16], 0.012, SKIN, f"hand.{SIDE[s]}", 8)
        elif kind == "clipboard":
            c = prop[1]; tilt = _n(D(0, -0.7, 1))
            M = look_matrix(Vector(), tilt, Vector((0, -1, 0))).to_3x3()
            box(mb, c, (0.23, 0.31, 0.012), METAL, "hand.L", M=M)
            box(mb, c + tilt * 0.008, (0.20, 0.26, 0.004), WHITE, "hand.L", M=M)
            box(mb, c + M @ Vector((0, 0.15, 0.012)), (0.08, 0.03, 0.015), DARK, "hand.L", M=M)
        elif kind == "camera":
            c = prop[1]; fwdh = _n(Vector((J["face"].x, J["face"].y, 0)))
            box(mb, c, (0.15, 0.11, 0.09), DARK, "hand.R", M=look_matrix(Vector(), fwdh).to_3x3(), bevel=0.2)
            cyl(mb, c + fwdh * 0.04, c + fwdh * 0.20, 0.045, DARK, "hand.R", 14, r2=0.05)
            cyl(mb, c + fwdh * 0.20, c + fwdh * 0.205, 0.05, METAL, "hand.R", 14)
        elif kind == "wrench":
            s = prop[1]; wr, hd = J[f"wr{s}"], J[f"hdir{s}"]
            a = wr + hd * 0.05; b = a + _n(hd + Vector((0, 0, -0.5))) * 0.20
            tube(mb, [a, b], 0.009, METAL, f"hand.{SIDE[s]}", 8)
            torus(mb, b, Vector((1, 0, 0)), 0.018, 0.007, METAL, f"hand.{SIDE[s]}", 10, 5)
    return mb, J, B
