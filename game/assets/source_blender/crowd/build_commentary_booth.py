"""
build_commentary_booth.py – EuroMax Cycling commentary booth + two commentators for Velodrome 250.

Same procedural style as people.py / vlib.py (egg head, painted-on face, skin-modifier body, mitten hands),
but at "hero" detail for frontal close-ups: denser head and body, rigged, with face blend shapes for talking.

Run (Blender 5.2+):  blender --background --python build_commentary_booth.py   (needs face_sdf.py, hero_head.py, people.py, vlib.py
                     next to it and the PNGs in assets/commentary/textures, see make_euromax_textures.py)
Outputs (game/assets/commentary/):
  euromax_commentary_booth.glb   static booth (+ separate 'BoothGlass' node)
  commentator_links.glb          left presenter (glasses, buzz cut, stubble) – skeleton, blend shapes, idle/talk loops
  commentator_rechts.glb         right presenter (brown quiff)               – same rig
  commentary_booth_rig.blend     everything together, editable
Coordinates: origin = booth floor centre, booth front (track side) = Godot +Z, Y up, metres.
"""
from pathlib import Path
import sys, math, json, random
import bpy, bmesh
from mathutils import Vector, Matrix

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import people
from vlib import *

GAME = HERE.parents[2] if (HERE.parents[2] / "project.godot").exists() else HERE / "out_game"
OUT = GAME / "assets" / "commentary"
TEX = OUT / "textures"
for a in sys.argv:
    if a.startswith("--out="):
        OUT = Path(a[6:]); TEX = OUT / "textures"
OUT.mkdir(parents=True, exist_ok=True)

def hexc(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))

def _n(v):
    return v.normalized()

