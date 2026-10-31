"""
hero_head.py – builds a semi-realistic, rig-ready head for the commentators (Blender + numpy).

build_head(cfg) -> dict(verts, faces, tags, keys={name: offsets}, weights=[...])
All coordinates in head space (metres, x = person's left, y = up, z = forward), origin between the ears.
Tags are strings (material names without prefix). Blend shapes: open, wide, round, smile, blink_L, blink_R, brow_up.
"""
import math
import numpy as np
import bpy
from face_sdf import HeadSDF, QuiffSDF, surface_nets, project, normal, smoothstep, sd_ell, skin_weights

def lin_hex(h):
    c = np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])
    return np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)

KEYS = ["open", "wide", "round", "smile", "blink_L", "blink_R", "brow_up"]

class Geo:
    def __init__(s):
        s.v, s.f, s.t, s.deform, s.col = [], [], [], [], []   # deform: per-vertex 'skin' | 'static' | 'lid'; col: linear RGB
        s.lid_parts = []
    def add(s, verts, faces, tag, deform="skin", col=None):
        o = len(s.v)
        s.v.extend([tuple(map(float, p)) for p in verts])
        s.col.extend([tuple(map(float, c)) for c in col] if col is not None else [(1.0, 1.0, 1.0)] * len(verts))
        tags = tag if isinstance(tag, list) else [tag] * len(faces)
        for fc, tg in zip(faces, tags):
            s.f.append([o + int(k) for k in fc]); s.t.append(tg)
        s.deform.extend([deform] * len(verts))
        return o

# ------------------------------------------------------------------ small mesh helpers (numpy)
def ring_frame(t):
    t = t / np.linalg.norm(t)
    a = np.array([0, 1, 0]) if abs(t[1]) < 0.9 else np.array([1, 0, 0])
    u = np.cross(t, a); u /= np.linalg.norm(u); w = np.cross(t, u)
    return u, w

def tube(points, radii, segs=10, cap=True, flat=1.0):
    P = np.asarray(points, dtype=float); n = len(P)
    R = np.broadcast_to(np.asarray(radii, dtype=float), (n,))
    verts, faces = [], []
    prev_u = None
    for i in range(n):
        t = P[min(i + 1, n - 1)] - P[max(i - 1, 0)]
        u, w = ring_frame(t)
        if prev_u is not None and np.dot(u, prev_u) < 0: u, w = -u, -w
        prev_u = u
        for k in range(segs):
            a = 2 * math.pi * k / segs
            verts.append(P[i] + R[i] * (math.cos(a) * u + flat * math.sin(a) * w))
    for i in range(n - 1):
        for k in range(segs):
            k2 = (k + 1) % segs
            faces.append([i * segs + k, i * segs + k2, (i + 1) * segs + k2, (i + 1) * segs + k])
    if cap:
        for end, sgn in ((0, -1), (n - 1, 1)):
            c = len(verts); verts.append(P[end])
            for k in range(segs):
                k2 = (k + 1) % segs
                a, b = end * segs + k, end * segs + k2
                faces.append([c, b, a] if sgn < 0 else [c, a, b])
    return verts, faces

def uv_sphere(c, r, nu=24, nv=14, scale=(1, 1, 1)):
    verts, faces = [], []
    for j in range(nv + 1):
        th = math.pi * j / nv
        for i in range(nu):
            ph = 2 * math.pi * i / nu
            verts.append(np.asarray(c) + r * np.array([math.sin(th) * math.cos(ph) * scale[0], math.cos(th) * scale[1], math.sin(th) * math.sin(ph) * scale[2]]))
    for j in range(nv):
        for i in range(nu):
            i2 = (i + 1) % nu
            faces.append([j * nu + i, j * nu + i2, (j + 1) * nu + i2, (j + 1) * nu + i])
    return verts, faces

