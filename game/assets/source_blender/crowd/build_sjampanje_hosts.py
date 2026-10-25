"""Two stylised champagne hosts using the game's existing crowd modelling library.
Reference cues: lanky orange suit/cap/scarf, stout olive coat/striped shirt/top hat.
Run with Blender --background --python this_file.py. Static service poses, opaque props.
"""
from pathlib import Path
import sys, math, json
import bpy, bmesh
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import people
from vlib import *

OUT=HERE.parents[1]/'bars/hosts'; OUT.mkdir(parents=True,exist_ok=True)
BASE_DIMS=people.body_dims; BASE_POSE=people.pose_joints

def rgb(value): return tuple(int(value[i:i+2],16)/255 for i in (0,2,4))

def body_dimensions(sex):
    d=BASE_DIMS(sex).copy()
    if STYLE=='orange':
        d.update(hw=0.085,sw=0.18,thigh=0.47,shin=0.47,ua=0.29,fa=0.28,head_r=0.127,
                 r_pel=(0.13,0.115),r_belly=(0.105,0.095),r_chest=(0.13,0.11),r_uch=(0.14,0.105),
                 r_thigh=0.068,r_calf=0.051,r_hip=0.08)
    else:
        d.update(hw=0.13,sw=0.235,thigh=0.31,shin=0.30,ua=0.25,fa=0.24,head_r=0.149,
                 r_pel=(0.255,0.215),r_belly=(0.265,0.225),r_chest=(0.255,0.215),r_uch=(0.21,0.18),
                 r_neck=0.066,r_hip=0.13,r_thigh=0.11,r_knee=0.075,r_calf=0.07)
    return d

def pose(spec):
    j=BASE_POSE(spec)
    if STYLE=='orange':
        for side,wrist,hint,hand in [(-1,D(-0.20,0.34,1.17),D(-0.8,-0.2,-0.6),D(0,0.85,0.2)),
                                     (1,D(0.22,-0.01,1.02),D(1,0,-0.1),D(-0.2,0,-1))]:
            elbow,wrist=two_bone(j[f'sh{side}'],wrist,j['dm']['ua'],j['dm']['fa'],hint)
            j[f'elb{side}']=elbow; j[f'wr{side}']=wrist; j[f'hdir{side}']=hand.normalized()
    return j

def coat_tail(mb,j,tag):
    # Open-front long coat; geometry is outside the torso, with no filled skirt.
    rx,rf=(0.15,0.13) if STYLE=='orange' else (0.29,0.245)
    top=j['BELLY'].z+0.08; bottom=j['PELV'].z-(0.20 if STYLE=='orange' else 0.24)
    segments=14
    for i in range(segments):
        a=math.radians(28)+math.radians(304)*i/segments
        b=math.radians(28)+math.radians(304)*(i+1)/segments
        points=[]
        for t,height in [(a,top),(b,top),(b,bottom),(a,bottom)]:
            points.append(D(math.sin(t)*rx,math.cos(t)*rf,height))
        mb.add(points,[[0,1,2,3]],tag,None,smooth=False)
        mb.add(points,[[3,2,1,0]],tag,None,smooth=False)

def extras(j,colors):
    mb=MB(); head=j['HEAD_C']; z=head.z
    if STYLE=='orange':
        # A long soft nose and cap brim echo the reference without photographic detail.
        sphere(mb,D(0,0.160,z-0.012),(0.054,0.122,0.044),'host_skin',None,(14,8))
        for side in [-1,1]:
            for k in range(4):
                tube(mb,[D(side*0.105,-0.045-k*0.012,z+0.02),D(side*(0.135+k*0.006),-0.07-k*0.012,z-0.07),
                         D(side*(0.12+k*0.006),-0.08-k*0.012,z-0.12)],0.003,'host_hair',None,6,joints=False)
        # Folded white neckerchief and its two loose ends.
        torus(mb,j['NECK_T']-j['nd']*0.035,j['nd'],0.060,0.012,'host_ivory',None,20,6)
        sphere(mb,D(0,0.085,j['NECK_T'].z-0.06),(0.025,0.022,0.024),'host_ivory',None,(10,6))
        for side in [-1,1]:
            mb.add([D(0,0.10,j['NECK_T'].z-0.06),D(side*0.055,0.135,j['NECK_T'].z-0.14),
                    D(side*0.008,0.14,j['NECK_T'].z-0.18)],[[0,1,2]],'host_ivory',None,smooth=False)
        # Round tray rests on the raised palm, not suspended in front of it.
        wrist=j['wr-1']; tray=wrist+D(0,0.085,0.073)
        cyl(mb,tray-Vector((0,0,0.014)),tray+Vector((0,0,0.014)),0.345,'host_tray',None,24)
        torus(mb,tray+Vector((0,0,0.012)),Vector((0,0,1)),0.333,0.012,'host_tray_rim',None,24,6)
        for index in range(7):
            angle=math.tau*(index-1)/6
            p=tray+Vector((0,0,0.027))+(D(math.sin(angle)*0.225,math.cos(angle)*0.225,0) if index else Vector())
            cyl(mb,p,p+Vector((0,0,0.015)),0.035,'host_ivory',None,10)
            cyl(mb,p+Vector((0,0,0.015)),p+Vector((0,0,0.12)),0.006,'host_ivory',None,8)
            cyl(mb,p+Vector((0,0,0.12)),p+Vector((0,0,0.245)),0.025,'host_champagne',None,12,r2=0.039)
            torus(mb,p+Vector((0,0,0.245)),Vector((0,0,1)),0.039,0.005,'host_ivory',None,12,5)
    else:
        # Tall black hat, blue ribbon, round nose and scruffy dark whiskers.
        brim=head+D(0,-0.006,0.136)
        cyl(mb,brim-Vector((0,0,0.017)),brim+Vector((0,0,0.017)),0.225,'host_black',None,16)
        cyl(mb,brim+Vector((0,0,0.02)),brim+Vector((0,0,0.33)),0.153,'host_black',None,12,r2=0.18)
        cyl(mb,brim+Vector((0,0,0.025)),brim+Vector((0,0,0.085)),0.156,'host_blue',None,16,r2=0.162)
        sphere(mb,head+D(0,0.185,-0.012),(0.079,0.102,0.053),'host_skin',None,(14,8))
        sphere(mb,head+D(0,0.105,-0.126),(0.12,0.080,0.064),'host_beard',None,(14,8))
        for side in [-1,1]:
            for k in range(6):
                p=head+D(side*(0.025+0.015*k),0.17-0.005*k,-0.112)
                tube(mb,[p,p+D(side*0.009,0.01,-0.04-(k%2)*0.015)],0.003,'host_beard',None,5,joints=False)
            for k in range(3):
                tube(mb,[D(side*0.13,-0.025,z),D(side*(0.17+k*0.006),-0.05-k*0.01,z-0.06)],0.003,'host_hair',None,5,joints=False)
        # A small tooth and simple smile remain legible at infield scale.
        sphere(mb,head+D(0,0.183,-0.098),(0.034,0.010,0.016),'host_black',None,(10,6))
        box(mb,head+D(0.006,0.195,-0.099),(0.019,0.011,0.020),'host_ivory',None)
    coat_tail(mb,j,'host_orange' if STYLE=='orange' else 'host_olive')
    return mb

