"""Skinsuit UV v1. Rest-space UVs; never change geometry, weights or morphs.

Atlas coordinates are bottom-left (Blender). Cylindrical islands use padded
rectangles, with the seam at the back. Both generators share this contract.
"""
import math
from mathutils import Vector

REGIONS = {
    "torso": (0.02, 0.52, 0.60, 0.98),
    "sleeve_L": (0.62, 0.52, 0.78, 0.98),
    "sleeve_R": (0.80, 0.52, 0.96, 0.98),
    "shorts_L": (0.02, 0.02, 0.30, 0.48),
    "shorts_R": (0.32, 0.02, 0.60, 0.48),
}


def apply_skinsuit_uv(ob, body_face_count, bone_seg, nearest_bones):
    """Tag body clothing surfaces only; all source colors stay intact.

    Bare forearms on the standard model get a separate skin_kit material so a
    selected long-sleeve texture can dress them without changing default riders.
    UVMap also contains the original decal UVs; those polygons are untouched.
    """
    mesh = ob.data
    uv = mesh.uv_layers.get("UVMap") or mesh.uv_layers.new(name="UVMap")
    copies = {}
    for poly in list(mesh.polygons)[:body_face_count]:
        source = mesh.materials[poly.material_index]
        center = sum((mesh.vertices[i].co for i in poly.vertices), Vector()) / len(poly.vertices)
        def distance(n):
            a, b = bone_seg(n)
            t = max(0, min(1, (center-a).dot(b-a) / (b-a).length_squared))
            return (center - a - t*(b-a)).length
        bone = min(nearest_bones, key=distance)
        base, _, side = bone.partition(".")
        if source.name not in ("suit", "accent", "panel") and base != "forearm":
            continue
        if source.name not in copies:
            material = source.copy()
            material.name = source.name + "_kit"
            copies[source.name] = len(mesh.materials)
            mesh.materials.append(material)
        poly.material_index = copies[source.name]
        if base in ("upper_arm", "forearm", "hand"):
            region = "sleeve_" + side
            # Each segment uses a common transported lateral axis and arc-length V.
            a, elbow = bone_seg("upper_arm." + side)
            _, wrist = bone_seg("forearm." + side)
            upper_len, lower_len = (elbow-a).length, (wrist-elbow).length
            start, end = (a, elbow) if base == "upper_arm" else (elbow, wrist)
            offset = 0 if base == "upper_arm" else upper_len
            total = upper_len + lower_len
        elif base == "thigh":
            region = "shorts_" + side
            start, end = bone_seg(bone)
            offset, total = 0, (end-start).length
        else:
            region = "torso"
            start, _ = bone_seg("pelvis")
            _, end = bone_seg("chest")
            offset, total = 0, (end-start).length
        axis = (end-start).normalized()
        lateral = Vector((1, 0, 0))
        lateral = (lateral-axis*lateral.dot(axis)).normalized()
        back = axis.cross(lateral).normalized()
        coords = []
        for li in poly.loop_indices:
            delta = mesh.vertices[mesh.loops[li].vertex_index].co - start
            # V=1 at shoulder/hip; torso V=1 at neck.
            v = (delta.dot(axis)+offset) / total
            if region != "torso":
                v = 1-v
            u = (math.atan2(delta.dot(lateral), delta.dot(back)) / (2*math.pi)) % 1
            coords.append((li, u, max(0, min(1, v))))
        # Unwrap seam per face so interpolation never crosses the whole island.
        if max(c[1] for c in coords)-min(c[1] for c in coords) > 0.5:
            coords = [(li, u+1 if u < 0.5 else u, v) for li, u, v in coords]
        x0, y0, x1, y1 = REGIONS[region]
        # A full wrap plus seam padding fits inside each atlas cell.
        for li, u, v in coords:
            uv.data[li].uv = (x0 + u/1.5*(x1-x0), y0 + v*(y1-y0))
    mesh.update()


def apply_helmet_uv(ob, center, face_matrix, radius):
    """Spherical rest-space atlas on opaque shell panels; visor/straps untouched."""
    mesh = ob.data
    uv = mesh.uv_layers.get("UVMap") or mesh.uv_layers.new(name="UVMap")
    inverse = face_matrix.inverted()
    for poly in mesh.polygons:
        if mesh.materials[poly.material_index].name not in ("helmet", "helmet2"):
            continue
        coords = []
        for li in poly.loop_indices:
            p = inverse @ ((mesh.vertices[mesh.loops[li].vertex_index].co-center)/radius)
            u = (math.atan2(p.x, -p.z)/(2*math.pi)) % 1
            v = 0.5 + math.asin(max(-1, min(1, p.y/max(p.length, 1e-9))))/math.pi
            coords.append((li, u, v))
        if max(c[1] for c in coords)-min(c[1] for c in coords) > 0.5:
            coords = [(li, u+1 if u < 0.5 else u, v) for li, u, v in coords]
        for li, u, v in coords:
            uv.data[li].uv = (0.02 + u/1.5*0.96, 0.02 + v*0.96)
    mesh.update()