def cap(c, r, amax, axis=(0, 0, 1), nr=6, ns=24):
    """spherical cap around axis (angle amax) on a sphere centre c radius r"""
    ax = np.asarray(axis, float); ax /= np.linalg.norm(ax)
    u, w = ring_frame(ax)
    verts = [np.asarray(c) + ax * r]
    faces = []
    for j in range(1, nr + 1):
        a = amax * j / nr
        for i in range(ns):
            ph = 2 * math.pi * i / ns
            d = math.cos(a) * ax + math.sin(a) * (math.cos(ph) * u + math.sin(ph) * w)
            verts.append(np.asarray(c) + d * r)
    for i in range(ns):
        faces.append([0, 1 + i, 1 + (i + 1) % ns])
    for j in range(1, nr):
        for i in range(ns):
            a = 1 + (j - 1) * ns + i; b = 1 + (j - 1) * ns + (i + 1) % ns
            faces.append([a, a + ns, b + ns, b])
    return verts, faces

def grid_faces(nu, nv):
    return [[i * nv + j, i * nv + j + 1, (i + 1) * nv + j + 1, (i + 1) * nv + j] for i in range(nu - 1) for j in range(nv - 1)]

# ------------------------------------------------------------------ isosurface -> decimated mesh
def iso_mesh(fn, lo, hi, h, target_tris, name="iso"):
    v, q = surface_nets(fn, lo, hi, h)
    me = bpy.data.meshes.new(name)
    me.from_pydata(v.tolist(), [], q.tolist())
    me.validate(); me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    if tris > target_tris:
        m = ob.modifiers.new("dec", "DECIMATE"); m.ratio = target_tris / tris; m.use_symmetry = True; m.symmetry_axis = "X"
    dg = bpy.context.evaluated_depsgraph_get()
    em = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    import bmesh
    bm = bmesh.new(); bm.from_mesh(em)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(em); bm.free()
    verts = np.array([vv.co[:] for vv in em.vertices], dtype=np.float32)
    faces = [list(p.vertices) for p in em.polygons]
    bpy.data.objects.remove(ob); bpy.data.meshes.remove(me); bpy.data.meshes.remove(em)
    return verts, faces

# ------------------------------------------------------------------ eyes & lids
def eyelid(E, re, upper, edge_deg, nu=26, nv=7):
    rr = re + 0.0007
    phis = np.radians(np.linspace(-72, 72, nu))
    V = []
    edge = []
    for ph in phis:
        shape = math.cos(ph / math.radians(72) * math.pi / 2) ** 0.75
        if upper:
            e = math.radians(1.5) + (math.radians(edge_deg) - math.radians(1.5)) * shape
            ths = np.linspace(e, math.radians(82), nv)
        else:
            e = -(math.radians(2.5) + (math.radians(edge_deg) - math.radians(2.5)) * shape)
            ths = np.linspace(math.radians(-82), e, nv)
        for th in ths:
            V.append(E + rr * np.array([math.cos(th) * math.sin(ph), math.sin(th), math.cos(th) * math.cos(ph)]))
        edge.append(V[-nv] if upper else V[-1])
    F = grid_faces(nu, nv)
    if not upper: F = [f[::-1] for f in F]
    else: F = [f for f in F]
    return V, F, edge

def eye_parts(g, cfg, E, sg, blink):
    re = cfg["eye_r"]
    v, f = uv_sphere(E, re, 28, 16); g.add(v, f, "eye_white", "static")
    v, f = cap(E, re + 0.00025, math.radians(31), nr=5, ns=28); g.add(v, f, "iris", "static")
    v, f = cap(E, re + 0.00045, math.radians(13.5), nr=3, ns=20); g.add(v, f, "pupil", "static")
    v, f = cap(E, re + 0.0006, math.radians(4.0), axis=(0.22, 0.26, 1), nr=2, ns=10)
    g.add(v, f, "catchlight", "static")
    up_open, lo_open = cfg["lid_up"], cfg["lid_lo"]
    up = up_open + (-7.0 - up_open) * blink
    lo = lo_open + (9.0 - lo_open) * blink
    for upper, deg, tag in ((True, up, "skin"), (False, lo, "skin")):
        V, F, edge = eyelid(E, re, upper, deg)
        g.add(V, F, tag, "lid")
        # lid rim / lash line
        rim = np.asarray(edge) + (np.asarray(edge) - E) * 0.06
        tv, tf = tube(rim, 0.00105 if upper else 0.00075, 6, cap=True)
        g.add(tv, tf, "lash" if upper else "lid_rim", "lid")

