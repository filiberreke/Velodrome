"""Two reference-inspired standing pizza guests and high table, in the crowd style.
Build with Blender --background --python build_pizza_friends.py.
"""
from pathlib import Path
import sys,math,json
import bpy,bmesh
from mathutils import Vector
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import people
from vlib import *
bpy.ops.wm.read_factory_settings(use_empty=True)
BASE_POSE=people.pose_joints
def pose(spec):
    j=BASE_POSE(spec)
    arms=[(1,D(0.23,0.29,1.19),D(0.8,-0.4,-0.5)),(-1,D(0.23,0.48,1.06),D(-0.7,-0.2,-0.6))] if ROLE=='striped' else [(-1,D(-0.27,0.35,1.32),D(-0.8,-0.4,-0.4))]
    for side,wrist,hint in arms:
        elbow,wrist=two_bone(j[f'sh{side}'],wrist,j['dm']['ua'],j['dm']['fa'],hint)
        j[f'elb{side}']=elbow;j[f'wr{side}']=wrist;j[f'hdir{side}']=D(0,0.85,0.25).normalized()
    return j
people.pose_joints=pose
palette={'skin':'e4b18e','hair':'504436','beard':'63594d','navy':'172c39','stripe':'eae9d9',
         'polo':'d9644d','trousers':'adb5b2','jeans':'67849a','shoe':'eee9d9','eye':'25231e',
         'mouth':'985b4b','glasses':'30363a','ivory':'f7eed5','gold':'e2bd62','wine':'6b2232',
         'glass':'c4ceca','crust':'c88b3e','cheese':'f0ca72','tomato':'bc4933','basil':'3b7945',
         'wood':'b48149','table_leg':'3c474b'}
colors={name:tuple(int(h[i:i+2],16)/255 for i in (0,2,4)) for name,h in palette.items()}

def glass(mb,j,side):
    wrist=j[f'wr{side}'];base=wrist+D(0,0.06,-0.025)
    # Opaque low-poly stemless wine glass; raised bowl sits in the mitten hand.
    sphere(mb,base+D(0,0,0.041),(0.052,0.052,0.036),'wine',None,(16,10))
    for k in range(4):
        a=k*math.tau/4
        tube(mb,[base+D(math.cos(a)*r,math.sin(a)*r,z) for r,z in [(0.02,0.008),(0.054,0.045),(0.052,0.09),(0.045,0.14)]],0.003,'glass',None,6,joints=False)
    torus(mb,base+D(0,0,0.142),Vector((0,0,1)),0.045,0.004,'ivory',None,16,5)

for ROLE in ['striped','polo']:
    spec=dict(sex='m',pose='stand_relaxed',hair='short',top='tshirt' if ROLE=='striped' else 'polo',bottom='trousers')
    mb,j,bones=people.build_person(spec,0)
    top='navy' if ROLE=='striped' else 'polo';bottom='jeans' if ROLE=='striped' else 'trousers'
    tags=['skin','hair',top,bottom,'shoe','eye','ivory','mouth','polo','glasses',top,'gold','mouth','hair']
    mb.ft=[tags[tag] for tag in mb.ft]
    body=build_object(mb,'ManGestreept' if ROLE=='striped' else 'ManRodePolo',mode='materials',colors=colors)
    if ROLE=='striped':
        # Actual garment cuts, so shirt stripes stay crisp from every angle.
        mesh=body.data;bm=bmesh.new();bm.from_mesh(mesh)
        lo=j['PELV'].z-0.02
        for k in range(18):
            for edge in [lo+k*0.065,lo+k*0.065+0.014]:
                bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=Vector((0,0,edge)),plane_no=Vector((0,0,1)),dist=1e-6)
        bm.to_mesh(mesh);bm.free();mesh.materials.append(make_mat('stripe',colors['stripe']));slot=len(mesh.materials)-1
        for face in mesh.polygons:
            p=sum((mesh.vertices[i].co for i in face.vertices),Vector())/len(face.vertices)
            if mesh.materials[face.material_index].name=='navy' and (p.z-lo)%0.065<0.014:face.material_index=slot
    prop=MB();hd=people.Head(prop,j,0)
    if ROLE=='striped':
        # Beard follows the existing head surface instead of floating in front of it.
        for u,v in [(-.45,-.28),(-.38,-.44),(-.27,-.57),(-.12,-.64),(0,-.66),(.12,-.64),(.27,-.57),(.38,-.44),(.45,-.28)]:
            hd.decal(u,v,0.12,0.14,0.025,'beard',lift=0.024,segs=(8,5))
        for u in [-.18,.18]:hd.decal(u,-.25,0.16,0.055,0.02,'beard',lift=0.02,segs=(8,5))
        glass(prop,j,1)
        centre=j['wr-1']+D(0,0.08,0.073)
        cyl(prop,centre,centre+D(0,0,0.018),0.25,'ivory',None,32)
        cyl(prop,centre+D(0,0,0.018),centre+D(0,0,0.037),0.226,'crust',None,32)
        cyl(prop,centre+D(0,0,0.038),centre+D(0,0,0.045),0.204,'tomato',None,32)
        for k in range(15):
            a=k*2.399;r=0.17*math.sqrt((k+.5)/15);p=centre+D(math.cos(a)*r,math.sin(a)*r,0.048)
            sphere(prop,p,(0.027,0.025,0.005),'cheese' if k%3 else 'basil',None,(8,4))
    else:
        # Angular rectangular spectacles matching the strong dark frames in the photo.
        for side in [-1,1]:
            pts=[hd.surf(side*.27+u,v,0.065)[0] for u,v in [(-.23,.22),(.23,.22),(.23,-.14),(-.23,-.14),(-.23,.22)]]
            tube(prop,pts,0.006,'glasses',None,8,joints=False)
        hd.line([(-.06,.06),(0,.09),(.06,.06)],.045,'glasses',lift=.065)
        glass(prop,j,-1)
        torus(prop,j['wr-1'],(j['wr-1']-j['elb-1']).normalized(),0.038,0.005,'gold',None,16,5)
        # Small dark polo badge with a gold edge.
        box(prop,D(-.095,.127,1.42),(.045,.008,.045),'gold',None)
        box(prop,D(-.095,.133,1.42),(.036,.006,.036),'navy',None)
    details=build_object(prop,'BaardPizzaEnWijn' if ROLE=='striped' else 'BrilEnWijn',mode='materials',colors=colors)
    for obj in [body,details]:obj.location=D(-.67 if ROLE=='striped' else .67,-.28,0)

table=MB()
cyl(table,D(0,.30,1.015),D(0,.30,1.065),.59,'wood',None,32)
cyl(table,D(0,.30,.06),D(0,.30,1.015),.065,'table_leg',None,16)
cyl(table,D(0,.30,.015),D(0,.30,.065),.33,'table_leg',None,24)
torus(table,D(0,.30,.30),Vector((0,0,1)),.24,.015,'table_leg',None,24,6)
build_object(table,'StatafelPizza',mode='materials',colors=colors)
OUT=HERE.parents[1]/'people';OUT.mkdir(exist_ok=True)
target=OUT/'pizza_vrienden_statafel.glb'
bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_yup=True,export_normals=True,export_animations=False)
print('PIZZA_FRIENDS_EXPORTED',target)
print('PIZZA_FRIENDS_VERTICES',sum(len(o.data.vertices) for o in bpy.data.objects if o.type=='MESH'))
