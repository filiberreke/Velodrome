"""
build_infield_props.py – infield / fan-zone props for Velodrome 250, same soft cartoon style as the rider.
Output: ../out/infield_props.glb – one object per prop, origin on the ground, front facing +Z in Godot.
Materials are named (canopy_a, canopy_b, banner, truck_body, parasol_a, ...) so Godot can recolour them.
"""
import bpy, os, sys, math
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import importlib, vlib
importlib.reload(vlib)
from vlib import *
from mathutils import Vector, Matrix

OUT = os.environ.get("CROWD_OUT", os.path.join(HERE, "..", "out"))
COLORS = dict(
    metal=(0.78, 0.80, 0.82), dark=(0.13, 0.14, 0.16), wood=(0.72, 0.52, 0.33), wood_dark=(0.45, 0.30, 0.18),
    white=(0.96, 0.96, 0.95), tire=(0.09, 0.09, 0.10), glass=(0.55, 0.75, 0.85), canopy_a=(0.95, 0.35, 0.20),
    canopy_b=(0.98, 0.96, 0.92), banner=(0.10, 0.22, 0.45), truck_body=(0.30, 0.68, 0.72), truck_trim=(0.97, 0.80, 0.30),
    counter_cloth=(0.10, 0.22, 0.45), parasol_a=(0.95, 0.75, 0.15), parasol_b=(0.98, 0.97, 0.94), beachflag=(0.90, 0.20, 0.25),
    plant=(0.25, 0.55, 0.28), plant2=(0.35, 0.65, 0.30), soil=(0.30, 0.22, 0.16), bike_frame=(0.20, 0.45, 0.85),
    jersey_1=(0.95, 0.80, 0.10), jersey_2=(0.20, 0.55, 0.95), jersey_3=(0.92, 0.25, 0.25), jersey_4=(0.25, 0.70, 0.40),
    bulb=(1.0, 0.85, 0.55), menu=(0.12, 0.13, 0.15), chalk=(0.92, 0.92, 0.88), podium=(0.97, 0.97, 0.97),
    gold=(0.95, 0.75, 0.20), silver=(0.78, 0.80, 0.84), bronze=(0.78, 0.50, 0.28), cushion=(0.10, 0.22, 0.45),
    coffee=(0.35, 0.20, 0.12), fridge=(0.85, 0.88, 0.90), keg=(0.70, 0.72, 0.74), fries=(0.98, 0.82, 0.30),
    trash=(0.20, 0.45, 0.30), sign_face=(0.98, 0.98, 0.96),
)
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
FWD = D(0, 1, 0)   # front (customers) -> +Z in Godot

def mat_setup():
    for k, c in COLORS.items():
        kw = {}
        if k == "metal": kw = dict(rough=0.35, metal=0.7)
        if k == "bulb": kw = dict(emit=3.0)
        if k == "glass": kw = dict(rough=0.08, alpha=0.35)
        if k in ("canopy_a", "canopy_b", "parasol_a", "parasol_b", "banner", "counter_cloth", "beachflag"): kw = dict(rough=0.85)
        make_mat(k, c, **kw)

def bx(mb, center, size, tag, bevel=0.0, M=None):
    box(mb, center, size, tag, None, M=M, bevel=bevel)

def leg(mb, a, b, r=0.025, tag="metal", segs=10):
    cyl(mb, a, b, r, tag, None, segs)

