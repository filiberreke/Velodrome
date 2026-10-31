"""
face_sdf.py – semi-realistic heads as signed distance fields (numpy only, runs inside Blender's Python).

Head space (metres): origin between the ears, x = person's left, y = up, z = forward (face).
  HeadSDF(params).sdf(P)          signed distance (negative inside) for points P (N,3)
  surface_nets(fn, lo, hi, h)     isosurface -> (verts, quads), no scikit-image needed
  HeadSDF.deform(P, key)          per-vertex displacement for the talking blend shapes
"""
import numpy as np

# ------------------------------------------------------------------ primitives
def _len(v):
    return np.sqrt((v * v).sum(-1))

def sd_ell(P, c, r, R=None):
    q = P - np.asarray(c, dtype=np.float32)
    if R is not None: q = q @ np.asarray(R, dtype=np.float32)
    r = np.asarray(r, dtype=np.float32)
    k0 = _len(q / r); k1 = _len(q / (r * r))
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)

def sd_cap(P, a, b, r1, r2=None):
    a = np.asarray(a, dtype=np.float32); b = np.asarray(b, dtype=np.float32)
    pa = P - a; ba = b - a
    h = np.clip((pa @ ba) / float(ba @ ba), 0.0, 1.0)
    r = r1 if r2 is None else r1 + (r2 - r1) * h
    return _len(pa - h[:, None] * ba) - r

def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)

def smax(a, b, k):
    return -smin(-a, -b, k)

def rot_x(deg):
    t = np.radians(deg); c, s = np.cos(t), np.sin(t)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]], dtype=np.float32)

def rot_z(deg):
    t = np.radians(deg); c, s = np.cos(t), np.sin(t)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], dtype=np.float32)

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)

def gauss(P, c, sigma):
    d = P - np.asarray(c, dtype=np.float32)
    return np.exp(-(d * d).sum(-1) / (2 * sigma * sigma))

# ------------------------------------------------------------------ head
DEFAULT = dict(
    W=1.0,            # skull width
    face_w=1.0,       # face (cheek/jaw) width
    face_len=1.0,     # vertical face length below the eyes
    jaw_w=1.0, chin=1.0, cheeks=1.0, neck=1.0,
    nose_len=1.0, nose_w=1.0, nose_tip=1.0,
    lips=1.0, mouth_w=1.0,
    brow=1.0, ears=1.0,
    eye_x=0.032, eye_y=0.006, eye_r=0.0122,
)

MOUTH_Y = -0.0625

