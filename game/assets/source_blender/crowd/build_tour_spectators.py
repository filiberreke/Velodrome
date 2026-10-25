"""Small long-haired chihuahua eating lasagne and an elderly banner supporter."""
from pathlib import Path
import sys,math,random
import bpy
from mathutils import Vector
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import people
from vlib import *
OUT=HERE.parents[1]/'people';OUT.mkdir(exist_ok=True)
palette={'fur':'d0a56c','cream':'f6e4bc','ear':'b57f66','nose':'28241f','eye':'201e1a',
         'dish':'b4bdc1','sauce':'a84e32','pasta':'e7c67c','cheese':'efda98',
         'skin':'e0b08f','grey':'a3a5a0','navy':'273c51','trousers':'606a70','shoe':'3c3d39',
         'white':'f5efde','glasses':'333c43','mouth':'a16d5e'}
colors={k:tuple(int(h[i:i+2],16)/255 for i in (0,2,4)) for k,h in palette.items()}
bpy.ops.wm.read_factory_settings(use_empty=True)
mb=MB()
sphere(mb,D(0,0,.23),(.12,.23,.12),'fur',None,(16,10))
sphere(mb,D(0,.15,.23),(.12,.11,.14),'cream',None,(14,10))
for side in [-1,1]:
    for f in [-.13,.14]:
        cyl(mb,D(side*.082,f,.22),D(side*.09,f+.015,.045),.026,'fur',None,10,r2=.022)
        sphere(mb,D(side*.09,f+.035,.035),(.035,.048,.025),'cream',None,(10,6))
sphere(mb,D(0,.245,.21),(.112,.105,.105),'fur',None,(18,12))
sphere(mb,D(0,.325,.14),(.055,.075,.047),'cream',None,(14,8))
sphere(mb,D(0,.381,.116),(.025,.025,.02),'nose',None,(10,6))
for side in [-1,1]:
    sphere(mb,D(side*.076,.31,.23),(.018,.012,.02),'eye',None,(10,6))
    sphere(mb,D(side*.072,.321,.238),(.005,.004,.006),'white',None,(8,4))
    ear=[D(side*.044,.21,.285),D(side*.13,.20,.28),D(side*.117,.20,.444)]
    mb.add(ear,[[0,1,2]],'fur',None,smooth=False)
    mb.add([ear[0]+D(side*.014,.005,.005),ear[1]+D(-side*.012,.005,.012),ear[2]+D(0,.005,-.035)],[[0,1,2]],'ear',None,smooth=False)
# Feathered ears, chest, flanks and high curled plume; fixed seed keeps exports stable.
rng=random.Random(250)
for side in [-1,1]:
    for k in range(20):
        f=-.18+k*.018;z=.24+rng.uniform(-.04,.04)
        tube(mb,[D(side*.095,f,z),D(side*(.13+rng.random()*.025),f-.015,z-.075),D(side*.115,f-.035,.11)],.008,'cream' if k%3==0 else 'fur',None,5,joints=False)
    for k in range(7):
        tube(mb,[D(side*(.075+k*.007),.22,.30),D(side*(.11+k*.007),.22,.25-k*.006)],.006,'cream',None,5,joints=False)
tail=[D(0,-.18,.29),D(.06,-.29,.39),D(.11,-.29,.47),D(.14,-.22,.49)]
tube(mb,tail,.03,'cream',None,12)
for k in range(10):tube(mb,[tail[1]+D(k*.004,0,0),tail[2]+D(k*.004,-.025,.015),tail[3]+D(k*.004,-.02,-.04)],.008,'cream',None,5,joints=False)
dog=build_object(mb,'LangharigeChihuahua',mode='materials',colors=colors)
food=MB();centre=D(0,.43,.025)
box(food,centre,(.31,.23,.04),'dish',None)
for side in [-1,1]:box(food,centre+D(side*.155,0,.018),(.015,.25,.045),'dish',None)
for z,c in [(0.025,'sauce'),(.035,'pasta'),(.045,'sauce'),(.055,'cheese')]:box(food,centre+D(0,0,z),(.275,.205,.012),c,None)
for k in range(12):sphere(food,centre+D(rng.uniform(-.12,.12),rng.uniform(-.08,.08),.064),(.018,.014,.004),'sauce',None,(8,4))
build_object(food,'Lasagneschotel',mode='materials',colors=colors)
bpy.ops.export_scene.gltf(filepath=str(OUT/'chihuahua_lasagne.glb'),export_format='GLB',export_yup=True,export_normals=True,export_animations=False)

bpy.ops.wm.read_factory_settings(use_empty=True)
original=people.pose_joints
def banner_pose(spec):
    j=original(spec)
    for side in [-1,1]:
        elbow,wrist=two_bone(j[f'sh{side}'],D(side*.46,.28,1.43),j['dm']['ua'],j['dm']['fa'],D(side*.8,-.4,-.2))
        j[f'elb{side}']=elbow;j[f'wr{side}']=wrist;j[f'hdir{side}']=D(0,1,0)
    return j
people.pose_joints=banner_pose
spec=dict(sex='m',pose='stand_relaxed',hair='short',top='longsleeve',bottom='trousers',glasses=True)
mb,j,bones=people.build_person(spec,0)
tags=['skin','grey','navy','trousers','shoe','eye','white','mouth','navy','glasses','navy','dish','mouth','grey']
mb.ft=[tags[tag] for tag in mb.ft]
build_object(mb,'OudereWoutSupporter',mode='materials',colors=colors)
cloth=MB();box(cloth,D(0,.34,1.38),(1.50,.025,.40),'white',None)
for side in [-1,1]:cyl(cloth,D(side*.73,.33,1.15),D(side*.73,.33,1.65),.012,'navy',None,10)
build_object(cloth,'SpandoekDoek',mode='materials',colors=colors)
bpy.ops.export_scene.gltf(filepath=str(OUT/'supporter_wout.glb'),export_format='GLB',export_yup=True,export_normals=True,export_animations=False)
print('TOUR_SPECTATORS_EXPORTED')