# ------------------------------------------------------------------ props
def food_truck():
    mb = MB(); L, W, H = 4.6, 2.1, 2.55; z0 = 0.42
    # body (rounded van) – long axis along X, hatch side faces front (-Y)
    bx(mb, Vector((0, 0, z0 + H / 2)), (L, W, H), "truck_body", bevel=0.18)
    bx(mb, Vector((0, 0, z0 + H - 0.02)), (L * 0.96, W * 0.94, 0.10), "white", bevel=0.3)
    bx(mb, Vector((0, 0, z0 + 0.28)), (L * 1.002, W * 1.003, 0.20), "truck_trim", bevel=0.25)
    # cab front (towards +X)
    bx(mb, Vector((L / 2 - 0.05, 0, z0 + 1.55)), (0.20, W * 0.82, 0.75), "glass", bevel=0.25)
    for s in (1, -1):
        sphere(mb, Vector((L / 2 + 0.02, s * 0.70, z0 + 0.60)), (0.05, 0.13, 0.10), "white", None, (10, 6))
    # serving hatch (front side = -Y)
    hy = -W / 2 - 0.005
    bx(mb, Vector((-0.35, hy, z0 + 1.45)), (2.3, 0.04, 1.05), "dark")
    bx(mb, Vector((-0.35, hy - 0.22, z0 + 0.93)), (2.5, 0.42, 0.06), "wood", bevel=0.2)       # counter ledge
    for s in (-1, 1):
        cyl(mb, Vector((-0.35 + s * 1.2, hy - 0.40, z0 + 0.93)), Vector((-0.35 + s * 1.2, hy, z0 + 2.18)), 0.012, "metal", None, 6)
    # awning: tilted striped flap with scalloped edge
    n = 10
    for i in range(n):
        x0 = -0.35 - 1.3 + 2.6 * i / n; x1 = x0 + 2.6 / n
        tag = "canopy_a" if i % 2 == 0 else "canopy_b"
        M = Matrix.Rotation(math.radians(-25), 3, 'X')
        bx(mb, Vector(((x0 + x1) / 2, hy - 0.35, z0 + 2.12)), (x1 - x0, 0.80, 0.03), tag, M=M)
        sphere(mb, Vector(((x0 + x1) / 2, hy - 0.72, z0 + 1.93)), ((x1 - x0) / 2, 0.02, 0.08), tag, None, (10, 6),
               shape=lambda co: Vector((co.x, co.y, min(co.z, 0.0))))
    # menu board and items in the window
    bx(mb, Vector((0.80, hy - 0.02, z0 + 1.55)), (0.55, 0.03, 0.70), "menu")
    for k in range(4):
        bx(mb, Vector((0.80, hy - 0.04, z0 + 1.80 - k * 0.15)), (0.40, 0.01, 0.03), "chalk")
    for k in range(5):
        cyl(mb, Vector((-1.2 + k * 0.32, hy - 0.10, z0 + 0.96)), Vector((-1.2 + k * 0.32, hy - 0.10, z0 + 1.10)), 0.035, "fries", None, 8, r2=0.05)
    # wheels
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = Vector((sx * 1.45, sy * (W / 2 - 0.12), 0.36))
            cyl(mb, c - Y * 0.11, c + Y * 0.11, 0.36, "tire", None, 20)
            cyl(mb, c + Y * sy * 0.112, c + Y * sy * 0.12, 0.20, "metal", None, 14)
    # roof sign
    bx(mb, Vector((-0.3, 0, z0 + H + 0.35)), (2.4, 0.12, 0.55), "truck_trim", bevel=0.25)
    bx(mb, Vector((-0.3, -0.07, z0 + H + 0.35)), (2.2, 0.02, 0.42), "sign_face")
    return mb

