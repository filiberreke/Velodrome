"""Reference-inspired low-poly mixed-zone trio, using the existing crowd library.
Blender --background --python build_mixed_interviews.py; no photo textures.
"""
from pathlib import Path
import sys,math,json
import bpy,bmesh
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import people
from vlib import *
OUT=HERE.parents[1]/'people'; OUT.mkdir(exist_ok=True)
BASE_POSE=people.pose_joints

def pose(spec):
    j=BASE_POSE(spec)
    if ROLE=='reporter':
        for side,wrist,hint in [(-1,D(-0.08,0.45,1.34),D(-0.6,-0.3,-0.7)),
                                (1,D(0.30,0.15,1.20),D(0.8,-0.3,-0.5))]:
            elbow,wrist=two_bone(j[f'sh{side}'],wrist,j['dm']['ua'],j['dm']['fa'],hint)
            j[f'elb{side}']=elbow;j[f'wr{side}']=wrist;j[f'hdir{side}']=D(0,0.9,0.1).normalized()
    return j
people.pose_joints=pose

def colour(h):return tuple(int(h[i:i+2],16)/255 for i in (0,2,4))

def front_point(body,x,z,lift=0.003):
    hit,p,normal,index=body.ray_cast(Vector((x,-1,z)),Vector((0,1,0)))
    return p+Vector((0,-lift,0)) if hit else Vector((x,-0.16,z))

def champion(body,j,colours):
    # Cut the real garment mesh for clean horizontal blue/cyan chest bands.
    mesh=body.data; bm=bmesh.new();bm.from_mesh(mesh)
    for height in [0.985,1.285,1.335]:
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
            plane_co=Vector((0,0,height)),plane_no=Vector((0,0,1)),dist=1e-6)
    bm.to_mesh(mesh);bm.free()
    for key in ['ek_blue','ek_cyan']:mesh.materials.append(make_mat(key,colours[key]))
    slots={m.name:i for i,m in enumerate(mesh.materials)}
    for face in mesh.polygons:
        p=sum((mesh.vertices[i].co for i in face.vertices),Vector())/len(face.vertices)
        name=mesh.materials[face.material_index].name
        if name=='ek_white' and abs(p.x)<0.19:
            if 0.985<p.z<1.285:face.material_index=slots['ek_blue']
            elif 1.285<p.z<1.335:face.material_index=slots['ek_cyan']
    mesh.update();bpy.context.view_layer.update()
    details=MB()
    # Twelve small five-point stars follow the actual curved front of the jersey.
    for index in range(12):
        angle=math.tau*index/12
        cx=math.sin(angle)*0.087;cz=1.14+math.cos(angle)*0.103
        points=[front_point(body,cx,cz)]
        for k in range(10):
            a=math.pi/2+math.tau*k/10;r=0.019 if k%2==0 else 0.008
            points.append(front_point(body,cx+math.cos(a)*r,cz+math.sin(a)*r,0.004))
        details.add(points,[[0,1+k,1+(k+1)%10] for k in range(10)],'ek_gold',None,smooth=False)
    if ROLE=='female':
        # A medal on a navy ribbon echoes the reference without hiding the chest band.
        neck=j['NECK_T']
        for side in [-1,1]:
            tube(details,[neck+D(side*0.055,0.025,-0.02),D(side*0.075,0.17,1.31),D(0,0.19,1.02)],
                 0.012,'ek_navy',None,6,joints=False)
        cyl(details,D(0,0.19,1.01),D(0,0.205,1.01),0.034,'ek_gold',None,16)
    obj=build_object(details,'EuropeseSterrenEnMedaille',mode='materials',colors=colours)
    obj['jersey_stars']=12
    return obj

for ROLE in ['reporter','male','female']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    spec=dict(sex='f' if ROLE=='female' else 'm',pose='stand_relaxed',
        hair='bun' if ROLE=='female' else 'short',top='longsleeve',
        bottom='trousers' if ROLE=='reporter' else 'shorts')
    mb,j,bones=people.build_person(spec,0)
    palette={'skin':'e5b69a','hair':'9c9e96' if ROLE=='reporter' else ('786341' if ROLE=='female' else '74533d'),
             'ek_white':'f5f4ee','ek_blue':'1e53b6','ek_cyan':'70c4eb','ek_gold':'f5cf32',
             'ek_navy':'172840','sweater':'152526','trousers':'263133','shoe':'eeeeea' if ROLE!='reporter' else '25292c',
             'eye':'26211d','mouth':'a56757','brow':'797b73' if ROLE=='reporter' else '634c38',
             'mic':'171d22','mic_blue':'254d94','metal':'abb8ba'}
    colors={name:colour(h) for name,h in palette.items()}
    top='sweater' if ROLE=='reporter' else 'ek_white';bottom='trousers' if ROLE=='reporter' else 'ek_navy'
    tags=['skin','hair',top,bottom,'shoe','eye','ek_white','mouth','ek_navy','mic',top,'metal','mouth','brow']
    mb.ft=[tags[tag] for tag in mb.ft]
    body=build_object(mb,'JournalistGrijsModel' if ROLE=='reporter' else 'EuropeesKampioenModel',mode='materials',colors=colors)
    extras=[]
    if ROLE=='reporter':
        prop=MB();w=j['wr-1']
        # Hand-held interview microphone points forward towards the rider's mouth.
        a=w+D(0,0.015,-0.035);b=w+D(0,0.19,0.09)
        cyl(prop,a,b,0.018,'mic',None,12)
        sphere(prop,b+D(0,0.065,0.025),(0.058,0.080,0.061),'mic',None,(14,8))
        box(prop,w+D(0,0.13,0.04),(0.08,0.07,0.075),'mic_blue',None)
        # Dark wristwatch and discreet pale chest emblem.
        torus(prop,j['wr1'],(j['wr1']-j['elb1']).normalized(),0.039,0.009,'mic',None,16,6)
        torus(prop,D(-0.095,0.13,1.43),D(0,1,0),0.015,0.003,'ek_white',None,12,5)
        extras.append(build_object(prop,'MicrofoonEnHorloge',mode='materials',colors=colors))
    else:extras.append(champion(body,j,colors))
    target=OUT/({'reporter':'journalist_grijs','male':'renner_europees_kampioen','female':'renster_europees_kampioen'}[ROLE]+'.glb')
    body['reference_role']=ROLE
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_yup=True,export_animations=False,export_normals=True)
    print('INTERVIEW_MODEL',json.dumps({'role':ROLE,'file':str(target),'vertices':sum(len(o.data.vertices) for o in [body,*extras])}))
