"""Build the mixed-zone reporter using the game's existing cartoon people library.
Run with Blender --background --python this_file.py. No photo textures or external assets.
"""
from pathlib import Path
import sys, math, json
import bpy, bmesh
from mathutils import Vector, Matrix

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import people
from vlib import *

bpy.ops.wm.read_factory_settings(use_empty=True)
original_pose = people.pose_joints
def interview_pose(spec):
    joints = original_pose(spec)
    # Raised hand lines up with the existing microphone in the tent.
    shoulder = joints['sh-1']
    wrist = D(-0.10, 0.42, 1.34)
    elbow, wrist = two_bone(shoulder, wrist, joints['dm']['ua'], joints['dm']['fa'], D(-0.6,-0.3,-0.7))
    joints['elb-1'] = elbow; joints['wr-1'] = wrist
    joints['hdir-1'] = D(0.0, 0.9, 0.15).normalized()
    return joints
people.pose_joints = interview_pose
spec = dict(sex='f', pose='stand_talk', hair='bob', top='tshirt', bottom='shorts')
mb, joints, bones = people.build_person(spec, 0)
head = joints['HEAD_C']

# Extend the existing bob to the jaw/neck, with a gentle asymmetric side part.
hair_vertices = {index for face, tag in zip(mb.f, mb.ft) if tag == HAIR for index in face}
for index in hair_vertices:
    point = mb.v[index]
    if point.z < head.z: point.z = head.z + (point.z-head.z)*2.0
    if point.x < 0 and point.z > head.z: point.x -= 0.008

palette = {
    'skin': 'e9b990', 'hair_honey_blonde': 'a87942', 'jersey_white': 'faf9f3',
    'denim': '5687b0', 'denim_cuff': '88afd0', 'shoe': 'e8e8e0', 'eye': '241c16',
    'mouth': '904f42', 'accent': 'e8e8e0', 'dark': '202a34', 'metal': 'afbbc0',
    'brow': '77512e', 'rainbow_blue': '1497d4', 'rainbow_black': '15191d',
    'rainbow_red': 'd9303c', 'rainbow_yellow': 'f2d035', 'rainbow_green': '329447',
    'hair_highlight': 'c49b62', 'glasses_frame': '243445', 'glasses_lens': '213e4b',
}
def srgb(hex): return tuple(int(hex[i:i+2],16)/255.0 for i in (0,2,4))
colors = {name: srgb(hex) for name, hex in palette.items()}
tags = ['skin','hair_honey_blonde','jersey_white','denim','shoe','eye','jersey_white',
        'mouth','accent','dark','jersey_white','metal','mouth','brow']
mb.ft = [tags[tag] for tag in mb.ft]
body = build_object(mb,'JournalisteRegenboog',mode='materials',colors=colors)

# Cut genuine garment geometry at stripe boundaries so colours are crisp even
# at close range, without texture sampling or a game-specific clothes shader.
mesh = body.data
bm = bmesh.new(); bm.from_mesh(mesh)
def cut(point, normal):
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
        plane_co=point,plane_no=normal,dist=0.000001,clear_inner=False,clear_outer=False)
for height in [0.74,0.765,0.99,1.10,1.124,1.148,1.172,1.196,1.22]: cut(Vector((0,0,height)),Vector((0,0,1)))
for side in [-1,1]:
    start,end=bones[f'upper_arm.{"L" if side==1 else "R"}']
    for t in [0.20,0.26,0.32,0.38,0.44,0.50]: cut(start.lerp(end,t),(end-start).normalized())
bm.to_mesh(mesh); bm.free()
slots = {mat.name:i for i,mat in enumerate(mesh.materials)}
for name in ['denim_cuff','rainbow_blue','rainbow_black','rainbow_red','rainbow_yellow','rainbow_green']:
    mesh.materials.append(make_mat(name,colors[name])); slots[name]=len(mesh.materials)-1
rainbow=['rainbow_blue','rainbow_red','rainbow_black','rainbow_yellow','rainbow_green']
for face in mesh.polygons:
    centre=sum((mesh.vertices[i].co for i in face.vertices),Vector())/len(face.vertices)
    name=mesh.materials[face.material_index].name
    # A clean untucked jersey hem, instead of polygon-dependent zigzags.
    if name in ('denim','jersey_white') and 0.90<centre.z<1.04 and abs(centre.x)<0.20:
        name='jersey_white' if centre.z>=0.99 else 'denim'
        face.material_index=slots[name]
    if name=='denim':
        if centre.z<0.74: face.material_index=slots['skin']
        elif centre.z<0.765: face.material_index=slots['denim_cuff']
    if name!='jersey_white': continue
    if abs(centre.x)<0.16 and 1.10<centre.z<1.22:
        face.material_index=slots[rainbow[min(4,int((1.22-centre.z)/0.024))]]
    elif abs(centre.x)>=0.16:
        side='L' if centre.x>0 else 'R'
        distance,t=seg_dist(centre,*bones[f'upper_arm.{side}'])
        if 0.20<t<0.50: face.material_index=slots[rainbow[min(4,int((t-0.20)/0.06))]]

# Sunglasses sit above the forehead in the hair, leaving the face unobstructed.
details=MB()
tilt=Matrix.Rotation(math.radians(55),3,'X')
for side in [-1,1]:
    centre=D(side*0.053,0.068,head.z+0.123)
    sphere(details,centre,(0.046,0.029,0.006),'glasses_lens',None,(16,8),M=tilt)
    points=[centre+tilt@Vector((math.cos(a)*0.048,math.sin(a)*0.031,0)) for a in [math.tau*i/24 for i in range(25)]]
    tube(details,points,0.004,'glasses_frame',None,8,joints=False)
    tube(details,[centre+D(side*0.044,0,0),D(side*0.13,0.015,head.z+0.10),D(side*0.13,-0.045,head.z+0.055)],0.004,'glasses_frame',None,8)
tube(details,[D(-0.008,0.068,head.z+0.13),D(0,0.075,head.z+0.133),D(0.008,0.068,head.z+0.13)],0.004,'glasses_frame',None,8)
# Fine blond strands follow the outer sides of the bob.
for side in [-1,1]:
    for j in range(3):
        tube(details,[D(side*(0.105+j*0.009),0.04-j*0.03,head.z+0.09),
            D(side*(0.138+j*0.004),0.035-j*0.03,head.z-0.015),
            D(side*(0.124+j*0.006),0.02-j*0.03,head.z-0.14)],0.002,'hair_highlight',None,6,joints=False)
# A narrow rainbow collar around the base of the neck.
for i,name in enumerate(rainbow):
    torus(details,joints['NECK_T']-joints['nd']*(0.072+i*0.005),joints['nd'],0.049,0.0035,name,None,24,6)
accessories=build_object(details,'ZonnebrilEnHaaraccenten',mode='materials',colors=colors)

out=HERE.parents[1]/'people'
out.mkdir(exist_ok=True)
target=out/'journaliste_regenboog.glb'
bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_animations=False,
    export_yup=True,export_apply=True,export_normals=True)
print('JOURNALIST_EXPORTED',target)
print('JOURNALIST_STATS',json.dumps({'vertices':sum(len(o.data.vertices) for o in [body,accessories]),
    'height':max(v.co.z for o in [body,accessories] for v in o.data.vertices)}))