def stall_tent(counter=True):
    mb = MB(); S = 3.0; h = 2.25; peak = 3.05
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg(mb, Vector((sx * S / 2, sy * S / 2, 0)), Vector((sx * S / 2, sy * S / 2, h)), 0.028)
            cyl(mb, Vector((sx * S / 2, sy * S / 2, 0)), Vector((sx * S / 2, sy * S / 2, 0.02)), 0.10, "dark", None, 10)
    # canopy: 8 striped gores (two per side)
    corners = [Vector((S / 2 + 0.05, -S / 2 - 0.05, h)), Vector((S / 2 + 0.05, S / 2 + 0.05, h)),
               Vector((-S / 2 - 0.05, S / 2 + 0.05, h)), Vector((-S / 2 - 0.05, -S / 2 - 0.05, h))]
    top = Vector((0, 0, peak))
    k = 0
    for i in range(4):
        a, b = corners[i], corners[(i + 1) % 4]
        m = (a + b) / 2
        for p, q in ((a, m), (m, b)):
            tag = "canopy_a" if k % 2 == 0 else "canopy_b"; k += 1
            mb.add([p, q, top], [[0, 1, 2]], tag, [{None: 1}] * 3, smooth=False)
            mb.add([q, p, top - Vector((0, 0, 0.02))], [[0, 1, 2]], tag, [{None: 1}] * 3, smooth=False)
    # valance with scallops on all sides
    for i in range(4):
        a, b = corners[i], corners[(i + 1) % 4]
        d = (b - a); nseg = 6
        out = Vector((d.y, -d.x, 0)).normalized()
        for j in range(nseg):
            p0 = a + d * (j / nseg); p1 = a + d * ((j + 1) / nseg)
            tag = "canopy_a" if j % 2 == 0 else "canopy_b"
            c = (p0 + p1) / 2 + Vector((0, 0, -0.12))
            M = look_matrix(Vector(), out).to_3x3()
            bx(mb, c, ((p1 - p0).length, 0.22, 0.02), tag, M=M)
            sphere(mb, c + Vector((0, 0, -0.11)), ((p1 - p0).length / 2, 0.06, 0.01), tag, None, (10, 5), M=M,
                   shape=lambda co: Vector((co.x, min(co.y, 0.0), co.z)))
    # back wall banner
    bx(mb, Vector((0, S / 2 - 0.05, h / 2 + 0.1)), (S - 0.1, 0.03, h - 0.2), "banner")
    if counter:
        bx(mb, Vector((0, -S / 2 + 0.45, 0.48)), (S - 0.35, 0.60, 0.96), "counter_cloth", bevel=0.12)
        bx(mb, Vector((0, -S / 2 + 0.45, 0.975)), (S - 0.25, 0.70, 0.05), "white", bevel=0.2)
        # back shelf with stock
        bx(mb, Vector((0, S / 2 - 0.40, 0.45)), (S - 0.5, 0.45, 0.90), "wood", bevel=0.1)
        for i in range(7):
            cyl(mb, Vector((-1.1 + i * 0.36, S / 2 - 0.40, 0.90)), Vector((-1.1 + i * 0.36, S / 2 - 0.40, 1.15)), 0.06, "jersey_%d" % (1 + i % 4), None, 10)
    return mb

def bar_counter():
    mb = MB(); L = 4.2
    bx(mb, Vector((0, 0, 0.55)), (L, 0.65, 1.10), "wood_dark", bevel=0.08)
    for i in range(8):
        bx(mb, Vector((-L / 2 + 0.26 + i * (L - 0.5) / 7, -0.33, 0.55)), (0.06, 0.02, 0.95), "wood")
    bx(mb, Vector((0, -0.05, 1.12)), (L + 0.15, 0.85, 0.06), "wood", bevel=0.25)
    bx(mb, Vector((0, -0.34, 0.25)), (L, 0.02, 0.10), "canopy_a")
    for i in range(5):    # beer taps
        x = -0.9 + i * 0.45
        cyl(mb, Vector((x, 0.05, 1.15)), Vector((x, 0.05, 1.45)), 0.025, "metal", None, 10)
        cyl(mb, Vector((x, 0.05, 1.45)), Vector((x, -0.05, 1.45)), 0.018, "metal", None, 8)
        cyl(mb, Vector((x, -0.05, 1.42)), Vector((x, -0.05, 1.62)), 0.018, "canopy_a" if i % 2 else "dark", None, 8)
    for i in range(4):    # cups on the bar
        x = -1.7 + i * 0.25
        cyl(mb, Vector((x, -0.2, 1.15)), Vector((x, -0.2, 1.29)), 0.035, "fries", None, 10, r2=0.042)
    # back fridge & kegs
    bx(mb, Vector((1.2, 1.1, 0.95)), (1.5, 0.6, 1.9), "fridge", bevel=0.1)
    bx(mb, Vector((1.2, 0.79, 1.0)), (1.3, 0.02, 1.6), "glass")
    for i in range(3):
        cyl(mb, Vector((-1.2 + i * 0.45, 1.0, 0.0)), Vector((-1.2 + i * 0.45, 1.0, 0.58)), 0.20, "keg", None, 16)
    # stools
    for i in range(4):
        x = -1.5 + i * 1.0
        leg(mb, Vector((x, -0.75, 0)), Vector((x, -0.75, 0.75)), 0.03)
        cyl(mb, Vector((x, -0.75, 0.75)), Vector((x, -0.75, 0.80)), 0.19, "cushion", None, 16)
        torus(mb, Vector((x, -0.75, 0.30)), Z, 0.15, 0.012, "metal", None, 16, 5)
        cyl(mb, Vector((x, -0.75, 0)), Vector((x, -0.75, 0.02)), 0.20, "metal", None, 14)
    return mb