# ------------------------------------------------------------------ main
def build_head(cfg, keystate=None):
    """keystate: dict for lids (blink_L/blink_R). Returns Geo with all parts (basis or blinked lids)."""
    ks = keystate or {}
    H = HeadSDF(**cfg["sdf"])
    g = Geo()
    # --- skin
    if "_skin" not in cfg:
        cfg["_skin"] = iso_mesh(H.sdf, (-0.108, -0.205, -0.128), (0.108, 0.150, 0.150), cfg.get("res", 0.0011), cfg.get("skin_tris", 26000), "skin")
    sv, sf = cfg["_skin"]
    C = np.array([np.mean(sv[f], 0) for f in sf], dtype=np.float32)
    tags = np.array(["skin"] * len(sf), dtype=object)
    tags[H.mouth_inner_mask(C)] = "mouth_inner"
    cols = cfg["colors"]
    w = skin_weights(H, sv, cfg)
    col = np.tile(lin_hex(cols["skin"]), (len(sv), 1))
    col = col * (1 - 0.18 * w["flush"][:, None]) + lin_hex(cols.get("flush", "d9876f")) * (0.18 * w["flush"][:, None])
    for name, amt in (("scalp", cfg.get("scalp_amt", 1.0)), ("beard", cfg.get("beard_amt", 1.0)), ("lips", 1.0), ("nostril", 0.85)):
        if name in w:
            k = (w[name] * amt)[:, None]
            col = col * (1 - k) + lin_hex(cols.get(name, "5a2e28")) * k
    g.add(sv, sf, list(tags), "skin", col)
    # --- mouth interior: dark bag, tongue, teeth
    my = H.mouth_y; mw = H.p["mouth_w"]
    v, f = uv_sphere((0, my - 0.003, 0.082), 1.0, 24, 12, (0.023 * mw, 0.013, 0.021)); g.add(v, f, "mouth_cavity", "skin")
    v, f = uv_sphere((0, my - 0.0085, 0.086), 1.0, 20, 10, (0.016 * mw, 0.0055, 0.016)); g.add(v, f, "tongue", "skin")
    for upper in (True, False):
        nu, nv = 22, 3
        V = []
        for i in range(nu):
            a = math.radians(-68 + 136 * i / (nu - 1))
            R = 0.0235 * mw
            for j in range(nv):
                y0 = (my + 0.0062, my - 0.0024) if upper else (my - 0.0014, my - 0.0085)
                y = y0[0] + (y0[1] - y0[0]) * j / (nv - 1)
                rr = R - 0.0005 * abs(math.sin(a))
                V.append((math.sin(a) * rr, y, 0.0800 + math.cos(a) * rr))
        F = grid_faces(nu, nv)
        # give the tooth row thickness: inner copy
        n0 = len(V)
        V += [(x * 0.86, y, 0.0800 + (z - 0.0800) * 0.86) for x, y, z in V]
        F += [[k + n0 for k in fc[::-1]] for fc in grid_faces(nu, nv)]
        for i in range(nu - 1):
            for j in (0, nv - 1):
                a_, b_ = i * nv + j, (i + 1) * nv + j
                F.append([a_, b_, b_ + n0, a_ + n0] if j else [b_, a_, a_ + n0, b_ + n0])
        g.add(V, F, "teeth", "skin")
    # --- eyes
    for E, sg, side in ((H.eye[0], 1, "L"), (H.eye[1], -1, "R")):
        eye_parts(g, cfg, E, sg, ks.get(f"blink_{side}", 0.0))
    # --- eyebrows (strands projected on the skin)
    for sg in (1, -1):
        xs = np.array([0.012, 0.020, 0.029, 0.038, 0.046, 0.053])
        ys = np.array([0.0215, 0.0250, 0.0270, 0.0272, 0.0255, 0.0220]) * cfg.get("brow_arch", 1.0) + cfg.get("brow_y", 0.0)
        th = np.array([1.0, 1.0, 0.95, 0.85, 0.65, 0.4]) * cfg.get("brow_thick", 1.0)
        for row, dy in enumerate((-0.0019, -0.0007, 0.0005, 0.0016)):
            P = np.stack([sg * xs, ys + dy * th, np.full(6, 0.10)], 1).astype(np.float32)
            P = project(H.sdf, P, offset=0.0004)
            v, f = tube(P, 0.00095 * th * (1.0 if row in (1, 2) else 0.8), 6, flat=0.55)
            g.add(v, f, "brow", "skin")
    # --- hair volume
    if cfg.get("quiff"):
        Q = QuiffSDF(H, **cfg["quiff"])
        if "_hair" not in cfg:
            cfg["_hair"] = iso_mesh(Q.sdf, (-0.100, -0.075, -0.125), (0.100, 0.150, 0.130), 0.0011, cfg.get("hair_tris", 22000), "hair")
        hv, hf = cfg["_hair"]
        Ch = np.array([np.mean(hv[f], 0) for f in hf], dtype=np.float32)
        hl = smoothstep(0.080, 0.118, hv[:, 1]) * smoothstep(-0.02, 0.06, hv[:, 2])
        streak = 0.5 + 0.5 * np.sin((hv[:, 0] + 0.1 * hv[:, 2]) * 2 * np.pi / 0.006) * np.sin(hv[:, 2] * 2 * np.pi / 0.031)
        k = np.clip(hl * (0.85 + 0.15 * streak), 0, 1)[:, None]
        hcol = lin_hex(cols["hair"]) * (1 - k) + lin_hex(cols["hair_light"]) * k
        g.add(hv, hf, "hair", "skin", hcol)
        cfg["_hair_fn"] = Q.sdf
    # --- glasses
    if cfg.get("glasses"):
        glasses(g, H)
    headset(g, H, cfg)
    return g, H

