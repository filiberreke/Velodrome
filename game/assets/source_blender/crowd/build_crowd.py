"""
build_crowd.py – generates all crowd / staff meshes for Velodrome 250.
Run:  blender -b -P build_crowd.py      (or a python with the bpy module)
Output: ../out/crowd_people.glb  – one mesh per variant and LOD (e.g. seat_m_relaxed_lod0)
All meshes share ONE material 'crowd'; UV.x encodes the body region, so Godot's crowd.gdshader
can give every instance its own shirt, trousers, skin and hair colours (MultiMesh friendly).
"""
import bpy, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import importlib, vlib, people
importlib.reload(vlib); importlib.reload(people)
from vlib import *
from people import build_person

OUT = os.environ.get("CROWD_OUT", os.path.join(HERE, "..", "out"))
os.makedirs(OUT, exist_ok=True)

VARIANTS = {
    # seated – tribunes (origin = floor under the seat centre, seat height 0.43 m, facing +Z in Godot)
    "seat_m_relaxed":  dict(sex="m", pose="seat_relaxed", hair="short", top="tshirt", bottom="jeans"),
    "seat_f_clap":     dict(sex="f", pose="seat_clap", hair="ponytail", top="longsleeve", bottom="jeans"),
    "seat_m_cheer":    dict(sex="m", pose="seat_cheer1", hair="cap", top="tshirt", bottom="jeans", acc=["scarf"]),
    "seat_f_phone":    dict(sex="f", pose="seat_phone", hair="bob", top="tshirt", bottom="jeans"),
    "seat_m_lean":     dict(sex="m", pose="seat_lean", hair="buzz", beard=True, top="hoodie", bottom="jeans"),
    "seat_f_cheer":    dict(sex="f", pose="seat_cheer2", hair="long", top="tshirt", bottom="jeans", acc=["scarf"]),
    "seat_m_crossed":  dict(sex="m", pose="seat_crossed", hair="short", glasses=True, top="longsleeve", bottom="jeans"),
    "seat_f_drink":    dict(sex="f", pose="seat_drink", hair="bun", top="hoodie", bottom="jeans"),
    "seat_m_point":    dict(sex="m", pose="seat_point", hair="curly", top="polo", bottom="jeans"),
    # standing – infield public (origin = floor between the feet)
    "stand_m_relaxed": dict(sex="m", pose="stand_relaxed", hair="short", top="tshirt", bottom="jeans"),
    "stand_f_drink":   dict(sex="f", pose="stand_drink", hair="ponytail", top="tshirt", bottom="shorts"),
    "stand_m_cheer":   dict(sex="m", pose="stand_cheer2", hair="cap", top="tshirt", bottom="jeans", acc=["scarf"]),
    "stand_f_phone":   dict(sex="f", pose="stand_phone", hair="long", top="longsleeve", bottom="jeans"),
    "stand_m_rail":    dict(sex="m", pose="stand_rail", hair="short", beard=True, top="hoodie", bottom="jeans"),
    "stand_f_rail":    dict(sex="f", pose="stand_rail", hair="bob", top="tshirt", bottom="jeans"),
    "stand_m_clap":    dict(sex="m", pose="stand_clap", hair="curly", top="tshirt", bottom="shorts"),
    "stand_f_talk":    dict(sex="f", pose="stand_talk", hair="bun", top="longsleeve", bottom="skirt"),
    "stand_m_drink":   dict(sex="m", pose="stand_drink", hair="buzz", glasses=True, top="polo", bottom="jeans"),
    "stand_f_relaxed": dict(sex="f", pose="stand_relaxed", hair="ponytail", top="hoodie", bottom="jeans"),
    # staff
    "staff_official_m":  dict(sex="m", pose="stand_hips", hair="short", top="blazer", bottom="trousers", acc=["lanyard"]),
    "staff_official_f":  dict(sex="f", pose="stand_clipboard", hair="bun", top="blazer", bottom="trousers", acc=["lanyard"]),
    "staff_mechanic":    dict(sex="m", pose="stand_mechanic", hair="cap", top="polo", bottom="trousers"),
    "staff_mechanic_f":  dict(sex="f", pose="stand_relaxed", hair="ponytail", top="polo", bottom="trousers"),
    "staff_vendor_m":    dict(sex="m", pose="stand_counter", hair="cap", top="tshirt", bottom="trousers", acc=["apron"]),
    "staff_vendor_f":    dict(sex="f", pose="stand_counter", hair="bun", top="tshirt", bottom="trousers", acc=["apron"]),
    "staff_photographer":dict(sex="m", pose="stand_camera", hair="short", beard=True, top="jacket", bottom="trousers"),
}

def build_all(names=None, lods=(0, 1, 2)):
    stats = {}
    for name, spec in VARIANTS.items():
        if names and name not in names: continue
        for lod in lods:
            mb, J, B = build_person(spec, lod)
            ob = build_object(mb, f"{name}_lod{lod}", mode="regions")
            stats[ob.name] = mb.tris()
    return stats

if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    only = os.environ.get("ONLY")
    stats = build_all(only.split(",") if only else None)
    for k, v in stats.items():
        print(f"TRIS {k}: {v}")
    if not os.environ.get("NO_EXPORT"):
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "crowd_people.glb"), export_format='GLB',
                                  export_animations=False, export_yup=True, export_apply=False, export_normals=True)
        print("exported", os.path.join(OUT, "crowd_people.glb"))