# =====================================================================================  materials
def tex_mat(name, image, rough=0.6, emit=0.0, metal=0.0):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name)
    try: m.use_nodes = True
    except Exception: pass
    nt = m.node_tree; b = nt.nodes.get("Principled BSDF")
    img = bpy.data.images.load(str(TEX / image), check_existing=True)
    t = nt.nodes.new("ShaderNodeTexImage"); t.image = img
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        nt.links.new(t.outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = emit
    return m

MATS = {}
def mat(name, hexcol, **kw):
    if name not in MATS:
        MATS[name] = make_mat(name, hexc(hexcol), **kw)
    return MATS[name]

class UMB(MB):
    """MB with optional explicit per-face UVs (list of (u, v) per corner)."""
    def __init__(s):
        super().__init__(); s.fuv = {}
    def quad_uv(s, pts, tag, bone=None, uvs=((0, 0), (1, 0), (1, 1), (0, 1))):
        s.add(pts, [[0, 1, 2, 3]], tag, bone, smooth=False)
        s.fuv[len(s.f) - 1] = list(uvs)

def make_object(mb, name, mats, collection, proj_uv=None):
    """tags are material names; mats maps name -> bpy material."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in mb.v], [], mb.f)
    me.validate(); me.update()
    if len(me.polygons) != len(mb.f):
        raise RuntimeError(f"{name}: validate removed faces")
    names = []
    for t in mb.ft:
        if t not in names: names.append(t)
    for t in names: me.materials.append(mats[t])
    uv = me.uv_layers.new(name="UVMap")
    for i, p in enumerate(me.polygons):
        p.material_index = names.index(mb.ft[i]); p.use_smooth = mb.fs[i]
        if i in getattr(mb, "fuv", {}):
            for k, li in enumerate(p.loop_indices): uv.data[li].uv = mb.fuv[i][k]
        elif proj_uv and mb.ft[i] in proj_uv:
            scale = proj_uv[mb.ft[i]]
            n = p.normal
            for li in p.loop_indices:
                co = me.vertices[me.loops[li].vertex_index].co
                uv.data[li].uv = ((co.y if abs(n.x) > abs(n.y) else co.x) / scale, co.z / scale)
        else:
            for li in p.loop_indices: uv.data[li].uv = (0.5, 0.5)
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
    return ob

# =====================================================================================  booth
FRONT = [(-1.95, 0.40), (-0.95, 0.95), (0.95, 0.95), (1.95, 0.40)]   # (x, f) outer line, viewer left -> right
BACK_F = -1.25
PRES_F, PRES_Z = 0.22, 0.08          # presenter rig origin offset (f, z) from the booth origin
Z_BOTTOM, Z_DESK, Z_LEDGE, Z_GLASS_TOP, Z_ROOF = -1.05, 0.72, 0.80, 2.30, 2.44

def seg_frame(p0, p1):
    a, b = Vector((p0[0], p0[1])), Vector((p1[0], p1[1]))
    d = (b - a); L_ = d.length; d.normalize()
    n = Vector((-d.y, d.x))       # outward (towards +f)
    return a, b, d, n, L_

def wall_box(mb, p0, p1, z0, z1, thick, tag, out=0.0, extend=0.0):
    """slab along segment p0->p1 (x,f), outer face offset `out` from the line, `thick` inward."""
    a, b, d, n, L_ = seg_frame(p0, p1)
    a = a - d * extend; b = b + d * extend
    o0 = n * out; o1 = n * (out - thick)
    P = lambda q, o, z: D(q.x + o.x, q.y + o.y, z)
    v = [P(a, o0, z0), P(b, o0, z0), P(b, o0, z1), P(a, o0, z1), P(a, o1, z0), P(b, o1, z0), P(b, o1, z1), P(a, o1, z1)]
    f = [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]
    bm = bmesh.new(); vs = [bm.verts.new(p) for p in v]
    for fc in f: bm.faces.new([vs[k] for k in fc])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mb.add_bm(bm, tag, None, smooth=False)

def panel_on(mb, p0, p1, zc, w, h, tag, out=0.003, uc=0.5):
    """textured quad on the outer face of a segment (u along segment, viewer left->right)."""
    a, b, d, n, L_ = seg_frame(p0, p1)
    c = a + d * (L_ * uc) + n * out
    pts = [D(*(c - d * w / 2), zc - h / 2), D(*(c + d * w / 2), zc - h / 2), D(*(c + d * w / 2), zc + h / 2), D(*(c - d * w / 2), zc + h / 2)]
    mb.quad_uv(pts, tag)

def offset_line(pts, dist):
    """offset polyline inward (towards -f) by dist with mitred joints"""
    segs = [seg_frame(pts[i], pts[i + 1]) for i in range(len(pts) - 1)]
    out = []
    for i, p in enumerate(pts):
        ns = [segs[k][3] for k in (i - 1, i) if 0 <= k < len(segs)]
        nn = sum(ns, Vector((0, 0))).normalized()
        cosh = nn.dot(ns[0])
        out.append(Vector(p) - nn * (dist / cosh))
    return out

def prism(mb, poly_xf, z0, z1, tag, smooth=False):
    """vertical extrusion of a convex-ish polygon given in (x,f), CCW seen from above"""
    bm = bmesh.new()
    bot = [bm.verts.new(D(p[0], p[1], z0)) for p in poly_xf]
    top = [bm.verts.new(D(p[0], p[1], z1)) for p in poly_xf]
    bm.faces.new(bot); bm.faces.new(top)
    n = len(poly_xf)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([bot[i], bot[j], top[j], top[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mb.add_bm(bm, tag, None, smooth=False)

def rbox(mb, c, size, tag, M=None, bevel=0.0):
    box(mb, c, size, tag, None, M=M, bevel=bevel)

def booth_floor_poly(inset=0.0):
    f = offset_line(FRONT, inset)
    return [(p.x, p.y) for p in f] + [(FRONT[-1][0] - inset, BACK_F + inset), (FRONT[0][0] + inset, BACK_F + inset)]

def build_booth(col):
    mb, glass = UMB(), UMB()
    T = 0.05
    # ---------------- floor, back wall, side walls, roof
    prism(mb, booth_floor_poly()[::-1], -0.05, 0.0, "floor")
    xl, xr = FRONT[0][0], FRONT[-1][0]
    wall_box(mb, (xr, BACK_F), (xl, BACK_F), Z_BOTTOM, Z_ROOF, 0.08, "navy", out=0.08)          # back wall (outer face out)
    for side, x in ((-1, xl), (1, xr)):
        p0, p1 = ((x, BACK_F), (x, FRONT[0][1])) if side < 0 else ((x, FRONT[-1][1]), (x, BACK_F))
        wall_box(mb, p0, p1, Z_BOTTOM, Z_LEDGE, T, "navy")
        wall_box(glass, p0, p1, Z_LEDGE + 0.02, Z_GLASS_TOP, 0.012, "glass", out=-0.02)
        panel_on(mb, p0, p1, -0.18, 0.95, 0.475, "logo_panel")
    roof = booth_floor_poly(-0.08)
    prism(mb, roof[::-1], Z_GLASS_TOP, Z_ROOF, "roof")
    # ceiling light panels (emissive) under the roof
    for x in (-0.55, 0.55):
        rbox(mb, D(x, 0.15, Z_GLASS_TOP - 0.012), (0.9, 0.35, 0.02), "light_panel")
    # ---------------- front fascia facets with logos + steel trim
    for i in range(3):
        p0, p1 = FRONT[i], FRONT[i + 1]
        wall_box(mb, p0, p1, Z_BOTTOM, Z_LEDGE, T, "navy")
        wall_box(mb, p0, p1, Z_LEDGE, Z_LEDGE + 0.035, 0.16, "steel", out=0.03, extend=0.02)   # ledge
        wall_box(mb, p0, p1, Z_BOTTOM - 0.04, Z_BOTTOM + 0.04, 0.07, "steel", out=0.015, extend=0.02)
        wall_box(mb, p0, p1, Z_GLASS_TOP - 0.06, Z_ROOF + 0.04, 0.10, "steel", out=0.02, extend=0.02)  # top rail
        wall_box(mb, p0, p1, Z_ROOF - 0.10, Z_ROOF + 0.02, 0.02, "navy_band", out=0.035)
        wall_box(glass, p0, p1, Z_LEDGE + 0.035, Z_GLASS_TOP - 0.06, 0.012, "glass", out=-0.035)
        a, b, d, n, L_ = seg_frame(p0, p1)
        if i == 1:
            panel_on(mb, p0, p1, -0.10, 1.70, 0.85, "logo_panel")
        else:
            panel_on(mb, p0, p1, -0.18, 0.95, 0.475, "logo_panel")
        panel_on(mb, p0, p1, Z_ROOF - 0.04, min(0.80, L_ * 0.6), 0.09, "logo_strip", out=0.037)
    # posts at the facet joints and back corners
    for p in FRONT + [(xl, BACK_F), (xr, BACK_F)]:
        rbox(mb, D(p[0], p[1] - 0.005, (Z_BOTTOM + Z_ROOF) / 2 - 0.01), (0.075, 0.075, Z_ROOF - Z_BOTTOM + 0.1), "steel")
    # ---------------- desk
    inner = offset_line(FRONT, T)
    back = offset_line(FRONT, 0.52)
    desk = [(p.x, p.y) for p in inner] + [(p.x, p.y) for p in back[::-1]]
    prism(mb, desk[::-1], Z_DESK - 0.035, Z_DESK, "desk")
    edge = offset_line(FRONT, 0.52)
    for i in range(3):
        wall_box(mb, (edge[i].x, edge[i].y), (edge[i + 1].x, edge[i + 1].y), Z_DESK - 0.045, Z_DESK + 0.004, 0.02, "steel", out=0.01, extend=0.0)
    # ---------------- back wall: logo, light strips, equipment rack
    wb = BACK_F + 0.002
    pts = lambda x0, x1, z0, z1: [D(x0, wb, z0), D(x1, wb, z0), D(x1, wb, z1), D(x0, wb, z1)]
    # wall faces +f (towards camera); viewer-left = -x
    mb.quad_uv(pts(-0.85, 0.85, 1.20, 2.05), "logo_panel")
    for x in (-1.55, -1.12, 1.12, 1.55):
        rbox(mb, D(x, BACK_F + 0.012, 1.25), (0.035, 0.02, 1.9), "led_strip")
    rbox(mb, D(-1.55, BACK_F + 0.25, 0.45), (0.5, 0.45, 0.9), "dark", bevel=0.06)
    for k in range(4):
        rbox(mb, D(-1.55, BACK_F + 0.476, 0.18 + k * 0.2), (0.44, 0.01, 0.12), "rack_front")
        for j in range(5):
            rbox(mb, D(-1.72 + j * 0.06, BACK_F + 0.483, 0.20 + k * 0.2), (0.012, 0.006, 0.012), "led_green" if (j + k) % 3 else "led_red")
    # ---------------- lighting truss with spots aimed at the presenters
    tz, tf = Z_GLASS_TOP - 0.16, 0.55
    cyl(mb, D(-1.6, tf, tz), D(1.6, tf, tz), 0.025, "steel", None, 12)
    cyl(mb, D(-1.6, tf + 0.12, tz), D(1.6, tf + 0.12, tz), 0.025, "steel", None, 12)
    for x in (-1.6, -0.8, 0.0, 0.8, 1.6):
        cyl(mb, D(x, tf, tz), D(x, tf, Z_GLASS_TOP), 0.015, "steel", None, 8)
        cyl(mb, D(x, tf + 0.12, tz), D(x, tf + 0.12, Z_GLASS_TOP), 0.015, "steel", None, 8)
    for x, aim in ((-1.05, -0.52), (-0.25, -0.52), (0.25, 0.52), (1.05, 0.52)):
        top = D(x, tf + 0.06, tz - 0.03)
        target = D(aim, 0.12, 1.2)
        axis = _n(target - top)
        cyl(mb, top + axis * 0.04, top + axis * 0.22, 0.065, "black", None, 18, r2=0.075)
        cyl(mb, top + axis * 0.215, top + axis * 0.225, 0.066, "spot_lens", None, 18)
        cyl(mb, top, top + axis * 0.06, 0.012, "steel", None, 8)
    # ---------------- monitors (screens face the presenters, logo on the back towards camera)
    for x, f, yaw in ((0.0, 0.70, 0.0), (-1.18, 0.52, math.radians(-29)), (1.18, 0.52, math.radians(29))):
        Mz = Matrix.Rotation(yaw, 3, 'Z')
        tilt = Matrix.Rotation(math.radians(-14), 3, 'X')   # lean back towards presenters
        R3 = Mz @ tilt
        c = D(x, f, Z_DESK + 0.20)
        rbox(mb, D(x, f, Z_DESK + 0.005), (0.22, 0.16, 0.012), "black", M=Mz, bevel=0.15)
        cyl(mb, D(x, f, Z_DESK), D(x, f, Z_DESK + 0.11), 0.018, "black", None, 10)
        rbox(mb, c, (0.50, 0.035, 0.31), "black", M=R3, bevel=0.06)
        # screen (towards -f = presenters): Blender +Y is person backwards
        sc = c + R3 @ Vector((0, 0.0185, 0))
        ux, uz = R3 @ Vector((1, 0, 0)), R3 @ Vector((0, 0, 1))
        w, h = 0.47, 0.28
        mb.quad_uv([sc + ux * (w / 2) - uz * (h / 2), sc - ux * (w / 2) - uz * (h / 2), sc - ux * (w / 2) + uz * (h / 2), sc + ux * (w / 2) + uz * (h / 2)], "screen")
        bc = c - R3 @ Vector((0, 0.0185, 0))
        w, h = 0.30, 0.15
        mb.quad_uv([bc - ux * (w / 2) - uz * (h / 2), bc + ux * (w / 2) - uz * (h / 2), bc + ux * (w / 2) + uz * (h / 2), bc - ux * (w / 2) + uz * (h / 2)], "logo_panel")
    # ---------------- chairs
    for x in (-0.52, 0.52):
        base = D(x, PRES_F - 0.06, 0)
        for k in range(5):
            a = math.tau * k / 5
            cyl(mb, base + Vector((0, 0, 0.07)), base + Vector((math.cos(a) * 0.30, math.sin(a) * 0.30, 0.05)), 0.016, "black", None, 8)
            sphere(mb, base + Vector((math.cos(a) * 0.30, math.sin(a) * 0.30, 0.03)), (0.028,) * 3, "black", None, (8, 5))
        torus(mb, base + Vector((0, 0, 0.24)), Vector((0, 0, 1)), 0.21, 0.012, "steel", None, 32, 8)
        for k in range(3):
            a = math.tau * k / 3 + 0.5
            cyl(mb, base + Vector((0, 0, 0.30)), base + Vector((math.cos(a) * 0.21, math.sin(a) * 0.21, 0.24)), 0.009, "steel", None, 8)
        cyl(mb, base + Vector((0, 0, 0.06)), base + Vector((0, 0, 0.48)), 0.028, "steel", None, 12)
        rbox(mb, D(x, PRES_F - 0.04, 0.485), (0.50, 0.48, 0.07), "chair", bevel=0.25)
        rbox(mb, D(x, PRES_F - 0.36, 0.88), (0.46, 0.07, 0.52), "chair", M=Matrix.Rotation(math.radians(-8), 3, 'X'), bevel=0.25)
        cyl(mb, D(x, PRES_F - 0.25, 0.49), D(x, PRES_F - 0.35, 0.64), 0.02, "black", None, 8)
    # ---------------- desk props
    for x, f in ((-0.98, 0.62), (0.90, 0.66)):
        cyl(mb, D(x, f, Z_DESK), D(x, f, Z_DESK + 0.17), 0.032, "bottle", None, 16)
        cyl(mb, D(x, f, Z_DESK + 0.17), D(x, f, Z_DESK + 0.20), 0.032, "bottle", None, 16, r2=0.016)
        cyl(mb, D(x, f, Z_DESK + 0.20), D(x, f, Z_DESK + 0.222), 0.017, "bottle_cap", None, 12)
        rbox(mb, D(x, f, Z_DESK + 0.09), (0.066, 0.066, 0.06), "bottle_label", bevel=0.45)
    for x in (-0.52, 0.52):
        rbox(mb, D(x + 0.22, 0.55, Z_DESK + 0.004), (0.21, 0.297, 0.006), "paper", M=Matrix.Rotation(math.radians(8 if x < 0 else -8), 3, 'Z'))
        rbox(mb, D(x - 0.24, 0.60, Z_DESK + 0.025), (0.16, 0.12, 0.05), "dark", bevel=0.2)   # talkback unit
        for j in range(3):
            cyl(mb, D(x - 0.29 + j * 0.05, 0.62, Z_DESK + 0.045), D(x - 0.29 + j * 0.05, 0.62, Z_DESK + 0.056), 0.012, "led_red" if j == 0 else "rack_front", None, 10)
    mats = {
        "navy": mat("navy", "182968", rough=0.45), "navy_band": mat("navy_band", "182968", rough=0.45),
        "steel": mat("steel", "c9ced4", rough=0.28, metal=0.85), "roof": mat("roof", "1b1d22", rough=0.8),
        "floor": mat("floor", "3a3d44", rough=0.9), "desk": mat("desk", "2b2e35", rough=0.4),
        "dark": mat("dark", "202227", rough=0.6), "black": mat("black", "121316", rough=0.45),
        "chair": mat("chair", "18191c", rough=0.7), "light_panel": mat("light_panel", "f4f6ff", emit=3.0),
        "led_strip": mat("led_strip", "8fb8ff", emit=2.0), "rack_front": mat("rack_front", "2e3138", rough=0.5),
        "led_green": mat("led_green", "39ff7a", emit=2.0), "led_red": mat("led_red", "ff3b3b", emit=2.0),
        "spot_lens": mat("spot_lens", "fff4dc", emit=4.0), "paper": mat("paper", "f4f2ec", rough=0.9),
        "bottle": mat("bottle", "bfe0f2", rough=0.15), "bottle_cap": mat("bottle_cap", "2a5bd7", rough=0.4),
        "bottle_label": mat("bottle_label", "d61e2d", rough=0.5),
        "logo_panel": tex_mat("euromax_logo_panel", "euromax_cycling_panel.png", rough=0.45),
        "logo_strip": tex_mat("euromax_logo_panel", "euromax_cycling_panel.png", rough=0.45),
        "screen": tex_mat("monitor_screen", "monitor_live_timing.png", rough=0.2, emit=1.2),
        "glass": mat("glass", "d8e8f4", rough=0.04, alpha=0.14),
    }
    ob = make_object(mb, "Booth", mats, col)
    ob_g = make_object(glass, "BoothGlass", mats, col)
    return ob, ob_g

# =====================================================================================  presenters
import numpy as np
import hero_head as hh

SHAPE_KEYS = hh.KEYS     # open, wide, round, smile, blink_L, blink_R, brow_up
SHIRT_BTN, LANYARD, LANYARD2, POLO_G, POLO_W = 20, 21, 22, 23, 24

HEAD_COMMON = dict(eye_r=0.0126, res=0.0011, skin_tris=30000, hair_tris=24000)
CHARS = {
    # left: shaved head, rectangular black/tortoise glasses, light blue eyes, full face, light stubble, bicycle-print shirt
    "links": dict(
        x=-0.52, mic_side=1, print=True, rolled=False,
        dims=dict(sw=0.180, r_chest=(0.158, 0.130), r_uch=(0.140, 0.112), r_belly=(0.150, 0.130), r_pel=(0.150, 0.13), r_neck=0.060, r_sh=0.064, r_ua=0.056, r_elb=0.044, r_fa=0.044),
        spec=dict(sex="m", hair="buzz", top="longsleeve", bottom="trousers"),
        head=dict(HEAD_COMMON, sdf=dict(W=1.04, face_w=1.10, face_len=0.94, cheeks=1.2, jaw_w=1.12, chin=1.05, neck=1.15, nose_w=1.08,
                                        nose_tip=1.08, ears=1.05),
                  lid_up=27, lid_lo=21, scalp=True, recede=0.008, beard=True, glasses=True, band_z=-0.01, brow_thick=1.0),
        colors=dict(skin="e2a98c", scalp="7d6150", beard="a07a66", lips="b9695f", flush="d9876f", iris="7ba7c9", brow="8a6a52",
                    hair="4a2f1c", hair_light="7a5232", shirt="f6f6f3", cuff="f6f6f3", trousers="262a33", shoe="2a2420",
                    lanyard="1f2b5e", lanyard2="1f2b5e", button="2a2c35"),
    ),
    # right: dark brown brushed-up quiff, slimmer longer face, big smile, cream polo with green/white striped collar and cuffs, black lanyard
    "rechts": dict(
        x=0.52, mic_side=-1, print=False, rolled=False, polo=True, rest=dict(smile=0.85, open=0.16),
        dims=dict(sw=0.165, r_chest=(0.138, 0.112), r_uch=(0.125, 0.098), r_belly=(0.118, 0.105), r_pel=(0.130, 0.115), r_neck=0.050, r_sh=0.056, r_ua=0.047, r_elb=0.039, r_fa=0.039),
        spec=dict(sex="m", hair="quiff", top="tshirt", bottom="trousers"),
        head=dict(HEAD_COMMON, sdf=dict(W=0.97, face_w=0.95, cheeks=0.9, jaw_w=0.98, chin=1.1, face_len=0.99, mouth_w=1.08),
                  lid_up=21, lid_lo=18, quiff=dict(lift=0.88), band_z=-0.03, brow_thick=1.45, brow_y=-0.0015, brow_arch=0.93),
        colors=dict(skin="dfa47f", scalp="6a4a34", lips="b0665a", flush="d9876f", iris="6b4a2e", brow="4b3020",
                    hair="2c1b10", hair_light="573722", shirt="efebe0", cuff="efebe0", trousers="1c1f26", shoe="f2f2f2",
                    lanyard="141414", lanyard2="d9d9d4", button="e6e6e2", polo_green="1d4a32", polo_white="f4f2ea"),
    ),
}
HEAD_FIXED = dict(eye_white="f1ede6", pupil="0c0a09", catchlight="ffffff", lash="1d1612", lid_rim="c9967f", mouth_cavity="3a1414",
                  mouth_inner="7a3a36", tongue="b85f62", teeth="f2ece0", frame_black="141414", frame_tortoise="6b4630",
                  headset="1b1c1f", headset_pad="2c2d31", headset_metal="9aa1a8", mic_foam="232427")
HEAD_ROUGH = dict(eye_white=0.12, iris=0.15, pupil=0.1, catchlight=0.1, teeth=0.3, frame_black=0.25, frame_tortoise=0.2,
                  headset=0.35, headset_pad=0.9, headset_metal=0.3, mic_foam=0.95, mouth_cavity=0.8, hair=0.6, brow=0.8)

ANK_Z = people.ANK_Z

def desk_joints(ch):
    dm = people.body_dims("m"); dm.update(ch.get("dims", {})); dm["head_r"] = 0.12
    J = dict(dm=dm, seated=True, props=[])
    pelv = D(0, -0.06, 0.56); td = _n(D(0, 0.22, 1)); nd = _n(D(0, 0.0, 1)); face = _n(D(0, 1, 0.0))
    hip_z, hip_f = 0.535, -0.03
    ank = {1: D(0.15, 0.45, ANK_Z), -1: D(-0.15, 0.45, ANK_Z)}; knee_hint = D(0, 1, 0.6)
    belly = pelv + td * 0.13; chest = belly + td * 0.15; uchest = chest + td * 0.12
    neck_t = uchest + nd * 0.10; head_c = neck_t + nd * 0.100
    J.update(PELV=pelv, BELLY=belly, CHEST=chest, UCHEST=uchest, NECK_T=neck_t, HEAD_C=head_c, head_r=0.12,
             face=face, nd=nd, td=td)
    side_axis = _n(Vector((1, 0, 0)) - td * td.x)
    for s in (1, -1):
        hip = D(s * dm["hw"], hip_f, hip_z)
        knee, a = two_bone(hip, ank[s], dm["thigh"], dm["shin"], knee_hint + D(s * 0.08, 0, 0))
        toe = a + D(s * 0.02, 0.15, -0.03)
        sh = uchest + side_axis * (s * dm["sw"]) - td * 0.02
        wr = D(s * 0.17, 0.42, 0.665)
        elb, w = two_bone(sh, wr, dm["ua"], dm["fa"], D(s * 0.45, -0.25, -1.0))
        J[f"hip{s}"], J[f"knee{s}"], J[f"ank{s}"], J[f"toe{s}"] = hip, knee, a, toe
        J[f"sh{s}"], J[f"elb{s}"], J[f"wr{s}"], J[f"hdir{s}"] = sh, elb, w, _n(D(-s * 0.45, 1, -0.10))
    return J

def add_closed(mb, verts, faces, tag, bone):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces: bm.faces.new([vs[k] for k in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mb.add_bm(bm, tag, bone)

def front_point(verts, z, x=0.0, tol=0.012):
    best = None
    for v in verts:
        if abs(v.x - x) < tol and abs(v.z - z) < tol:
            if best is None or v.y < best.y: best = v
    return best.copy() if best is not None else None

def build_body(ch):
    """skin-modifier body in the people.py style (head comes from hero_head)."""
    spec = ch["spec"]
    J = desk_joints(ch); dm = J["dm"]; B = people.bone_segments(J)
    mb = MB()
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
    chain(uc, [(J["UCHEST"].lerp(J["NECK_T"], 0.5), dm["r_neck"]), (J["NECK_T"], dm["r_neck"] * 0.95)])
    for s in (1, -1):
        hip, knee, ank = J[f"hip{s}"], J[f"knee{s}"], J[f"ank{s}"]
        sh, elb, wr = J[f"sh{s}"], J[f"elb{s}"], J[f"wr{s}"]
        chain(pel, [(hip, dm["r_hip"]), (hip.lerp(knee, 0.5), dm["r_thigh"]), (knee, dm["r_knee"]),
                    (knee.lerp(ank, 0.3), dm["r_calf"]), (knee.lerp(ank, 0.72), dm["r_shin"]), (ank, dm["r_ank"])])
        chain(uc, [(sh, dm["r_sh"]), (sh.lerp(elb, 0.5), dm["r_ua"]), (elb, dm["r_elb"]), (elb.lerp(wr, 0.5), dm["r_fa"]), (wr, dm["r_wr"])])
    bv, bf = skin_mesh(pts, rad, edges, pel, subsurf=2)
    weights = people.body_weights(bv, B)
    mb.add(bv, bf, TOP, weights)
    for i, f in enumerate(bf):
        c = sum((bv[k] for k in f), Vector()) / len(f)
        r = people.body_region(c, B, spec, J)
        if ch.get("polo") and r in (TOP, TOP2, SKIN):
            for sd in "LR":
                if (c.x > 0) != (sd == "L"): continue
                d, t = seg_dist(c, *B[f"upper_arm.{sd}"])
                if d < 0.09:
                    if t < 0.50: r = TOP
                    elif t < 0.535: r = POLO_G
                    elif t < 0.555: r = POLO_W
                    elif t < 0.60: r = POLO_G
                    else: r = SKIN
                d2, t2 = seg_dist(c, *B[f"forearm.{sd}"])
                if d2 < 0.09 and d2 < d: r = SKIN
        if ch.get("rolled") and r in (TOP, TOP2):
            for sd in "LR":
                d, t = seg_dist(c, *B[f"forearm.{sd}"])
                if d < 0.09 and (c.x > 0) == (sd == "L"):
                    r = SKIN if t > 0.22 else TOP2
                d, t = seg_dist(c, *B[f"upper_arm.{sd}"])
                if d < 0.09 and t > 0.88 and (c.x > 0) == (sd == "L"):
                    r = TOP2
        d, t = seg_dist(c, *B["neck"])
        if d < 0.09 and t > 0.22 and r in (TOP, TOP2):
            r = SKIN                       # open collar: neck is skin
        mb.ft[i] = r
    # hands & shoes
    hs = dm["hand"]
    for s in (1, -1):
        n = people.SIDE[s]; wr, hd = J[f"wr{s}"], J[f"hdir{s}"]
        Mh = look_matrix(Vector(), hd, Vector((0, 0, 1))).to_3x3()
        sphere(mb, wr + hd * 0.052 * hs, (0.043 * hs, 0.024 * hs, 0.060 * hs), SKIN, f"hand.{n}", (18, 12), M=Mh, shape=superellipse(0.85))
        side_v = (Mh @ Vector((1, 0, 0))) * (-s)
        for k in range(4):   # finger hints along the front edge
            fx = (k - 1.5) * 0.019
            a = wr + hd * 0.085 * hs + (Mh @ Vector((fx, 0, 0)))
            tube(mb, [a, a + hd * 0.035 - Vector((0, 0, 0.006))], 0.0085, SKIN, f"hand.{n}", 8)
        sphere(mb, wr + hd * 0.035 * hs + side_v * 0.036 * hs + Vector((0, 0, 0.008)), (0.016 * hs, 0.016 * hs, 0.032 * hs), SKIN, f"hand.{n}", (10, 6),
               M=look_matrix(Vector(), _n(hd + side_v * 0.6), Vector((0, 0, 1))).to_3x3())
        ank, toe = J[f"ank{s}"], J[f"toe{s}"]
        fwd = _n(Vector((toe.x - ank.x, toe.y - ank.y, 0)))
        Ms = Matrix((fwd.cross(Vector((0, 0, 1))), fwd, Vector((0, 0, 1)))).transposed()
        c = Vector((ank.x, ank.y, 0)) + fwd * 0.045 + Vector((0, 0, 0.057))
        sphere(mb, c, (0.050, 0.125, 0.048), SHOE, f"foot.{n}", (12, 8), M=Ms, shape=superellipse(0.72))
    # collar band + collar points, buttons, lanyard
    neck_axis = _n(J["NECK_T"] - J["UCHEST"])
    zc = J["UCHEST"].z + 0.02
    polo = ch.get("polo")
    if polo:   # ribbed collar band around the neck base
        torus(mb, J["UCHEST"].lerp(J["NECK_T"], 0.12), neck_axis, dm["r_neck"] + 0.012, 0.011, POLO_G, "neck", 36, 8)
        torus(mb, J["UCHEST"].lerp(J["NECK_T"], 0.12) + neck_axis * 0.008, neck_axis, dm["r_neck"] + 0.0215, 0.0022, POLO_W, "neck", 36, 6)
    for sg in (1, -1):
        corners = [(sg * 0.010, zc - 0.004), (sg * 0.064, zc + 0.040), (sg * 0.050, zc - 0.060)]
        if polo: corners = [(sg * 0.012, zc - 0.010), (sg * 0.068, zc + 0.036), (sg * 0.060, zc - 0.062)]
        if polo: continue                  # polo: ribbed band + placket only
        surf_pts = [front_point(bv, z, x, 0.012) or front_point(bv, z, x, 0.025) for x, z in corners]
        if None in surf_pts: continue
        fw = Vector((0, -1, 0))
        top = [p + fw * 0.007 for p in surf_pts]; bot = [p + fw * 0.001 for p in surf_pts]
        add_closed(mb, top + bot, [[0, 1, 2], [5, 4, 3], [0, 3, 4, 1], [1, 4, 5, 2], [2, 5, 3, 0]], POLO_G if polo else TOP2, "chest")
    if polo:   # short placket below the collar
        p0 = front_point(bv, zc - 0.03, 0.0, 0.012); p1 = front_point(bv, zc - 0.13, 0.0, 0.012)
        if p0 and p1:
            v, f = hh.tube([tuple(p0 + Vector((0, -0.003, 0))), tuple(p1 + Vector((0, -0.003, 0)))], 0.006, 8, flat=0.3)
            mb.add([Vector(p) for p in v], f, POLO_G, "chest")
    for k in range(0 if polo else 4):
        z = zc - 0.075 - k * 0.075
        p = front_point(bv, z, 0.0, 0.01)
        if p is None: continue
        sphere(mb, p + Vector((0, -0.003, 0)), (0.0062, 0.003, 0.0062), SHIRT_BTN, "chest", (8, 6), M=look_matrix(Vector(), Vector((0, -1, 0))).to_3x3())
    bot = front_point(bv, J["BELLY"].z + 0.03, 0.0, 0.015)
    for sg in (1, -1):
        a = J["UCHEST"].lerp(J["NECK_T"], 0.25) + Vector((sg * (dm["r_neck"] + 0.012), 0.012, 0))
        m = front_point(bv, J["CHEST"].z + 0.05, sg * 0.055, 0.015)
        if m is None or bot is None: continue
        path = [a + Vector((0, -0.004, 0)), m + Vector((0, -0.013, 0)), bot + Vector((sg * 0.012, -0.015, 0.02))]
        v, f = hh.tube([tuple(p) for p in path], 0.0068, 8, flat=0.35)
        mb.add([Vector(p) for p in v], f, LANYARD, "chest")
        v, f = hh.tube([tuple(p + Vector((0, -0.0040, 0))) for p in path[1:]], 0.0014, 6)
        mb.add([Vector(p) for p in v], f, LANYARD2, "chest")
    if bot is not None:
        box(mb, bot + Vector((0, -0.012, -0.035)), (0.075, 0.006, 0.10), WHITE, "chest")
    return mb, J, B

def vc_mat(name, base_hex, rough=0.5, sss=0.0):
    """material whose base colour = factor x vertex colour 'Col' (exported as baseColorFactor * COLOR_0)."""
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name)
    try: m.use_nodes = True
    except Exception: pass
    nt = m.node_tree; b = nt.nodes.get("Principled BSDF")
    attr = nt.nodes.new("ShaderNodeVertexColor"); attr.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    c = lin(hexc(base_hex)) + (1.0,)
    mix.inputs[7].default_value = c                       # B (colour)
    nt.links.new(attr.outputs["Color"], mix.inputs[6])    # A
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    m.diffuse_color = c
    b.inputs["Roughness"].default_value = rough
    if sss > 0:
        try:
            b.inputs["Subsurface Weight"].default_value = sss
            b.inputs["Subsurface Radius"].default_value = (0.010, 0.004, 0.002)
            b.inputs["Subsurface Scale"].default_value = 0.01
        except Exception: pass
    return m

def presenter_materials(ch):
    c = ch["colors"]; pfx = "cl_" if ch["x"] < 0 else "cr_"
    M = lambda n, h, **kw: make_mat(pfx + n, hexc(h), **kw)
    shirt = tex_mat(pfx + "shirt_print", "shirt_print_navy_dots.png", rough=0.8) if ch["print"] else M("shirt", c["shirt"], rough=0.8)
    body = {SKIN: M("skin_body", c["skin"], rough=0.5), TOP: shirt, TOP2: M("shirt_collar", c["cuff"], rough=0.8),
            BOTTOM: M("trousers", c["trousers"], rough=0.7), SHOE: M("shoe", c["shoe"], rough=0.5), WHITE: M("badge", "ffffff", rough=0.4),
            SHIRT_BTN: M("button", c["button"], rough=0.3), LANYARD: M("lanyard", c["lanyard"], rough=0.6),
            LANYARD2: M("lanyard_stripe", c["lanyard2"], rough=0.6), DARK: M("dark", "202020"), ACCENT: M("lanyard", c["lanyard"]),
            HAIR: M("hair_flat", c["hair"]), PUPIL: M("dark", "202020"), MOUTH: M("dark", "202020"), METAL: M("headset_metal", "9aa1a8"),
            LIPS: M("dark", "202020"), BROW: M("dark", "202020"),
            POLO_G: M("polo_green", c.get("polo_green", "1d4a32"), rough=0.8), POLO_W: M("polo_white", c.get("polo_white", "f4f2ea"), rough=0.8)}
    head = {}
    for t, h in HEAD_FIXED.items():
        head[t] = M(t, h, rough=HEAD_ROUGH.get(t, 0.5), **({"emit": 1.5} if t == "catchlight" else {}))
    head["skin"] = vc_mat(pfx + "skin", c["skin"], rough=0.5, sss=0.12)
    head["hair"] = vc_mat(pfx + "hair", c["hair_light"], rough=0.6)
    head["iris"] = M("iris", c["iris"], rough=0.15)
    head["brow"] = M("brow", c["brow"], rough=0.8)
    return body, head

def head_to_world(J, P, scale=1.0):
    Mf = people.face_frame(J)
    Mn = np.array([[Mf[i][j] for j in range(3)] for i in range(3)], dtype=np.float64)
    return np.asarray(J["HEAD_C"])[None, :] + (np.asarray(P, dtype=np.float64) * scale) @ Mn.T, Mn

PARENTS = {"spine": "pelvis", "chest": "spine", "neck": "chest", "head": "neck"}
for sd in "LR":
    PARENTS.update({f"clavicle.{sd}": "chest", f"upper_arm.{sd}": f"clavicle.{sd}", f"forearm.{sd}": f"upper_arm.{sd}",
                    f"hand.{sd}": f"forearm.{sd}", f"thigh.{sd}": "pelvis", f"shin.{sd}": f"thigh.{sd}", f"foot.{sd}": f"shin.{sd}"})

HEAD_CACHE = {}
HEAD_SCALE = 1.07

def build_rigged_presenter(name, ch, col, offset):
    body, J, B = build_body(ch)
    bmats, hmats = presenter_materials(ch)
    cfg = ch["head"]; cfg["colors"] = ch["colors"]; cfg["mic_side"] = ch["mic_side"]
    key = name
    if key in HEAD_CACHE: cfg.update(HEAD_CACHE[key])
    g, H = hh.build_head(cfg)
    HEAD_CACHE[key] = {k: cfg[k] for k in ("_skin", "_hair", "_hair_fn") if k in cfg}
    offs = {}
    for k in SHAPE_KEYS:
        gk = hh.build_head(cfg, {k: 1.0})[0] if k.startswith("blink") else None
        offs[k] = hh.key_offsets(g, H, cfg, k, gk)
    Pw, Mn = head_to_world(J, g.v, HEAD_SCALE)
    # ---- merge body + head into one mesh description
    mb = MB()
    mb.v = list(body.v); mb.f = [list(f) for f in body.f]; mb.fs = list(body.fs); mb.vw = list(body.vw)
    mb.ft = [bmats[t].name for t in body.ft]
    o = len(mb.v)
    hy = np.asarray(g.v)[:, 1]
    wh = np.clip((hy + 0.115) / 0.045, 0, 1)
    for i, p in enumerate(Pw):
        mb.v.append(Vector(p))
        mb.vw.append({"head": float(wh[i]), "neck": float(1 - wh[i])} if wh[i] < 1 else {"head": 1.0})
    for f, t in zip(g.f, g.t):
        mb.f.append([o + k for k in f]); mb.ft.append(hmats[t].name); mb.fs.append(True)
    allm = {m.name: m for m in list(bmats.values()) + list(hmats.values())}
    ob = make_object(mb, name, allm, col, proj_uv={bmats[TOP].name: 0.16} if ch["print"] else None)
    add_weights(ob, mb)
    # vertex colours: ratio to the material base colour (skin / hair), white elsewhere
    ca = ob.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i in range(len(ob.data.vertices)): ca.data[i].color = (1, 1, 1, 1)
    vtag = {}
    for f, t in zip(g.f, g.t):
        for k in f: vtag[k] = t
    skin_l = np.array(lin(hexc(ch["colors"]["skin"]))); hair_l = np.array(lin(hexc(ch["colors"]["hair_light"])))
    for k, t in vtag.items():
        if t in ("skin", "mouth_inner"):
            r = np.clip(np.asarray(g.col[k]) / skin_l, 0, 1)
        elif t == "hair":
            r = np.clip(np.asarray(g.col[k]) / hair_l, 0, 1)
        else:
            continue
        ca.data[o + k].color = (float(r[0]), float(r[1]), float(r[2]), 1.0)
    ob.data.color_attributes.active_color = ca
    # shape keys (head only)
    ob.shape_key_add(name="Basis", from_mix=False)
    for k in SHAPE_KEYS:
        sk = ob.shape_key_add(name=k, from_mix=False)
        d = (offs[k] * HEAD_SCALE) @ Mn.T
        nz = np.nonzero(np.abs(d).sum(1) > 1e-7)[0]
        for i in nz:
            sk.data[o + i].co = Vector(Pw[i] + d[i])
    # armature
    arm = bpy.data.armatures.new(name + "_skeleton")
    rig = bpy.data.objects.new(name + "_rig", arm); col.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for n, (h, t) in B.items():
        eb = arm.edit_bones.new(n); eb.head = h; eb.tail = t
    for n, p in PARENTS.items():
        arm.edit_bones[n].parent = arm.edit_bones[p]
    bpy.ops.object.mode_set(mode="OBJECT")
    ob.parent = rig
    mod = ob.modifiers.new("Armature", "ARMATURE"); mod.object = rig
    rig.location = offset
    for k, v in ch.get("rest", {}).items():      # resting expression (also stored for Godot as custom property)
        ob.data.shape_keys.key_blocks[k].value = v
    ob["rest_expression"] = json.dumps(ch.get("rest", {}))
    animate(rig, ch)
    return rig, ob, J

def key_pose(rig, frame, rots):
    for bn, (x, y, z) in rots.items():
        pb = rig.pose.bones[bn]; pb.rotation_mode = "XYZ"
        pb.rotation_euler = (x, y, z)
        pb.keyframe_insert("rotation_euler", frame=frame)

def animate(rig, ch):
    rig.animation_data_create()
    sg = ch["mic_side"]   # turn slightly towards the partner
    acts = {}
    # idle_loop: 4 s breathing + small head drift
    act = bpy.data.actions.new("idle_loop"); rig.animation_data.action = act
    N = 120
    for f in range(0, N + 1, 10):
        a = math.tau * f / N
        key_pose(rig, f, {
            "spine": (0.012 * math.sin(a), 0, 0), "chest": (0.015 * math.sin(a + 0.5), 0, 0),
            "neck": (0.0, 0.03 * math.sin(a) * sg, 0.0),
            "head": (0.025 * math.sin(2 * a), 0.06 * math.sin(a + 1.0) * sg, 0.02 * math.sin(a)),
            "upper_arm.L": (0, 0, 0), "upper_arm.R": (0, 0, 0), "forearm.L": (0, 0, 0), "forearm.R": (0, 0, 0)})
    acts["idle_loop"] = act
    # talk_loop: 3 s, emphatic nods and a hand gesture with the hand away from the partner
    act = bpy.data.actions.new("talk_loop"); rig.animation_data.action = act
    N = 90
    gs = "R" if sg > 0 else "L"
    for f in range(0, N + 1, 5):
        a = math.tau * f / N
        lift = max(0.0, math.sin(a)) ** 1.5
        key_pose(rig, f, {
            "spine": (0.02 * math.sin(a), 0, 0), "chest": (0.03 * math.sin(2 * a), 0.02 * math.sin(a), 0),
            "neck": (0.0, 0.04 * math.sin(a), 0.0),
            "head": (0.07 * math.sin(3 * a) + 0.02, 0.07 * math.sin(a + 0.6), 0.04 * math.sin(2 * a)),
            f"upper_arm.{gs}": (-0.25 * lift, 0, 0), f"forearm.{gs}": (-0.55 * lift, 0, 0.15 * lift),
            f"hand.{gs}": (0.3 * lift, 0, 0), "upper_arm.L" if gs == "R" else "upper_arm.R": (0, 0, 0)})
    acts["talk_loop"] = act
    for name, act in acts.items():
        tr = rig.animation_data.nla_tracks.new(); tr.name = name
        tr.strips.new(name, 0, act)
    rig.animation_data.action = None
    # rest pose for the editable file
    for pb in rig.pose.bones: pb.rotation_euler = (0, 0, 0)

# =====================================================================================  main
def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()
    col = bpy.context.scene.collection
    return col

def export(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        for c in o.children_recursive: c.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS", export_morph=True,
                              export_morph_normal=True, export_skins=True, export_lights=False, export_cameras=False,
                              export_vertex_color="MATERIAL", export_extras=True)
    print("EXPORTED", path)

stats = {}
col = fresh()
booth, glass = build_booth(col)
stats["booth_tris"] = sum(len(p.vertices) - 2 for p in booth.data.polygons)
export(OUT / "euromax_commentary_booth.glb", [booth, glass])

for name, ch in CHARS.items():
    col = fresh()
    rig, ob, J = build_rigged_presenter(f"commentator_{name}", ch, col, Vector((0, 0, 0)))
    stats[name] = dict(verts=len(ob.data.vertices), tris=sum(len(p.vertices) - 2 for p in ob.data.polygons),
                       head_top=round(max(v.co.z for v in ob.data.vertices), 3))
    export(OUT / f"commentator_{name}.glb", [rig])

# combined editable .blend (presenters placed in the booth)
col = fresh()
build_booth(col)
for name, ch in CHARS.items():
    build_rigged_presenter(f"commentator_{name}", ch, col, D(ch["x"], PRES_F, PRES_Z))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "commentary_booth_rig.blend"))
bpy.ops.file.make_paths_relative()
bpy.ops.wm.save_mainfile()
print("STATS", json.dumps(stats))
