"""Editable, parametric mid-poly track bike. Run: python build_track_bike.py
Requires trimesh, numpy. Exports a multi-mesh glTF binary for Godot 4.
Coordinates: X transverse, Y up, +Z forward; dimensions in metres.
"""
from pathlib import Path
import numpy as np
import trimesh
from trimesh.transformations import rotation_matrix

OUT = Path(__file__).resolve().parents[2] / 'godot/assets/bikes/track_bike.glb'
scene=trimesh.Scene()
palette={
 'FRAME': [31,35,41,255], 'DARK': [21,24,29,255], 'RUBBER':[11,13,17,255],
 'CARBON':[34,40,48,255], 'METAL':[145,151,162,255], 'CHROME':[190,197,207,255],
 'TAPE':[16,19,23,255], 'CHAIN':[91,98,107,255], 'WHITE':[239,231,200,255]}
# Explicit glTF PBR materials are essential: relying on vertex colors alone
# caused imported wheels and frame to appear almost entirely white in Godot.
from trimesh.visual.material import PBRMaterial
from trimesh.visual.texture import TextureVisuals
materials = {}
for label, rgba in palette.items():
    is_metal = label in ('FRAME', 'METAL', 'CHROME', 'CHAIN')
    roughness = {'FRAME': .48, 'CARBON': .64, 'RUBBER': .92,
                 'CHROME': .29, 'METAL': .40, 'TAPE': .86}.get(label, .67)
    materials[label] = PBRMaterial(
        name='V250_' + label,
        baseColorFactor=[x / 255.0 for x in rgba],
        metallicFactor=.48 if is_metal else .02,
        roughnessFactor=roughness,
        doubleSided=True,
    )
count=0

def add(name,mesh,mat):
 global count
 mesh.visual = TextureVisuals(material=materials[mat])
 scene.add_geometry(mesh,geom_name=f'{name}_{count:03d}')
 count+=1

def rod(name,a,b,r,mat='FRAME',sections=12):
 a=np.array(a,float); b=np.array(b,float)
 d=b-a; length=np.linalg.norm(d)
 if length<1.e-6:return
 m=trimesh.creation.cylinder(radius=r,height=length,sections=sections)
 tf=trimesh.geometry.align_vectors([0,0,1],d/length)
 m.apply_transform(tf); m.apply_translation((a+b)/2)
 add(name,m,mat)

def ball(name,center,r,mat):
 m=trimesh.creation.icosphere(subdivisions=1,radius=r)
 m.apply_translation(center); add(name,m,mat)

def tube_path(name,points,r,mat,sections=9):
 for k in range(len(points)-1):rod(f'{name}_{k}',points[k],points[k+1],r,mat,sections)
 for k,p in enumerate(points[1:-1]):ball(name+'_bend',p,r,mat)

WHEEL_HUB_Y = 0.420
REAR_Z = -0.69
FRONT_Z = 0.69

def disk(name,z,r,width,mat):
 # Cylinder axis naturally Z: turn onto X, and move to wheel center.
 m=trimesh.creation.cylinder(radius=r,height=width,sections=48)
 m.apply_transform(rotation_matrix(np.pi/2,[0,1,0]))
 m.apply_translation([0,WHEEL_HUB_Y,z]); add(name,m,mat)

def ring(name,z,r,minor,offset,mat):
 # Torus about wheel axle X, with quad-ring segments; strong circular highlight.
 verts=[]; faces=[]; N=48; M=7
 for i in range(N):
  th=2*np.pi*i/N
  for j in range(M):
   ph=2*np.pi*j/M
   verts.append([offset+minor*np.sin(ph),WHEEL_HUB_Y+(r+minor*np.cos(ph))*np.sin(th),z+(r+minor*np.cos(ph))*np.cos(th)])
 for i in range(N):
  for j in range(M):
   a=i*M+j;b=((i+1)%N)*M+j;c=((i+1)%N)*M+(j+1)%M;d=i*M+(j+1)%M
   faces.extend([[a,b,c],[a,c,d]])
 add(name,trimesh.Trimesh(vertices=verts,faces=faces,process=False),mat)

# Solid discs, tyre, rim, lockring, centre boss (track cycling wheels).
for label,z in [('rear',REAR_Z),('front',FRONT_Z)]:
 disk(f'{label}_carbon_disc',z,.400,.010,'CARBON')
 ring(f'{label}_tyre',z,.410,.009,0,'RUBBER')
 for side in (-1,1):
  ring(f'{label}_polished_rim',z,.400,.0035,side*.007,'METAL')
  ring(f'{label}_disc_highlight',z,.305,.0015,side*.006,'DARK')
 rod(f'{label}_hub',[-.046,WHEEL_HUB_Y,z],[.046,WHEEL_HUB_Y,z],.029,'CHROME')
 for side in (-1,1):
  ball(f'{label}_axle_nut',[side*.05,WHEEL_HUB_Y,z],.015,'METAL')