def high_table():
    mb = MB()
    cyl(mb, Vector((0, 0, 1.06)), Vector((0, 0, 1.10)), 0.40, "white", None, 24)
    # stretch cover: waisted cone
    pts = [Vector((0, 0, 0.02)), Vector((0, 0, 0.55)), Vector((0, 0, 1.06))]
    cyl(mb, pts[0], pts[1], 0.33, "white", None, 20, r2=0.12, caps=False)
    cyl(mb, pts[1], pts[2], 0.12, "white", None, 20, r2=0.40, caps=False)
    cyl(mb, Vector((0, 0, 1.02)), Vector((0, 0, 1.06)), 0.402, "canopy_a", None, 24)
    return mb

def picnic_bench():
    mb = MB(); L = 2.0
    for dz, w, y in ((0.74, 0.70, 0.0), (0.44, 0.26, -0.62), (0.44, 0.26, 0.62)):
        for k in range(3 if w > 0.5 else 1):
            yy = y + (k - 1) * 0.235 if w > 0.5 else y
            bx(mb, Vector((0, yy, dz)), (L, (w / 3 if w > 0.5 else w) - 0.02, 0.05), "wood", bevel=0.2)
    for sx in (-1, 1):
        x = sx * (L / 2 - 0.25)
        for sy in (-1, 1):
            a = Vector((x, sy * 0.78, 0.0)); b = Vector((x, sy * 0.10, 0.72))
            cyl(mb, a, b, 0.035, "wood_dark", None, 8)
        bx(mb, Vector((x, 0, 0.41)), (0.06, 1.55, 0.06), "wood_dark")
    return mb

def parasol():
    mb = MB(); R = 1.5; h = 2.35; n = 8
    leg(mb, Vector((0, 0, 0.05)), Vector((0, 0, h + 0.35)), 0.025)
    cyl(mb, Vector((0, 0, 0)), Vector((0, 0, 0.12)), 0.28, "dark", None, 16)
    top = Vector((0, 0, h + 0.38))
    for i in range(n):
        a0 = 2 * math.pi * i / n; a1 = 2 * math.pi * (i + 1) / n
        p = Vector((R * math.cos(a0), R * math.sin(a0), h)); q = Vector((R * math.cos(a1), R * math.sin(a1), h))
        m = (p + q) / 2 * 1.0 + Vector((0, 0, 0.06))
        tag = "parasol_a" if i % 2 == 0 else "parasol_b"
        mb.add([p, m, top], [[0, 1, 2]], tag, [{None: 1}] * 3, smooth=False)
        mb.add([m, q, top], [[0, 1, 2]], tag, [{None: 1}] * 3, smooth=False)
        mb.add([m, p, top - Vector((0, 0, 0.02))], [[0, 1, 2]], tag, [{None: 1}] * 3, smooth=False)
        mb.add([q, m, top - Vector((0, 0, 0.02))], [[0, 1, 2]], tag, [{None: 1}] * 3, smooth=False)
        am = (a0 + a1) / 2
        Mt = Matrix((Vector((math.cos(am), math.sin(am), 0)), Vector((-math.sin(am), math.cos(am), 0)), Z)).transposed()
        sphere(mb, (p + q) / 2 + Vector((0, 0, -0.005)), (0.02, (q - p).length / 2, 0.08), tag, None, (10, 5), M=Mt,
               shape=lambda co: Vector((co.x, co.y, min(co.z, 0.0))))
    sphere(mb, top, (0.05,) * 3, "parasol_a", None, (8, 5))
    return mb

