"""Structural GLB inspector / comparer (pure python, no Blender needed).

    python glb_inspect.py a.glb              -> summary (nodes, skin joints, animations)
    python glb_inspect.py a.glb b.glb        -> structural comparison (exit 1 on difference)

Structural = node names + hierarchy + rest TRS, skin joint list, mesh/primitive/material names and
vertex counts, animation names / channel targets / keyframe counts and sampled values (tolerance 1e-4).
Byte equality is NOT expected across Blender versions (exporter metadata differs), so this is the
comparison used to show that an existing GLB did not change.
"""
import json, struct, sys, hashlib

CT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}

def load(path):
    b = open(path, "rb").read()
    magic, ver, ln = struct.unpack_from("<4sII", b, 0)
    assert magic == b"glTF"
    off, js, binc = 12, None, b""
    while off < ln:
        cl, ct = struct.unpack_from("<II", b, off); off += 8
        data = b[off:off + cl]; off += cl
        if ct == 0x4E4F534A: js = json.loads(data)
        elif ct == 0x004E4942: binc = data
    return js, binc

def accessor(js, binc, i):
    """returns list of tuples"""
    a = js["accessors"][i]; bv = js["bufferViews"][a["bufferView"]]
    n = NC[a["type"]]; fmt = "<" + CT[a["componentType"]] * n
    size = struct.calcsize(fmt)
    stride = bv.get("byteStride", size)
    base = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return [struct.unpack_from(fmt, binc, base + k * stride) for k in range(a["count"])]

def summary(path):
    js, binc = load(path)
    nodes = js["nodes"]
    names = [n.get("name", f"#{i}") for i, n in enumerate(nodes)]
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []): parent[c] = i
    s = {"nodes": [], "skins": [], "meshes": [], "anims": {}}
    for i, n in enumerate(nodes):
        s["nodes"].append((names[i], names[parent[i]] if i in parent else None,
                           tuple(round(x, 5) for x in n.get("translation", [0, 0, 0])),
                           tuple(round(x, 5) for x in n.get("rotation", [0, 0, 0, 1])),
                           tuple(round(x, 5) for x in n.get("scale", [1, 1, 1]))))
    for sk in js.get("skins", []):
        s["skins"].append([names[j] for j in sk["joints"]])
    for m in js.get("meshes", []):
        prims = []
        for p in m["primitives"]:
            mat = js["materials"][p["material"]]["name"] if "material" in p else None
            prims.append((mat, int(js["accessors"][p["attributes"]["POSITION"]]["count"])))
        s["meshes"].append((m.get("name"), prims))
    for an in js.get("animations", []):
        ch = {}
        for c in an["channels"]:
            smp = an["samplers"][c["sampler"]]
            t = accessor(js, binc, smp["input"]); v = accessor(js, binc, smp["output"])
            ch[(names[c["target"]["node"]], c["target"]["path"])] = (len(t), float(t[-1][0]) if t else 0.0, v)
        s["anims"][an["name"]] = ch
    return s

def compare(a, b, tol=1e-4):
    diffs = []
    if a["nodes"] != b["nodes"]: diffs.append("node names/hierarchy/rest TRS differ")
    if a["skins"] != b["skins"]: diffs.append("skin joint lists differ")
    if a["meshes"] != b["meshes"]: diffs.append("meshes/primitives/materials differ")
    if set(a["anims"]) != set(b["anims"]): diffs.append(f"animation sets differ: {sorted(set(a['anims']) ^ set(b['anims']))}")
    worst = 0.0
    for name in set(a["anims"]) & set(b["anims"]):
        ca, cb = a["anims"][name], b["anims"][name]
        if set(ca) != set(cb): diffs.append(f"{name}: channel sets differ"); continue
        for k in ca:
            if ca[k][0] != cb[k][0]: diffs.append(f"{name}{k}: keyframe count {ca[k][0]} vs {cb[k][0]}"); continue
            d = max((abs(x - y) for va, vb in zip(ca[k][2], cb[k][2]) for x, y in zip(va, vb)), default=0.0)
            worst = max(worst, d)
            if d > tol: diffs.append(f"{name}{k}: max value delta {d:.2e}")
    return diffs, worst

def sha(path): return hashlib.sha256(open(path, "rb").read()).hexdigest()

if __name__ == "__main__":
    if len(sys.argv) == 2:
        s = summary(sys.argv[1])
        print("nodes:", len(s["nodes"]), " skins:", [len(k) for k in s["skins"]])
        for k in s["skins"]: print(" joints:", k)
        for m in s["meshes"]: print(" mesh", m[0], "prims", len(m[1]), "verts", sum(p[1] for p in m[1]))
        for n, ch in s["anims"].items():
            tracks = sorted({k[0] for k in ch}); fr = next(iter(ch.values()))[0]
            print(f" anim {n}: {len(ch)} channels, {fr} keys, length {next(iter(ch.values()))[1]:.4f}s, {len(tracks)} nodes")
    else:
        a, b = summary(sys.argv[1]), summary(sys.argv[2])
        diffs, worst = compare(a, b)
        print("sha256:", sha(sys.argv[1])[:16], sha(sys.argv[2])[:16], "(byte-identical)" if sha(sys.argv[1]) == sha(sys.argv[2]) else "(bytes differ)")
        print("structural differences:", "none" if not diffs else diffs, f"| worst animation value delta {worst:.2e}")
        sys.exit(1 if diffs else 0)
