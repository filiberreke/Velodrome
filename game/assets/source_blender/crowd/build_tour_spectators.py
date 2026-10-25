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
palette.update(straw='bf9253',straw_light='dcbb7f',hat_band='8d6b3d',check_blue='789fae',check_orange='c6a174',check_light='e1d4b9')
colors={k:tuple(int(h[i:i+2],16)/255 for i in (0,2,4)) for k,h in palette.items()}
def banner_pose(spec):
    j=original(spec)
    side=-1 if ROLE=='older' else 1
    elbow,wrist=two_bone(j[f'sh{side}'],D(side*.58,.17,1.68),j['dm']['ua'],j['dm']['fa'],D(side*.8,-.3,-.2))
    j[f'elb{side}']=elbow;j[f'wr{side}']=wrist;j[f'hdir{side}']=D(0,0,1)
    return j
people.pose_joints=banner_pose
for ROLE in ['older','straw']:
    shift=-1.26 if ROLE=='older' else 1.26
    spec=dict(sex='m',pose='stand_relaxed',hair='short',top='longsleeve',bottom='trousers',glasses=True)
    mb,j,bones=people.build_person(spec,0)
    tags=['skin','grey','navy' if ROLE=='older' else 'check_blue','trousers','shoe','eye','white','mouth','navy','glasses','navy','dish','mouth','grey']
    mb.ft=[tags[tag] for tag in mb.ft]
    body=build_object(mb,'OudereWoutSupporter' if ROLE=='older' else 'StrohoedWoutSupporter',mode='materials',colors=colors)
    body.location=D(shift,0,0)
    if ROLE=='straw':
        # Fine geometric plaid, cut into the actual shirt mesh on both axes.
        import bmesh
        mesh=body.data;bm=bmesh.new();bm.from_mesh(mesh)
        for axis,lo,hi,step in [(2,.92,1.60,.045),(0,-.55,.55,.045)]:
            n=int((hi-lo)/step)+1
            for k in range(n):
                for delta in [0,.008]:
                    point=Vector((0,0,0));point[axis]=lo+k*step+delta
                    normal=Vector((0,0,0));normal[axis]=1
                    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=point,plane_no=normal,dist=1e-6)
        bm.to_mesh(mesh);bm.free()
        for name in ['check_orange','check_light']:mesh.materials.append(make_mat(name,colors[name]))
        slots={m.name:i for i,m in enumerate(mesh.materials)}
        for face in mesh.polygons:
            if mesh.materials[face.material_index].name!='check_blue':continue
            p=sum((mesh.vertices[i].co for i in face.vertices),Vector())/len(face.vertices)
            hz=(p.z-.92)%.045<.008;vx=(p.x+.55)%.045<.008
            if hz or vx:face.material_index=slots['check_light' if hz and vx else 'check_orange']
        hat=MB();head=j['HEAD_C'];up=Vector((0,0,1));centre=head+up*.12
        # Broad straw brim, pinched crown, brown woven band and short brim strokes.
        sphere(hat,centre,(.245,.22,.025),'straw_light',None,(32,8))
        cyl(hat,centre,centre+up*.18,.13,'straw',None,18,r2=.098)
        sphere(hat,centre+up*.18,(.105,.115,.028),'straw_light',None,(18,6))
        cyl(hat,centre+up*.018,centre+up*.055,.133,'hat_band',None,20,r2=.128)
        for k in range(28):
            a=k*math.tau/28
            tube(hat,[centre+Vector((math.cos(a)*r,math.sin(a)*r,.025)) for r in [.155,.218]],.0015,'straw',None,4,joints=False)
        obj=build_object(hat,'Strohoed',mode='materials',colors=colors);obj.location=D(shift,0,0)
cloth=MB();box(cloth,D(0,.19,2.52),(3.80,.032,.90),'white',None)
build_object(cloth,'SpandoekDoek',mode='materials',colors=colors)
poles=MB()
for side in [-1,1]:
    cyl(poles,D(side*1.84,.19,1.05),D(side*1.84,.19,3.02),.022,'hat_band',None,12)
build_object(poles,'SpandoekStokken',mode='materials',colors=colors)
bpy.ops.export_scene.gltf(filepath=str(OUT/'supporter_wout.glb'),export_format='GLB',export_yup=True,export_normals=True,export_animations=False)
print('TOUR_SPECTATORS_EXPORTED')