def beach_flag():
    mb = MB(); H = 3.2
    cyl(mb, Vector((0, 0, 0)), Vector((0, 0, 0.06)), 0.25, "dark", None, 14)
    # curved feather sail: strip of quads along a bent spine
    pts = []
    for i in range(13):
        t = i / 12
        pts.append(Vector((0.02 + 0.55 * math.sin(t * math.pi) ** 0.8 * (1 - 0.3 * t) + 0.25 * t ** 3, 0, 0.35 + t * (H - 0.35))))
    tube(mb, [Vector((0, 0, 0.05))] + pts, 0.012, "metal", None, 6, joints=False)
    verts, faces = [], []
    for i, p in enumerate(pts):
        t = i / 12
        w = 0.75 * math.sin(min(1.0, t * 1.15) * math.pi * 0.5) ** 0.6 * (1.0 - 0.75 * t ** 2.5)
        verts += [p, Vector((p.x - w, 0, p.z - 0.10 * t))]
    for i in range(12):
        faces.append([2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2])
    mb.add(verts, faces, "beachflag", [{None: 1}] * len(verts))
    mb.add([v + Vector((0, 0.006, 0)) for v in verts], [list(reversed(f)) for f in faces], "beachflag", [{None: 1}] * len(verts))
    stripe = [Vector((v.x * 0.55 + (pts[i // 2].x) * 0.45 if i % 2 else v.x, -0.003, v.z)) for i, v in enumerate(verts)]
    sv = []
    for i in range(13):
        a = verts[2 * i]; b = verts[2 * i + 1]
        sv += [a.lerp(b, 0.30) + Vector((0, -0.004, 0)), a.lerp(b, 0.42) + Vector((0, -0.004, 0))]
    mb.add(sv, faces, "white", [{None: 1}] * len(sv))
    sv2 = [v + Vector((0, 0.008, 0)) for v in sv]
    mb.add(sv2, [list(reversed(f)) for f in faces], "white", [{None: 1}] * len(sv2))
    return mb

def track_bike(mb, origin=Vector((0, 0, 0)), yaw=0.0, wheels=True):
    """parked track bike, long axis along X (front +X)"""
    R = Matrix.Rotation(yaw, 3, 'Z')
    def P(x, z, y=0.0): return origin + R @ Vector((x, y, z))
    WR = 0.335
    rear, front, bb = P(-0.40, WR), P(0.58, WR), P(0, 0.29)
    seat, ht_top, ht_bot = P(-0.152, 0.82), P(0.47, 0.84), P(0.51, 0.70)
    for a, b, r in ((bb, seat, 0.022), (seat, ht_top, 0.02), (bb, ht_bot, 0.025), (ht_bot, ht_top, 0.026)):
        tube(mb, [a, b], r, "bike_frame", None, 10)
    for s in (1, -1):
        tube(mb, [bb + R @ Vector((0, s * 0.03, 0)), rear + R @ Vector((0, s * 0.06, 0))], 0.013, "bike_frame", None, 8)
        tube(mb, [seat, rear + R @ Vector((0, s * 0.06, 0))], 0.011, "bike_frame", None, 8)
        tube(mb, [ht_bot, front + R @ Vector((0, s * 0.05, 0))], 0.015, "bike_frame", None, 8)
    tube(mb, [seat, P(-0.19, 0.95)], 0.014, "metal", None, 8)
    sphere(mb, P(-0.18, 0.965), (0.13, 0.06, 0.025), "dark", None, (12, 6), M=R)
    tube(mb, [ht_top, P(0.47, 0.885), P(0.58, 0.885)], 0.015, "metal", None, 8)
    for s in (1, -1):
        tube(mb, [P(0.58, 0.885, s * 0.19), P(0.66, 0.875, s * 0.19), P(0.70, 0.83, s * 0.19), P(0.67, 0.78, s * 0.19), P(0.57, 0.775, s * 0.19)], 0.012, "dark", None, 8)
    tube(mb, [P(0.58, 0.885, 0.19), P(0.58, 0.885, -0.19)], 0.012, "dark", None, 8)
    if wheels:
        for c in (rear, front):
            torus(mb, c, R @ Y, WR - 0.016, 0.016, "tire", None, 24, 6)
            torus(mb, c, R @ Y, WR - 0.042, 0.014, "dark", None, 24, 4)
            for k in range(6):
                a = math.pi * k / 3
                tube(mb, [c, c + R @ Vector((math.cos(a) * (WR - 0.05), 0, math.sin(a) * (WR - 0.05)))], 0.003, "metal", None, 4, ends=False)
    cyl(mb, bb + R @ Vector((0, -0.06, 0)), bb + R @ Vector((0, -0.052, 0)), 0.10, "metal", None, 24)
    return mb

def bike_work_stand():
    mb = MB()
    for a in (0, 2.1, 4.2):
        leg(mb, Vector((0, 0, 0.55)), Vector((0.55 * math.cos(a), 0.55 * math.sin(a), 0)), 0.018, "dark")
    leg(mb, Vector((0, 0, 0.5)), Vector((0, 0, 1.25)), 0.025, "dark")
    leg(mb, Vector((0, 0, 1.25)), Vector((-0.10, 0, 1.30)), 0.02, "canopy_a")
    track_bike(mb, Vector((0.05, 0, 0.35)), 0.0)
    return mb

def parked_bike_rack():
    mb = MB()
    bx(mb, Vector((0, 0, 0.03)), (2.4, 0.5, 0.06), "dark")
    for i in range(3):
        track_bike(mb, Vector((-0.8 + i * 0.8, 0.0, 0.0)), math.radians(90))
    return mb

def podium():
    mb = MB()
    for x, h, tag in ((0.0, 0.65, "podium"), (-1.05, 0.45, "podium"), (1.05, 0.30, "podium")):
        bx(mb, Vector((x, 0, h / 2)), (1.0, 0.9, h), tag, bevel=0.06)
        bx(mb, Vector((x, -0.452, h - 0.06)), (0.98, 0.01, 0.07), "banner")
    for x, h, tag in ((0.0, 0.65, "gold"), (-1.05, 0.45, "silver"), (1.05, 0.30, "bronze")):
        sphere(mb, Vector((x, -0.455, h * 0.45)), (0.12, 0.012, 0.12), tag, None, (16, 6))
    bx(mb, Vector((0, 0.9, 1.4)), (3.6, 0.08, 2.4), "banner")
    return mb

def string_light_pole():
    mb = MB()
    cyl(mb, Vector((0, 0, 0)), Vector((0, 0, 0.08)), 0.22, "dark", None, 14)
    leg(mb, Vector((0, 0, 0.08)), Vector((0, 0, 4.3)), 0.045, "dark", 12)
    sphere(mb, Vector((0, 0, 4.32)), (0.06,) * 3, "dark", None, (10, 6))
    return mb

def bulb():
    mb = MB()
    sphere(mb, Vector((0, 0, -0.05)), (0.045, 0.045, 0.06), "bulb", None, (8, 6))
    cyl(mb, Vector((0, 0, 0)), Vector((0, 0, 0.03)), 0.018, "dark", None, 6)
    return mb

def trash_bin():
    mb = MB()
    cyl(mb, Vector((0, 0, 0)), Vector((0, 0, 0.95)), 0.30, "trash", None, 20, r2=0.32)
    cyl(mb, Vector((0, 0, 0.95)), Vector((0, 0, 1.02)), 0.34, "dark", None, 20)
    bx(mb, Vector((0, -0.31, 0.6)), (0.25, 0.02, 0.25), "white", bevel=0.25)
    return mb

def planter():
    mb = MB()
    bx(mb, Vector((0, 0, 0.30)), (1.2, 0.6, 0.6), "wood", bevel=0.08)
    bx(mb, Vector((0, 0, 0.60)), (1.12, 0.52, 0.02), "soil")
    import random
    rnd = random.Random(3)
    for i in range(9):
        c = Vector((rnd.uniform(-0.45, 0.45), rnd.uniform(-0.18, 0.18), 0.72 + rnd.uniform(0, 0.25)))
        r = rnd.uniform(0.16, 0.26)
        sphere(mb, c, (r, r, r * 1.1), "plant" if i % 2 else "plant2", None, (10, 7))
    return mb

def merch_rack():
    mb = MB(); L = 2.0
    for sx in (-1, 1):
        leg(mb, Vector((sx * L / 2, 0, 0)), Vector((sx * L / 2, 0, 1.6)), 0.02)
        leg(mb, Vector((sx * L / 2, -0.3, 0)), Vector((sx * L / 2, 0.3, 0)), 0.02)
    leg(mb, Vector((-L / 2, 0, 1.6)), Vector((L / 2, 0, 1.6)), 0.015)
    for i in range(8):
        x = -0.85 + i * 0.243; tag = "jersey_%d" % (1 + i % 4)
        # jersey on a hanger: body + sleeves, facing front
        bx(mb, Vector((x, 0, 1.25)), (0.06, 0.42, 0.55), tag, bevel=0.25, M=Matrix.Rotation(math.radians(70), 3, 'Z'))
        for s in (1, -1):
            sphere(mb, Vector((x, s * 0.20, 1.46)) , (0.04, 0.10, 0.08), tag, None, (8, 5), M=Matrix.Rotation(math.radians(70), 3, 'Z'))
        torus(mb, Vector((x, 0, 1.55)), Y, 0.04, 0.005, "metal", None, 8, 4)
    return mb

def coffee_cart():
    mb = MB()
    bx(mb, Vector((0.35, 0, 0.85)), (0.95, 0.75, 0.70), "coffee", bevel=0.15)
    bx(mb, Vector((0.35, 0, 1.22)), (1.05, 0.85, 0.05), "wood", bevel=0.2)
    bx(mb, Vector((0.35, -0.38, 0.85)), (0.75, 0.01, 0.45), "sign_face")
    cyl(mb, Vector((0.55, 0.0, 1.24)), Vector((0.55, 0.0, 1.55)), 0.10, "metal", None, 14)
    for x in (0.0, 0.7):
        for s in (1, -1):
            torus(mb, Vector((x, s * 0.42, 0.25)), Y, 0.23, 0.025, "tire", None, 24, 6)
    track_bike(mb, Vector((-0.80, 0, 0.0)), 0.0, wheels=True)
    parasol_small = MB()
    leg(mb, Vector((0.35, 0.3, 1.22)), Vector((0.35, 0.3, 2.3)), 0.018)
    cyl(mb, Vector((0.35, 0.3, 2.15)), Vector((0.35, 0.3, 2.45)), 0.9, "parasol_a", None, 12, r2=0.02, caps=False)
    cyl(mb, Vector((0.35, 0.3, 2.45)), Vector((0.35, 0.3, 2.15)), 0.02, "parasol_b", None, 12, r2=0.9, caps=False)
    return mb

def crowd_barrier():
    mb = MB(); L = 2.4
    for sx in (-1, 1):
        leg(mb, Vector((sx * L / 2, 0, 0.08)), Vector((sx * L / 2, 0, 1.08)), 0.02)
        leg(mb, Vector((sx * L / 2, -0.30, 0.0)), Vector((sx * L / 2, 0.30, 0.0)), 0.02)
    for z in (0.10, 1.08):
        leg(mb, Vector((-L / 2, 0, z)), Vector((L / 2, 0, z)), 0.02)
    for i in range(16):
        x = -L / 2 + 0.07 + i * (L - 0.14) / 15
        leg(mb, Vector((x, 0, 0.1)), Vector((x, 0, 1.08)), 0.008, "metal", 6)
    bx(mb, Vector((0, -0.03, 0.75)), (L - 0.2, 0.01, 0.42), "banner")
    return mb

def officials_table():
    mb = MB(); L = 2.4
    bx(mb, Vector((0, 0, 0.74)), (L, 0.8, 0.05), "white", bevel=0.2)
    bx(mb, Vector((0, -0.38, 0.40)), (L, 0.02, 0.66), "counter_cloth")
    for i in range(3):   # laptops / timing screens
        x = -0.8 + i * 0.8
        bx(mb, Vector((x, 0.05, 0.775)), (0.38, 0.26, 0.02), "dark")
        bx(mb, Vector((x, 0.2, 0.92)), (0.38, 0.02, 0.26), "dark", M=Matrix.Rotation(math.radians(-15), 3, 'X'))
        bx(mb, Vector((x, 0.19, 0.92)), (0.34, 0.005, 0.22), "glass", M=Matrix.Rotation(math.radians(-15), 3, 'X'))
    for i in range(3):   # chairs behind
        x = -0.8 + i * 0.8
        bx(mb, Vector((x, 0.75, 0.45)), (0.45, 0.45, 0.05), "dark", bevel=0.2)
        bx(mb, Vector((x, 0.97, 0.75)), (0.45, 0.04, 0.55), "dark", bevel=0.2)
        for sx in (-1, 1):
            for sy in (-1, 1):
                leg(mb, Vector((x + sx * 0.19, 0.75 + sy * 0.19, 0)), Vector((x + sx * 0.19, 0.75 + sy * 0.19, 0.45)), 0.012)
    return mb

def tv_camera():
    mb = MB()
    for a in (0.3, 2.4, 4.5):
        leg(mb, Vector((0, 0, 1.15)), Vector((0.45 * math.cos(a), 0.45 * math.sin(a), 0)), 0.018, "dark")
    bx(mb, Vector((0, 0, 1.30)), (0.22, 0.48, 0.26), "dark", bevel=0.15)
    cyl(mb, Vector((0, -0.24, 1.32)), Vector((0, -0.55, 1.32)), 0.08, "dark", None, 16, r2=0.09)
    cyl(mb, Vector((0, -0.55, 1.32)), Vector((0, -0.56, 1.32)), 0.085, "glass", None, 16)
    bx(mb, Vector((0.14, 0.05, 1.42)), (0.06, 0.16, 0.12), "dark")
    return mb

PROPS = dict(food_truck=food_truck, stall_tent=stall_tent, team_tent=lambda: stall_tent(counter=False), bar_counter=bar_counter,
             high_table=high_table, picnic_bench=picnic_bench, parasol=parasol, beach_flag=beach_flag,
             bike_work_stand=bike_work_stand, bike_rack=parked_bike_rack, podium=podium, light_pole=string_light_pole,
             bulb=bulb, trash_bin=trash_bin, planter=planter, merch_rack=merch_rack, coffee_cart=coffee_cart,
             crowd_barrier=crowd_barrier, officials_table=officials_table, tv_camera=tv_camera)

def build_all(names=None):
    mat_setup()
    obs = {}
    for name, fn in PROPS.items():
        if names and name not in names: continue
        mb = fn()
        mb.vw = [{} for _ in mb.v]
        ob = build_object(mb, name, mode="materials", colors=COLORS)
        obs[name] = (ob, mb.tris())
    return obs

if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    obs = build_all()
    for k, (o, t) in obs.items():
        print(f"TRIS {k}: {t}")
    os.makedirs(OUT, exist_ok=True)
    if not os.environ.get("NO_EXPORT"):
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "infield_props.glb"), export_format='GLB', export_yup=True)
        print("exported infield_props.glb")