def outer_fn(H, cfg):
    hf = cfg.get("_hair_fn")
    if hf is None: return H.sdf
    return lambda P: np.minimum(H.sdf(P), hf(P))

def glasses(g, H):
    for sg in (1, -1):
        cx, cy, hw, hh, r = sg * 0.0335, 0.0095, 0.0255, 0.0170, 0.0065
        pts = []
        for k, a0 in enumerate((0, 90, 180, 270)):
            ccx = cx + (hw - r) * (1 if k in (0, 3) else -1)
            ccy = cy + (hh - r) * (1 if k in (0, 1) else -1)
            for m in range(7):
                a = math.radians(a0 + 90 * m / 6)
                pts.append((ccx + r * math.cos(a), ccy + r * math.sin(a)))
        P = np.array([(x, y, 0.1045 - 2.2 * x * x) for x, y in pts])
        upper = P[0:14]; lower = np.concatenate([P[14:], P[:1]])
        v, f = tube(upper, 0.0031, 10); g.add(v, f, "frame_black", "static")
        v, f = tube(lower, 0.0019, 8); g.add(v, f, "frame_tortoise", "static")
        # temple arm
        outer = np.array([sg * (0.0335 + 0.0255), cy + 0.007, 0.1045 - 2.2 * 0.059 ** 2])
        arm = [outer, (sg * 0.068, cy + 0.007, 0.088), (sg * 0.0815, cy + 0.006, 0.030), (sg * 0.0845, cy + 0.003, -0.012), (sg * 0.081, -0.010, -0.030)]
        v, f = tube(arm, 0.0016, 8); g.add(v, f, "frame_black", "static")
    br = [(-0.0085, 0.019, 0.1043), (0.0, 0.0205, 0.1062), (0.0085, 0.019, 0.1043)]
    v, f = tube(br, 0.0017, 8); g.add(v, f, "frame_black", "static")