class HeadSDF:
    def __init__(s, **kw):
        s.p = dict(DEFAULT); s.p.update(kw)
        p = s.p
        s.fl = p["face_len"]
        s.mouth_y = MOUTH_Y * s.fl
        s.eye = [np.array([sg * p["eye_x"], p["eye_y"], 0.0748], dtype=np.float32) for sg in (1, -1)]

    def fy(s, y):     # scale face heights below the eye line
        return y * s.fl if y < 0 else y

    def cranium(s, P):
        p = s.p; W = p["W"]
        d = sd_ell(P, (0, 0.020, -0.014), (0.0755 * W, 0.094, 0.100))
        d = smin(d, sd_ell(P, (0, 0.036, 0.028), (0.067 * W, 0.064, 0.072)), 0.03)
        return d

    def sdf(s, P):
        p = s.p; fy = s.fy; W, FW = p["W"], p["face_w"]
        d = s.cranium(P)
        # face mass, cheekbones, cheeks, jaw, chin
        d = smin(d, sd_ell(P, (0, fy(-0.026), 0.034), (0.064 * FW, 0.084 * s.fl, 0.073)), 0.03)
        for sg in (1, -1):
            d = smin(d, sd_ell(P, (sg * 0.047 * FW, -0.010, 0.050), (0.021, 0.017, 0.030)), 0.02)
            cf = p["cheeks"]
            d = smin(d, sd_ell(P, (sg * 0.040 * FW, fy(-0.044), 0.052), (0.028 * cf, 0.030 * cf, 0.030 * cf)), 0.034)
        jw = p["jaw_w"]
        d = smin(d, sd_ell(P, (0, fy(-0.079), 0.020), (0.060 * jw, 0.034, 0.070)), 0.028)
        ch = p["chin"]
        d = smin(d, sd_ell(P, (0, fy(-0.104), 0.075), (0.022 * ch, 0.018 * ch, 0.019 * ch)), 0.018)
        # neck
        nk = p["neck"]
        d = smin(d, sd_cap(P, (0, -0.075, -0.022), (0, -0.215, -0.032), 0.054 * nk), 0.022)
        # brow ridge
        b = p["brow"]
        d = smin(d, sd_cap(P, (-0.050, 0.025, 0.073), (0, 0.029, 0.0885 + 0.002 * (b - 1)), 0.0105 * b), 0.012)
        d = smin(d, sd_cap(P, (0.050, 0.025, 0.073), (0, 0.029, 0.0885 + 0.002 * (b - 1)), 0.0105 * b), 0.012)
        # eye sockets
        for e in s.eye:
            d = smax(d, -sd_ell(P, e + np.array([0, 0.001, 0.0132], dtype=np.float32), (0.0195, 0.0128, 0.0155)), 0.007)
        # nose
        nl, nw, nt = p["nose_len"], p["nose_w"], p["nose_tip"]
        tip = np.array([0, -0.027 * nl * s.fl, 0.1195 + 0.004 * (nl - 1)], dtype=np.float32)
        d = smin(d, sd_cap(P, (0, 0.012, 0.0935), tip + np.array([0, 0.002, 0], dtype=np.float32), 0.0060 * nw, 0.0090 * nw), 0.008)
        d = smin(d, sd_ell(P, tip + np.array([0, -0.004, -0.002]), (0.0110 * nw * nt, 0.0105 * nt, 0.0105 * nt)), 0.006)
        for sg in (1, -1):
            d = smin(d, sd_ell(P, (sg * 0.0125 * nw, tip[1] - 0.0105, 0.1065), (0.0085 * nw, 0.0072, 0.0090)), 0.005)
        for sg in (1, -1):
            d = smax(d, -sd_ell(P, (sg * 0.0072 * nw, tip[1] - 0.0165, 0.1125), (0.0036 * nw, 0.0022, 0.0052)), 0.002)
        # lips
        lp, mw = p["lips"], p["mouth_w"]
        my = s.mouth_y
        d = smin(d, sd_ell(P, (0, my + 0.0050, 0.0998), (0.0228 * mw, 0.0064 * lp, 0.0096)), 0.008)
        d = smin(d, sd_ell(P, (0, my - 0.0054, 0.0975), (0.0200 * mw, 0.0066 * lp, 0.0098)), 0.006)
        d = smax(d, -sd_cap(P, (0, my + 0.0115, 0.1115), (0, my + 0.020, 0.1095), 0.0020), 0.003)  # philtrum
        d = smax(d, -sd_ell(P, (0, my - 0.0175, 0.0985), (0.0155, 0.0042, 0.0065)), 0.006)       # chin groove
        d = smax(d, -sd_ell(P, (0, my, 0.101), (0.0255 * mw, 0.00115, 0.030)), 0.0012)             # mouth slit
        # ears
        e_ = p["ears"]
        for sg in (1, -1):
            R = rot_x(-12) @ rot_z(sg * 8)
            c = np.array([sg * (0.0755 * W + 0.0005), -0.006, -0.010], dtype=np.float32)
            d = smin(d, sd_ell(P, c, (0.0105, 0.031 * e_, 0.0195 * e_), R), 0.006)
            d = smax(d, -sd_ell(P, c + np.array([sg * 0.0095, -0.002, 0.002]), (0.0052, 0.017 * e_, 0.011 * e_), R), 0.004)
        return d

    # -------------------------------------------------------------- regions (on face centroids)
    def lip_mask(s, P):
        my = s.mouth_y; mw = s.p["mouth_w"]; lp = s.p["lips"]
        a = sd_ell(P, (0, my + 0.0050, 0.1040), (0.0245 * mw, 0.0074 * lp, 0.013)) < 0.0012
        b = sd_ell(P, (0, my - 0.0055, 0.1015), (0.0220 * mw, 0.0074 * lp, 0.013)) < 0.0012
        return (a | b) & (P[:, 2] > 0.094)

    def mouth_inner_mask(s, P):
        return (np.abs(P[:, 1] - s.mouth_y) < 0.0022) & (P[:, 2] < 0.1075) & (np.abs(P[:, 0]) < 0.027 * s.p["mouth_w"])

    def nostril_mask(s, P):
        tip_y = -0.027 * s.p["nose_len"] * s.fl
        m = np.zeros(len(P), bool)
        for sg in (1, -1):
            m |= sd_ell(P, (sg * 0.0072 * s.p["nose_w"], tip_y - 0.0165, 0.1125), (0.0040, 0.0026, 0.0056)) < 0.0005
        return m

    def hairline_y(s, P, recede=0.0):
        """y above which the scalp carries hair (buzz cut / hair base)."""
        x, z = np.abs(P[:, 0]), P[:, 2]
        front = 0.050 + recede + 0.55 * np.clip(z - 0.03, 0, None) + recede * 0.9 * np.clip(x / 0.045, 0, 1.2) ** 2
        side = np.where(x > 0.055, 0.004 + 0.4 * np.clip(z - 0.0, 0, None), 0.03)
        back = -0.058 + 0.0 * x
        t = smoothstep(-0.07, 0.0, z)
        base = back * (1 - t) + side * t
        t2 = smoothstep(0.02, 0.05, z)
        return base * (1 - t2) + front * t2

    def beard_mask(s, P, top=-0.034):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        jaw = (y < top) & (z > -0.028 + 0.25 * (y - top)) & (y > -0.135)
        mous = (y < s.mouth_y + 0.0135) & (y > s.mouth_y + 0.004) & (np.abs(x) < 0.027) & (z > 0.09)
        side = (np.abs(x) > 0.05) & (y < 0.0) & (y > -0.06) & (z > -0.02) & (z < 0.04)
        return (jaw | mous | side) & ~s.lip_mask(P)

    # -------------------------------------------------------------- talking blend shapes
    def jaw_weight(s, P):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        w = smoothstep(s.mouth_y + 0.0006, s.mouth_y - 0.0016, y)
        w *= smoothstep(-0.045, -0.010, z)
        w *= smoothstep(-0.175, -0.120, y)
        return w

    def deform(s, P, key):
        P = np.asarray(P, dtype=np.float32)
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        out = np.zeros_like(P)
        my = s.mouth_y; mw = s.p["mouth_w"]
        cx = 0.0245 * mw
        if key == "open":
            w = s.jaw_weight(P)
            a = np.radians(13.0) * w
            piv = np.array([0, -0.016, -0.018], dtype=np.float32)
            r = P - piv
            ny = r[:, 1] * np.cos(a) - r[:, 2] * np.sin(a)
            nz = r[:, 1] * np.sin(a) + r[:, 2] * np.cos(a)
            out[:, 1] = ny - r[:, 1]; out[:, 2] = nz - r[:, 2]
            up = smoothstep(my - 0.0006, my + 0.0016, y) * gauss(P, (0, my + 0.004, 0.104), 0.011)
            out[:, 1] += 0.0022 * up
            out[:, 2] -= 0.0008 * up
            for sg in (1, -1):   # corners stay narrower when open
                g = gauss(P, (sg * cx, my, 0.097), 0.008)
                out[:, 0] -= sg * 0.0025 * g
        elif key == "smile":
            for sg in (1, -1):
                g = gauss(P, (sg * cx, my, 0.097), 0.010)
                out += np.stack([sg * 0.0038 * g, 0.0068 * g, -0.0036 * g], 1)
                g = gauss(P, (sg * 0.036, -0.038, 0.085), 0.016)
                out += np.stack([sg * 0.0006 * g, 0.0026 * g, 0.0020 * g], 1)
                g = gauss(P, (sg * 0.032, -0.006, 0.090), 0.008)     # lower lid push (smiling eyes)
                out[:, 1] += 0.0012 * g
        elif key == "wide":
            for sg in (1, -1):
                g = gauss(P, (sg * cx, my, 0.097), 0.011)
                out += np.stack([sg * 0.0048 * g, 0.0008 * g, -0.0022 * g], 1)
            g = gauss(P, (0, my, 0.104), 0.012)
            out[:, 2] -= 0.0012 * g
        elif key == "round":
            for sg in (1, -1):
                g = gauss(P, (sg * cx, my, 0.097), 0.012)
                out += np.stack([-sg * 0.0065 * g, np.zeros_like(g), 0.0020 * g], 1)
            g = gauss(P, (0, my, 0.106), 0.013)
            out[:, 2] += 0.0040 * g
        elif key == "brow_up":
            w = smoothstep(0.004, 0.022, y) * smoothstep(0.085, 0.055, y) * smoothstep(0.045, 0.075, z)
            out[:, 1] += 0.0042 * w
            out[:, 2] += 0.0006 * w
        return out