rear=[0,WHEEL_HUB_Y,REAR_Z]; front=[0,WHEEL_HUB_Y,FRONT_Z]; bb=[0,.49,-.09]
seat=[0,1.02,-.27]; headtop=[0,1.02,.48]; headbottom=[0,.82,.56]
for name,a,b,r in [
 ('down_tube',bb,headbottom,.038),('top_tube',seat,headtop,.032),
 ('seat_tube',bb,seat,.035),('head_tube',headbottom,headtop,.043),
 ('fork_steerer',headbottom,front,.035)]:rod(name,a,b,r)
for side in (-1,1):
 x=side*.059
 rod('chainstay',[x,.49,-.09],[side*.053,WHEEL_HUB_Y,REAR_Z],.016)
 rod('seatstay',[side*.042,.97,-.27],[side*.053,WHEEL_HUB_Y,REAR_Z],.014)
 rod('fork_blade',[side*.044,.82,.56],[side*.052,WHEEL_HUB_Y,FRONT_Z],.019)
# Top tube junction and seat tube clamp
rod('seatpost',[0,.98,-.27],[0,1.10,-.29],.023,'METAL')
rod('seat_rails',[-.057,1.095,-.34],[.057,1.095,-.34],.014,'METAL')
saddle=trimesh.creation.icosphere(subdivisions=2,radius=1)
saddle.apply_scale([.082,.023,.167]);saddle.apply_translation([0,1.109,-.355]);add('racing_saddle',saddle,'DARK')
# Stem, classic compact track drops, no brakes or gear shifters.
rod('stem',[0,1.03,.48],[0,1.14,.58],.024,'METAL')
rod('handlebar_top',[-.29,1.14,.58],[.29,1.14,.58],.019,'CHROME')
for side in (-1,1):
 x=side*.29
 pts=[[x,1.14,.58],[x,1.14,.70],[x,1.085,.77],[x,.975,.78],[x,.905,.72],[x,.895,.62]]
 tube_path('classic_drop',pts,.018,'TAPE')
# Crankset, narrow track chainring, no derailleur.
rod('bottom_bracket',[-.12,.49,-.09],[.12,.49,-.09],.038,'METAL')
# Chainring in bicycle YZ plane, centred on the bottom bracket.
def drivetrain_ring(name,x,cy,cz,r,minor,mat):
 verts=[];faces=[];N=32;M=6
 for i in range(N):
  t=2*np.pi*i/N
  for j in range(M):
   p=2*np.pi*j/M
   verts.append([x+minor*np.sin(p),cy+(r+minor*np.cos(p))*np.sin(t),cz+(r+minor*np.cos(p))*np.cos(t)])
 for i in range(N):
  for j in range(M):
   a=i*M+j;b=((i+1)%N)*M+j;c=((i+1)%N)*M+(j+1)%M;d=i*M+(j+1)%M
   faces.extend([[a,b,c],[a,c,d]])
 add(name,trimesh.Trimesh(vertices=verts,faces=faces,process=False),mat)
drivetrain_ring('chainring',-.103,.49,-.09,.137,.011,'CHROME')
# Dynamic crank arms and pedals are created by rider_visual.gd.
# Keeping them out of the GLB avoids static duplicates during pedalling.
# Right (-X) drivetrain: chainring, sprocket and two stationary chain runs.
# Facing the bicycle direction of travel (+Z), physical right is -X.
# This is the correct handedness in Godot and glTF (right = forward cross up).
drivetrain_ring('rear_sprocket',-.080,WHEEL_HUB_Y,REAR_Z,.063,.009,'METAL')
rod('chain_upper',[-.103,.49+.137,-.09],[-.080,WHEEL_HUB_Y+.063,REAR_Z],.006,'CHAIN')
rod('chain_lower',[-.103,.49-.137,-.09],[-.080,WHEEL_HUB_Y-.063,REAR_Z],.006,'CHAIN')

OUT.parent.mkdir(parents=True,exist_ok=True)
OUT.write_bytes(scene.export(file_type='glb'))
print(f'Generated: {OUT} | parts={count} | triangles={sum(len(g.faces) for g in scene.geometry.values())}')
