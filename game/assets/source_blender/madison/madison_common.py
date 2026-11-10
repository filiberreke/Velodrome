"""Shared helpers for the Madison Blender scripts.

`load_rider_rig()` re-uses the rig code of ../build_rider.py WITHOUT modifying that file: it executes the
source of build_rider.py up to (not including) the "keyed control actions" section, i.e. everything that
builds the armature, meshes, IK constraints, calibrated poles and the `apply_controls()` helper.
build_rider.py itself stays byte-identical, so its output cannot change.
"""
import os, math, bpy
from mathutils import Vector, Matrix, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, ".."))
MARKER = "# keyed control actions for the editable .blend"

# ---- contract constants shared with Godot (also written to madison_profile.json)
REF_GAP = 1.20          # reference lateral distance between the two bike centre lines (m)
HAND_ANCHOR = 0.11      # clasp point: metres from the wrist along the hand bone (+Y local)
PEAK_T = 0.6            # sling_t of maximum momentum
E_END = 0.35            # efficiency left at sling_t = 1.0 (over-holding)

def _smoother(x):
    x = max(0.0, min(1.0, x)); return x * x * x * (x * (x * 6 - 15) + 10)

def _smooth(x):
    x = max(0.0, min(1.0, x)); return x * x * (3 - 2 * x)

def efficiency(t):
    """Single source of truth for the HUD slider width AND the pose intensity. 0..1, exactly 1.0 at PEAK_T."""
    t = max(0.0, min(1.0, t))
    if t <= PEAK_T:
        return _smoother(t / PEAK_T)
    return 1.0 - (1.0 - E_END) * _smooth((t - PEAK_T) / (1.0 - PEAK_T))

def load_rider_rig(out_dir):
    path = os.path.join(SRC, "build_rider.py")
    src = open(path, encoding="utf-8").read()
    code = src[:src.index(MARKER)]
    os.makedirs(out_dir, exist_ok=True)
    os.environ["RIDER_OUT"] = out_dir
    ns = {"__name__": "build_rider_rig", "__file__": path}
    exec(compile(code, path, "exec"), ns)
    return ns


def filter_glb_channels(path, allowed_nodes):
    """Remove animation channels whose target node is not in `allowed_nodes` (pure python, rewrites the GLB JSON chunk).
    The Blender exporter keeps a constant rest-value channel for a few bones (e.g. foot.R) even though they are not keyed."""
    import json, struct
    b = open(path, "rb").read()
    magic, ver, ln = struct.unpack_from("<4sII", b, 0)
    off, chunks = 12, []
    while off < ln:
        cl, ct = struct.unpack_from("<II", b, off); chunks.append((ct, b[off + 8:off + 8 + cl])); off += 8 + cl
    js = json.loads(chunks[0][1]); names = [n.get("name") for n in js["nodes"]]
    removed = []
    for an in js.get("animations", []):
        keep = []
        for c in an["channels"]:
            nm = names[c["target"]["node"]]
            (keep if nm in allowed_nodes else removed).append(c) if True else None
        an["channels"] = keep
    jb = json.dumps(js, separators=(",", ":")).encode(); jb += b" " * (-len(jb) % 4)
    out = struct.pack("<II", len(jb), 0x4E4F534A) + jb
    for ct, data in chunks[1:]:
        out += struct.pack("<II", len(data), ct) + data
    open(path, "wb").write(struct.pack("<4sII", b"glTF", 2, 12 + len(out)) + out)
    return len(removed)