for STYLE in ['green','orange']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    people.body_dims=body_dimensions; people.pose_joints=pose
    spec=dict(sex='m',pose='stand_counter' if STYLE=='green' else 'stand_relaxed',
              hair='buzz' if STYLE=='green' else 'cap',top='blazer',bottom='trousers')
    mb,j,bones=people.build_person(spec,0)
    palette={'host_skin':'e9bb8e','host_hair':'333129','host_ivory':'fff3d1','host_black':'151b18',
             'host_orange':'bd622f','host_orange_shadow':'9c4b28','host_olive':'858b3d','host_olive_shadow':'67732c',
             'host_yellow':'f3d94b','host_blue':'2580b1','host_shoe':'80522a','host_beard':'32362b',
             'host_tray':'505951','host_tray_rim':'b9a875','host_champagne':'e9d58a','host_mouth':'9c5c45'}
    colors={name:rgb(value) for name,value in palette.items()}
    coat='host_orange' if STYLE=='orange' else 'host_olive'
    shadow='host_orange_shadow' if STYLE=='orange' else 'host_olive_shadow'
    tags=['host_skin','host_hair',coat,'host_orange' if STYLE=='orange' else 'host_black','host_shoe',
          'host_black','host_ivory','host_mouth','host_orange' if STYLE=='orange' else 'host_blue',
          'host_black',shadow,'host_tray_rim','host_mouth','host_hair']
    mb.ft=[tags[tag] for tag in mb.ft]
    body=build_object(mb,'ToogUitbaterModel' if STYLE=='green' else 'PlateauUitbaterModel',mode='materials',colors=colors)
    if STYLE=='green':
        # Crisp blue/yellow shirt visible through the open olive jacket.
        bm=bmesh.new(); bm.from_mesh(body.data)
        lo=j['PELV'].z+0.035; hi=j['UCHEST'].z+0.025
        for i in range(1,10):
            bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                plane_co=Vector((0,0,lo+i*0.06)),plane_no=Vector((0,0,1)),dist=0.000001)
        bm.to_mesh(body.data); bm.free()
        for name in ['host_blue','host_yellow']:
            body.data.materials.append(make_mat(name,colors[name]))
        slots={m.name:i for i,m in enumerate(body.data.materials)}
        for face in body.data.polygons:
            p=sum((body.data.vertices[v].co for v in face.vertices),Vector())/len(face.vertices)
            if lo<p.z<hi and abs(p.x)<0.102 and p.y < -0.07:
                name='host_yellow' if int((p.z-lo)/0.06)%2==0 else 'host_blue'
                face.material_index=slots[name]
    details=extras(j,colors)
    props=build_object(details,'HoedBaardEnJaspanden' if STYLE=='green' else 'PlateauMetZevenGlazen',mode='materials',colors=colors)
    if STYLE=='orange': props['glass_count']=7
    target=OUT/('sjampanje_tooguitbater.glb' if STYLE=='green' else 'sjampanje_plateauuitbater.glb')
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_animations=False,export_yup=True,export_normals=True)
    print('HOST_EXPORTED',target)
    print('HOST_STATS',json.dumps({'style':STYLE,'vertices':sum(len(o.data.vertices) for o in [body,props]),
        'height':max(v.co.z for o in [body,props] for v in o.data.vertices)}))