# ------------------------------------------------------------------ hair volume (quiff)
class QuiffSDF:
    def __init__(s, head, **kw):
        s.h = head
        s.k = dict(lift=1.0, sweep=1.0, recede=0.0)
        s.k.update(kw)

    def sdf(s, P):
        h = s.h; lift = s.k["lift"]
        hl = h.hairline_y(P, s.k["recede"])
        fade = smoothstep(hl, hl + 0.022, P[:, 1])            # hair thins out towards the hairline (no helmet edge)
        d = h.cranium(P) - (0.0006 + fade * (0.0010 + 0.0028 * smoothstep(-0.01, 0.06, P[:, 1])))
        top = sd_ell(P, (0.003, 0.080, 0.012), (0.068 * h.p["W"], 0.050 * lift, 0.090))
        d = smin(d, top + (1 - fade) * 0.01, 0.02)
        front = sd_ell(P, (-0.006, 0.094 + 0.012 * lift, 0.062), (0.060, 0.034 * lift, 0.042), rot_x(-32) @ rot_z(6))
        d = smin(d, front, 0.016)
        # combed grooves running front -> back on the top
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        groove = 0.00008 * np.sin((x + 0.12 * z) * (2 * np.pi / 0.0085)) * smoothstep(0.05, 0.09, y)
        d = d + groove
        # only above the hairline
        m = h.hairline_y(P, s.k["recede"]) - y
        d = smax(d, m, 0.006)
        return d