def headset(g, H, cfg):
    fn = outer_fn(H, cfg)
    zb = cfg.get("band_z", -0.010)
    W = H.p["W"]
    cupx = 0.0755 * W + 0.0225
    # band: radial search from the head centre in the plane z = zb
    pts = []
    for a in np.radians(np.linspace(-62, 62, 25)):
        d = np.array([math.sin(a), math.cos(a), 0.0], dtype=np.float32)
        c = np.array([0, -0.004, zb], dtype=np.float32)
        lo_t, hi_t = 0.02, 0.25
        for _ in range(30):
            m = 0.5 * (lo_t + hi_t)
            if fn((c + d * m)[None])[0] < 0.0: lo_t = m
            else: hi_t = m
        pts.append(c + d * (hi_t + 0.0038))
    pts = [np.array([-cupx - 0.004, 0.030, zb])] + pts + [np.array([cupx + 0.004, 0.030, zb])]
    v, f = tube(pts, 0.0060, 12, flat=0.42); g.add(v, f, "headset", "static")
    v, f = tube(pts[8:-8], 0.0072, 12, flat=0.55); g.add(v, f, "headset_pad", "static")
    for sg in (1, -1):
        cin = np.array([sg * cupx, -0.006, zb + 0.002])
        cout = cin + np.array([sg * 0.019, 0, 0])
        ring = [cin + np.array([sg * 0.0, 0, 0]), cout]
        # cup body: short fat tube with caps
        v, f = tube([cin + np.array([sg * 0.004, 0, 0]), cout], [0.036, 0.033], 32); g.add(v, f, "headset", "static")
        v, f = tube([cin - np.array([sg * 0.002, 0, 0]), cin + np.array([sg * 0.006, 0, 0])], 0.034, 32); g.add(v, f, "headset_pad", "static")
        v, f = tube([cout, cout + np.array([sg * 0.002, 0, 0])], 0.020, 24); g.add(v, f, "headset_metal", "static")
        # yoke from band to cup
        v, f = tube([pts[0] if sg < 0 else pts[-1], cin + np.array([sg * 0.012, 0.030, 0])], 0.0032, 8); g.add(v, f, "headset", "static")
    sg = cfg["mic_side"]
    my = H.mouth_y
    boom = [(sg * (cupx + 0.016), -0.020, zb + 0.012), (sg * 0.082, -0.048, 0.060), (sg * 0.060, my - 0.006, 0.106),
            (sg * 0.040, my - 0.004, 0.1225)]
    v, f = tube(boom, 0.0019, 8); g.add(v, f, "headset", "static")
    v, f = uv_sphere(boom[-1], 0.0072, 16, 10, (1.25, 1, 1)); g.add(v, f, "mic_foam", "static")

def key_offsets(g, H, cfg, key, g_key=None):
    """per-vertex offsets for one blend shape"""
    V = np.asarray(g.v, dtype=np.float32)
    off = np.zeros_like(V)
    dmode = np.array([d if isinstance(d, str) else d[0] for d in g.deform])
    if key.startswith("blink"):
        Vk = np.asarray(g_key.v, dtype=np.float32)
        m = dmode == "lid"
        off[m] = Vk[m] - V[m]
        return off
    m = dmode == "skin"
    off[m] = H.deform(V[m], key)
    return off
