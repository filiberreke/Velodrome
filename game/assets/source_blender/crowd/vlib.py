"""
vlib.py – shared procedural mesh helpers for Velodrome 250 assets (Blender 4.2+ / 5.x).
Coordinates: helpers take Blender vectors. D(x, f, z) converts 'person space'
(x = person's left, f = forward, z = up) to Blender (forward = -Y), which becomes +Z in Godot.
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix

def D(x, f, z):
    return Vector((x, -f, z))

def lin(c):
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)

# ------------------------------------------------------------------ region ids (crowd shader)
SKIN, HAIR, TOP, BOTTOM, SHOE, PUPIL, WHITE, MOUTH, ACCENT, DARK, TOP2, METAL, LIPS, BROW = range(14)
N_REGIONS = 16

class MB:
    """Mesh builder: verts, faces, a tag per face (region id or material name) and bone weights per vertex."""
    def __init__(s):
        s.v, s.f, s.ft, s.fs, s.vw = [], [], [], [], []
    def add(s, verts, faces, tag, weights, smooth=True, flat=None):
        o = len(s.v)
        s.v += [Vector(v) for v in verts]
        for i, fc in enumerate(faces):
            s.f.append([o + k for k in fc]); s.ft.append(tag)
            s.fs.append(smooth and not (flat and i in flat))
        if weights is None: s.vw += [{}] * len(verts)
        elif isinstance(weights, str): s.vw += [{weights: 1.0}] * len(verts)
        else: s.vw += list(weights)
    def add_bm(s, bm, tag, bone, M=Matrix(), smooth=True, flat_axis=None):
        bm.transform(M)
        bm.verts.index_update(); bm.normal_update()
        verts = [v.co.copy() for v in bm.verts]
        faces, flat = [], set()
        for i, f in enumerate(bm.faces):
            faces.append([v.index for v in f.verts])
            if flat_axis is not None and abs(f.normal.dot(flat_axis)) > 0.95:
                flat.add(i)
        bm.free()
        s.add(verts, faces, tag, bone, smooth, flat)
    def tris(s):
        return sum(len(f) - 2 for f in s.f)

def look_matrix(origin, axis_z, up_hint=Vector((0, 0, 1))):
    z = axis_z.normalized()
    if abs(z.dot(up_hint.normalized())) > 0.99:
        up_hint = Vector((0, 1, 0)) if abs(z.y) < 0.9 else Vector((1, 0, 0))
    x = up_hint.cross(z).normalized(); y = z.cross(x)
    M = Matrix((x, y, z)).transposed().to_4x4(); M.translation = origin
    return M

def superellipse(e):
    def f(co):
        return Vector(tuple(math.copysign(abs(k) ** e, k) for k in co))
    return f

def sphere(mb, c, radii, tag, bone, segs=(24, 14), M=None, shape=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs[0], v_segments=segs[1], radius=1.0)
    for v in bm.verts:
        if shape: v.co = shape(v.co)
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))
    T = Matrix.Translation(c) @ (M.to_4x4() if M is not None else Matrix())
    mb.add_bm(bm, tag, bone, T)

def box(mb, c, size, tag, bone, M=None, bevel=0.0):
    """axis-aligned box (in M frame) with optional rounded edges (superellipse sphere)."""
    if bevel > 0:
        e = max(0.08, min(0.45, bevel))
        sphere(mb, c, (size[0] / 2, size[1] / 2, size[2] / 2), tag, bone, (16, 10), M=M, shape=superellipse(e))
        return
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    T = Matrix.Translation(c) @ (M.to_4x4() if M is not None else Matrix())
    mb.add_bm(bm, tag, bone, T, smooth=False)

def cyl(mb, a, b, r, tag, bone, segs=16, r2=None, caps=True):
    axis = b - a; L = axis.length
    if L < 1e-6: return
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, segments=segs, radius1=r, radius2=r2 if r2 is not None else r, depth=L)
    M = look_matrix((a + b) / 2, axis)
    mb.add_bm(bm, tag, bone, M, flat_axis=axis.normalized())

def tube(mb, pts, r, tag, bone, segs=12, ends=True, joints=True):
    rr = r if isinstance(r, (list, tuple)) else [r] * len(pts)
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        cyl(mb, a, b, rr[i], tag, bone, segs, r2=rr[i + 1], caps=False)
    for i, p in enumerate(pts):
        last = i in (0, len(pts) - 1)
        if (last and not ends) or (not last and not joints): continue
        sphere(mb, p, (rr[i],) * 3, tag, bone, (segs, max(3, segs // 2)))

def torus(mb, center, axis, R, r, tag, bone, seg=32, rseg=8, arc=2 * math.pi):
    M = look_matrix(center, axis)
    verts, faces = [], []
    full = abs(arc - 2 * math.pi) < 1e-6
    ns = seg if full else seg + 1
    for i in range(ns):
        a = arc * i / seg
        for j in range(rseg):
            b = 2 * math.pi * j / rseg
            p = Vector(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
            verts.append(M @ p)
    for i in range(seg):
        for j in range(rseg):
            i2, j2 = (i + 1) % ns, (j + 1) % rseg
            faces.append([i * rseg + j, i2 * rseg + j, i2 * rseg + j2, i * rseg + j2])
    mb.add(verts, faces, tag, bone)

def seg_dist(p, a, b):
    ab = b - a
    if ab.length_squared < 1e-12: return (p - a).length, 0.0
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length, t

def two_bone(root, target, a, b, hint):
    """returns (mid, end): end is the target clamped to reach"""
    dv = target - root; d = min(dv.length, a + b - 1e-4); u = dv.normalized()
    ca = max(-1, min(1, (a * a + d * d - b * b) / (2 * a * d)))
    v = (hint - u * hint.dot(u)).normalized()
    mid = root + u * (a * ca) + v * (a * math.sqrt(max(0, 1 - ca * ca)))
    return mid, root + u * d

def skin_mesh(points, radii, edges, root, subsurf=1):
    me = bpy.data.meshes.new("skin_src")
    me.from_pydata([tuple(p) for p in points], edges, [])
    ob = bpy.data.objects.new("skin_src", me); bpy.context.scene.collection.objects.link(ob)
    sk = ob.modifiers.new("Skin", 'SKIN'); sk.branch_smoothing = 0.6
    for i, r in enumerate(radii):
        d = me.skin_vertices[0].data[i]; d.radius = r; d.use_root = (i == root)
    if subsurf > 0:
        ss = ob.modifiers.new("Sub", 'SUBSURF'); ss.levels = subsurf; ss.render_levels = subsurf
    dg = bpy.context.evaluated_depsgraph_get()
    em = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    verts = [v.co.copy() for v in em.vertices]
    faces = [list(p.vertices) for p in em.polygons]
    bpy.data.objects.remove(ob); bpy.data.meshes.remove(me); bpy.data.meshes.remove(em)
    return verts, faces

def solid_shell_bm(bm, thick):
    """bmesh (open shell) -> (verts, faces) with thickness inward and rim walls"""
    bm.normal_update(); bm.verts.index_update()
    vs = [v.co.copy() for v in bm.verts]; ns = [v.normal.copy() for v in bm.verts]
    faces = [[v.index for v in f.verts] for f in bm.faces]
    n = len(vs)
    verts = vs + [vs[i] - ns[i] * thick for i in range(n)]
    allf = faces + [list(reversed([k + n for k in f])) for f in faces]
    for e in bm.edges:
        if e.is_boundary and e.link_faces:
            a, b = e.verts[0].index, e.verts[1].index
            fv = [v.index for v in e.link_faces[0].verts]; ia = fv.index(a)
            if fv[(ia + 1) % len(fv)] != b: a, b = b, a
            allf.append([b, a, a + n, b + n])
    bm.free()
    return verts, allf

def build_object(mb, name, mode="regions", colors=None, collection=None, extra_props=None):
    """mode 'regions': one material 'crowd', UV.u encodes the region id (crowd shader).
       mode 'materials': one material per tag name, colours from `colors` (sRGB)."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in mb.v], [], mb.f)
    me.validate(); me.update()
    if len(me.polygons) != len(mb.f):
        raise RuntimeError(f"{name}: mesh validate removed faces")
    if mode == "regions":
        m = bpy.data.materials.get("crowd") or _make_mat("crowd", (0.8, 0.8, 0.8))
        me.materials.append(m)
        uv = me.uv_layers.new(name="UVMap")
        for p, tag, sm in zip(me.polygons, mb.ft, mb.fs):
            p.use_smooth = sm
            u = (tag + 0.5) / N_REGIONS
            for li in p.loop_indices:
                uv.data[li].uv = (u, 0.5)
    else:
        names = []
        for t in mb.ft:
            if t not in names: names.append(t)
        for t in names:
            me.materials.append(bpy.data.materials.get(t) or _make_mat(t, (colors or {}).get(t, (0.8, 0.8, 0.8))))
        uv = me.uv_layers.new(name="UVMap")
        for p, tag, sm in zip(me.polygons, mb.ft, mb.fs):
            p.material_index = names.index(tag); p.use_smooth = sm
            for li in p.loop_indices:
                uv.data[li].uv = (0.5, 0.5)
    ob = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(ob)
    return ob

def _make_mat(name, srgb, rough=0.7, metal=0.0, emit=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    c = lin(srgb) + (1.0,)
    m.diffuse_color = c
    try: m.use_nodes = True
    except Exception: pass
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = c
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = c
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        try: m.surface_render_method = 'BLENDED'
        except Exception: m.blend_method = 'BLEND'
    return m

def make_mat(name, srgb, **kw):
    return bpy.data.materials.get(name) or _make_mat(name, srgb, **kw)

def add_weights(ob, mb):
    groups = {}
    for i, w in enumerate(mb.vw):
        for b, val in w.items():
            if b is None: continue
            if b not in groups: groups[b] = ob.vertex_groups.new(name=b)
            groups[b].add([i], val, 'REPLACE')