# ------------------------------------------------------------------ surface nets
def surface_nets(fn, lo, hi, h, chunk=2_000_000):
    lo = np.asarray(lo, dtype=np.float32); hi = np.asarray(hi, dtype=np.float32)
    n = np.ceil((hi - lo) / h).astype(int) + 1
    xs = [lo[i] + np.arange(n[i], dtype=np.float32) * h for i in range(3)]
    G = np.stack(np.meshgrid(*xs, indexing="ij"), -1).reshape(-1, 3)
    V = np.empty(len(G), dtype=np.float32)
    for i in range(0, len(G), chunk):
        V[i:i + chunk] = fn(G[i:i + chunk])
    del G
    V = V.reshape(n)
    nx, ny, nz = n
    corners = [(i, j, k) for i in (0, 1) for j in (0, 1) for k in (0, 1)]
    cv = [V[i:nx - 1 + i, j:ny - 1 + j, k:nz - 1 + k] for i, j, k in corners]
    inside = sum((c < 0).astype(np.int8) for c in cv)
    active = (inside > 0) & (inside < 8)
    idx = -np.ones((nx - 1, ny - 1, nz - 1), dtype=np.int64)
    act = np.argwhere(active)
    idx[active] = np.arange(len(act))
    edges = [(a, b) for a in range(8) for b in range(a + 1, 8) if sum(abs(corners[a][t] - corners[b][t]) for t in range(3)) == 1]
    acc = np.zeros((len(act), 3), dtype=np.float32); cnt = np.zeros(len(act), dtype=np.float32)
    ai, aj, ak = act[:, 0], act[:, 1], act[:, 2]
    for a, b in edges:
        va = cv[a][ai, aj, ak]; vb = cv[b][ai, aj, ak]
        m = (va < 0) != (vb < 0)
        t = np.where(m, va / np.where(m, va - vb, 1.0), 0.0)
        pa = np.asarray(corners[a], dtype=np.float32); pb = np.asarray(corners[b], dtype=np.float32)
        acc += m[:, None] * (pa + (pb - pa) * t[:, None])
        cnt += m
    verts = lo + (act + acc / np.maximum(cnt, 1)[:, None]) * h
    quads = []
    for ax in range(3):
        o1, o2 = [a for a in range(3) if a != ax]
        sl0 = [slice(None)] * 3; sl1 = [slice(None)] * 3
        sl0[ax] = slice(0, n[ax] - 1); sl1[ax] = slice(1, n[ax])
        A = V[tuple(sl0)]; B = V[tuple(sl1)]
        crs = (A < 0) != (B < 0)
        # need 1 <= o1,o2 index <= n-2
        crs[(slice(None),) * 3] &= True
        e = np.argwhere(crs)
        e = e[(e[:, o1] >= 1) & (e[:, o1] <= n[o1] - 2) & (e[:, o2] >= 1) & (e[:, o2] <= n[o2] - 2)]
        flip = A[e[:, 0], e[:, 1], e[:, 2]] < 0
        def cell(d1, d2):
            c = e.copy(); c[:, o1] -= d1; c[:, o2] -= d2
            return idx[c[:, 0], c[:, 1], c[:, 2]]
        q = np.stack([cell(1, 1), cell(0, 1), cell(0, 0), cell(1, 0)], 1)
        q[flip] = q[flip][:, ::-1]
        if ax == 1: q = q[:, ::-1]
        quads.append(q)
    quads = np.concatenate(quads)
    quads = quads[(quads >= 0).all(1)]
    return verts, quads

