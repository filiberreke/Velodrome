"""Measure the real arm reach of the Velodrome rider rig (run: blender -b -P measure_rig.py)."""
import os, sys, math, json, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from madison_common import *

ns = load_rider_rig(tempfile.mkdtemp())
rig, pb, arm, J, D = ns["rig"], ns["pb"], ns["arm_data"], ns["J"], ns["D"]
ep, loc_world, q_world = ns["evaluated_pose"], ns["loc_world"], ns["q_world"]
out = {}
for n in ("clavicle.R", "upper_arm.R", "forearm.R", "hand.R"):
    b = arm.bones[n]; out[n] = round(b.length, 4)
print("bone lengths", out)
print("shoulders  L", tuple(round(c, 3) for c in J["sh.L"]), " R", tuple(round(c, 3) for c in J["sh.R"]))
print("rest wrist L", tuple(round(c, 3) for c in J["wr.L"]), " wrist->anchor", HAND_ANCHOR, " max straight reach shoulder->wrist", round(out["upper_arm.R"] + out["forearm.R"], 3))

def place_target(side, world):  # world = Blender-space wrist target
    n = f"hand_tgt.{side}"
    pb[n].location = loc_world(n, world - J[f"wr.{side}"])
ns["apply_controls"]("cruise", 0)

def reach_test(side, x_sign, label, yaw_deg=0.0):
    rows = []
    sh0 = Vector(J[f"sh.{side}"])
    for lat in (0.20, 0.30, 0.40, 0.45, 0.50, 0.53, 0.56, 0.60):
        ns["apply_controls"]("cruise", 0)
        for nm in ("spine", "chest"):
            pb[nm].rotation_quaternion = q_world(nm, Vector((0, 0, 1)), math.radians(yaw_deg * 0.5))
        # wrist target: lat metres sideways of the (rest) shoulder, same forward, 12 cm below shoulder
        tgt = Vector((sh0.x + x_sign * lat, sh0.y, sh0.z - 0.12))
        place_target(side, tgt)
        P = ep()
        wr = P[f"forearm.{side}"].tail.copy(); sh = P[f"upper_arm.{side}"].head.copy()
        elb = P[f"upper_arm.{side}"].tail.copy()
        a = (sh - elb).normalized(); b = (wr - elb).normalized()
        ang = math.degrees(math.acos(max(-1, min(1, a.dot(b)))))
        rows.append((lat, round((wr - tgt).length * 1000, 1), round(ang, 0), round((wr - sh).length, 3)))
    print(label, "yaw", yaw_deg, "(lat m from rest shoulder, miss mm, elbow deg, |sh->wrist| m):", rows)

reach_test("R", -1, "giver R arm")
reach_test("R", -1, "giver R arm", yaw_deg=-25)   # chest/spine turned towards partner
reach_test("L", +1, "receiver L arm", yaw_deg=25)

# shoulder displacement caused by torso yaw (spine+chest)
for yaw in (0, 15, 25, 35):
    ns["apply_controls"]("cruise", 0)
    for nm, k in (("spine", 0.4), ("chest", 0.6)):
        pb[nm].rotation_quaternion = q_world(nm, Vector((0, 0, 1)), math.radians(-yaw * k))
    P = ep()
    sh = P["upper_arm.R"].head
    print(f"torso yaw {yaw:>2} deg toward right: R shoulder moves x {sh.x - J['sh.R'].x:+.3f} y {sh.y - J['sh.R'].y:+.3f} z {sh.z - J['sh.R'].z:+.3f}")
# arm on the bars: bike roll effect
ns["apply_controls"]("cruise", 0)
pb["bike"].rotation_quaternion = Quaternion((0, 1, 0), math.radians(1.5))
P = ep(); print("bars grip drift at 1.5 deg bike roll: ", round((P["bars"].head - Vector(ns["BAR_CLAMP"])).length * 1000, 1), "mm (bars origin)")