def project(fn, P, iters=6, eps=1e-4, offset=0.0):
    """move points onto the iso-surface fn = offset"""
    P = np.asarray(P, dtype=np.float32).copy()
    for _ in range(iters):
        d = fn(P) - offset
        g = np.stack([(fn(P + np.array(e, dtype=np.float32) * eps) - fn(P - np.array(e, dtype=np.float32) * eps)) / (2 * eps)
                      for e in ((1, 0, 0), (0, 1, 0), (0, 0, 1))], 1)
        g /= np.maximum(_len(g), 1e-9)[:, None]
        P -= g * d[:, None]
    return P

def normal(fn, P, eps=1e-4):
    P = np.asarray(P, dtype=np.float32)
    g = np.stack([(fn(P + np.array(e, dtype=np.float32) * eps) - fn(P - np.array(e, dtype=np.float32) * eps)) / (2 * eps)
                  for e in ((1, 0, 0), (0, 1, 0), (0, 0, 1))], 1)
    return g / np.maximum(_len(g), 1e-9)[:, None]


def skin_weights(H, V, cfg):
    """smooth per-vertex weights for vertex colouring of the skin: dict name -> (N,) in 0..1"""
    V = np.asarray(V, dtype=np.float32)
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    my, mw, lp = H.mouth_y, H.p["mouth_w"], H.p["lips"]
    w = {}
    du = sd_ell(V, (0, my + 0.0046, 0.1008), (0.0232 * mw, 0.0060 * lp, 0.012))
    dl = sd_ell(V, (0, my - 0.0050, 0.0985), (0.0205 * mw, 0.0064 * lp, 0.012))
    w["lips"] = smoothstep(0.0016, -0.0008, np.minimum(du, dl)) * smoothstep(0.090, 0.096, z)
    if cfg.get("scalp") or cfg.get("quiff"):
        hl = H.hairline_y(V, cfg.get("recede", 0.0))
        w["scalp"] = smoothstep(-0.003, 0.004, y - hl) * smoothstep(0.112, 0.100, z)
    if cfg.get("beard"):
        top = -0.030
        jaw = smoothstep(top + 0.006, top - 0.010, y) * smoothstep(-0.032, -0.012, z - 0.25 * (y - top)) * smoothstep(-0.150, -0.118, y)
        mous = (smoothstep(my + 0.0175, my + 0.0115, y) * smoothstep(my + 0.0020, my + 0.0060, y)
                * smoothstep(0.031, 0.022, np.abs(x)) * smoothstep(0.086, 0.094, z))
        side = smoothstep(0.050, 0.060, np.abs(x)) * smoothstep(0.004, -0.008, y) * smoothstep(-0.03, -0.012, z) * smoothstep(0.045, 0.03, z)
        w["beard"] = np.clip(np.maximum(np.maximum(jaw, mous), side) - w["lips"] * 1.5, 0, 1)
    tip_y = -0.027 * H.p["nose_len"] * H.fl
    g = np.zeros(len(V), np.float32)
    for sg in (1, -1):
        g = np.maximum(g, gauss(V, (sg * 0.0072 * H.p["nose_w"], tip_y - 0.0170, 0.1110), 0.0022))
    w["nostril"] = g
    flush = gauss(V, (0, tip_y, 0.12), 0.010) * 0.6
    for sg in (1, -1):
        flush = np.maximum(flush, gauss(V, (sg * 0.042, -0.030, 0.075), 0.016) * 0.7)
    w["flush"] = flush
    return w
