"""Standalone Wii/Mii-inspired EuroMaxCycling presenter study.
Blender --background --python build_mii_commentator.py
Original geometry, no facial image projection. Front=-Y; exported Godot front=+Z.
"""
from pathlib import Path
import bpy, math, json, bmesh
from mathutils import Vector

OUT=Path(__file__).resolve().parents[2]/'broadcast/commentators'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
M={}
def material(name,color,rough=.8):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
 M[name]=m
material('Skin',(0.71,.395,.205));material('Ear accent',(.57,.28,.14))
material('Brown hair',(.115,.053,.026));material('Hair groove',(.065,.027,.014))
material('Eye and mouth',(.012,.009,.008));material('Shirt',(.91,.92,.91))
material('Bottle green',(.007,.065,.050))
material('Collar shade',(.72,.75,.77));material('Navy trousers',(.033,.052,.085))
material('Shoes',(.022,.026,.034));material('Headset',(.028,.033,.042))
material('Headset inset',(.065,.075,.092));material('Lanyard',(.015,.06,.17))
material('Red accent',(.65,.015,.035));material('Teeth',(.98,.96,.9))
material('Eye white',(.95,.94,.90));material('Hazel iris',(.17,.075,.032));material('Soft lip',(.48,.245,.165))

def finish(o,name,mat):
 o.name=name;o.data.materials.append(M[mat]);return o
def sphere(name,p,r,mat,segments=40,rings=24):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=p)
 o=bpy.context.object;o.scale=r;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for f in o.data.polygons:f.use_smooth=True
 return finish(o,name,mat)
def mesh(name,verts,faces,mat,smooth=True):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);me.materials.append(M[mat])
 for f in me.polygons:f.use_smooth=smooth
 return o
def line(name,pts,r,mat):
 cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=8;cu.bevel_depth=r;cu.bevel_resolution=2
 sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(pts)-1)
 for v,p in zip(sp.bezier_points,pts):v.co=p;v.handle_left_type='AUTO';v.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(o);cu.materials.append(M[mat]);return o
def capsule(name,a,b,r,mat):
 a,b=Vector(a),Vector(b);d=b-a
 bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=r,depth=d.length,location=(a+b)/2)
 o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();finish(o,name,mat)
 for f in o.data.polygons:f.use_smooth=True
 sphere(name+' rounded end A',a,(r,r,r),mat,24,16)
 sphere(name+' rounded end B',b,(r,r,r),mat,24,16)
 return o

# Compact, deliberately simple Mii proportions: small rounded body, large head.
for side in [-1,1]:
 capsule('Trouser leg',(side*.085,.0,.16),(side*.085,.0,.51),.070,'Navy trousers')
 sphere('Rounded shoe',(side*.087,-.045,.086),(.085,.14,.067),'Shoes')
sphere('Hip',(0,.015,.49),(.165,.105,.12),'Navy trousers')
# One continuous tapered shirt, with shoulders integrated into its silhouette.
profiles=[(.50,.155,.100),(.53,.175,.110),(.71,.170,.115),(.90,.205,.110),(.98,.180,.095),(1.025,.085,.070)]
verts=[];faces=[];N=48
for z,rx,ry in profiles:
 for j in range(N):
  a=math.tau*j/N;verts.append((math.sin(a)*rx,.015-math.cos(a)*ry,z))
for i in range(len(profiles)-1):
 for j in range(N):faces.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
faces.extend([tuple(reversed(range(N))),tuple((len(profiles)-1)*N+j for j in range(N))])
shirt=mesh('Simple white shirt',verts,faces,'Shirt')
sub=shirt.modifiers.new('Soft Mii silhouette','SUBSURF');sub.levels=2;bpy.context.view_layer.objects.active=shirt;bpy.ops.object.modifier_apply(modifier=sub.name)
for side in [-1,1]:
 capsule('Sleeve',(side*.175,.015,.91),(side*.24,-.002,.73),.067,'Shirt')
 capsule('Sleeve forearm',(side*.24,-.002,.73),(side*.25,-.045,.59),.052,'Skin')
 sphere('Simple mitten hand',(side*.253,-.056,.53),(.060,.058,.072),'Skin',32,20)
 sphere('Thumb',(side*.210,-.081,.545),(.023,.027,.035),'Skin',24,16)
capsule('Short neck',(0,.018,.995),(0,.018,1.13),.073,'Skin')
# Small folded collar, no tall spikes or anatomical garment noise.
for side in [-1,1]:
 collar=mesh('Folded shirt collar',[(side*.018,-.063,1.026),(side*.080,-.066,1.015),(side*.102,-.098,.952),(side*.038,-.110,.974)],[(0,1,2,3)],'Bottle green',False)
 sol=collar.modifiers.new('Collar thickness','SOLIDIFY');sol.thickness=.006;bpy.context.view_layer.objects.active=collar;bpy.ops.object.modifier_apply(modifier=sol.name)
for z in [.91,.82,.73]:sphere('Small shirt button',(0,-.105,z),(.006,.003,.006),'Collar shade',16,8)
for side in [-1,1]:line('Blue lanyard',[(side*.07,-.072,.998),(side*.103,-.105,.86),(side*.045,-.111,.70)],.008,'Lanyard')
badge=mesh('Press pass',[(-.041,-.121,.74),(.041,-.121,.74),(.041,-.121,.635),(-.041,-.121,.635)],[(0,1,2,3)],'Shirt',False)
mesh('Red pass stripe',[(-.041,-.123,.71),(.041,-.123,.71),(.041,-.123,.69),(-.041,-.123,.69)],[(0,1,2,3)],'Red accent',False)

# Photo-inspired dark green polo collar, twin white piping and short cuffs.
for side in [-1,1]:
 for inset in [0,.009]:
  line('Twin collar piping',[(side*(.080-inset),-.074,1.014),(side*(.091-inset),-.100,.959)],.0022,'Shirt')
 a=Vector((side*.175,.015,.91));b=Vector((side*.24,-.002,.73));direction=(b-a).normalized()
 for name,offset,depth,radius,mat in [('Green short sleeve cuff',0,.055,.070,'Bottle green'),('White cuff piping',-.015,.005,.071,'Shirt'),('White cuff piping',.004,.005,.071,'Shirt')]:
  bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=radius,depth=depth,location=b+direction*offset)
  cuff=bpy.context.object;cuff.rotation_euler=direction.to_track_quat('Z','Y').to_euler();finish(cuff,name,mat)
  for f in cuff.data.polygons:f.use_smooth=True
line('Green V neckline',[(-.033,-.079,1.025),(0,-.111,.967),(.033,-.079,1.025)],.005,'Bottle green')
def chest_text(body,x,z,size):
 cu=bpy.data.curves.new('Chest embroidery','FONT');cu.body=body;cu.size=size;cu.align_x='CENTER';cu.extrude=.0003;cu.resolution_u=3
 o=bpy.data.objects.new('Chest embroidery',cu);bpy.context.collection.objects.link(o);o.location=(x,-.104,z);o.rotation_euler=(math.pi/2,0,0);cu.materials.append(M['Bottle green'])
chest_text('CRUA',.118,.874,.024)
sphere('Oval chest badge',(-.117,-.102,.885),(.030,.003,.017),'Bottle green',32,16)
for i in range(5):
 line('Badge fine lettering',[(-.137+i*.009,-.106,.876),(-.137+i*.009,-.106,.894)],.0011,'Shirt')
# Sweeping green graphic visible on the lower half of the reference jersey.
for dx in [-.065,.025,.105]:
 line('Lower jersey script flourish',[(dx-.027,-.104,.585),(dx+.017,-.106,.63),(dx+.026,-.105,.65),(dx-.006,-.108,.637),(dx-.022,-.108,.612),(dx+.024,-.105,.60)],.004,'Bottle green')

before_face=set(bpy.context.scene.objects)
# Broad oval/pear-shaped Mii head. Face is clean, with no realistic textures.
HC=1.405;RZ=.325;RX=.252;RY=.215
verts=[];faces=[];NU=80;NV=48
for j in range(NV+1):
 v=math.pi*j/NV;zz=math.cos(v);jaw=1.0-.12*max(0,-zz)
 for i in range(NU):
  a=math.tau*i/NU;xx=RX*math.sin(v)*math.sin(a)*jaw;z=HC+RZ*zz
  nose=(.010*math.exp(-(xx/.021)**2-((z-1.411)/.045)**2)+.027*math.exp(-(xx/.029)**2-((z-1.378)/.023)**2))*max(0,math.cos(a))**4
  verts.append((xx,.015-RY*math.sin(v)*math.cos(a)-nose,z))
for j in range(NV):
 for i in range(NU):faces.append((j*NU+i,j*NU+(i+1)%NU,(j+1)*NU+(i+1)%NU,(j+1)*NU+i))
head=mesh('Mii inspired head',verts,faces,'Skin')
def face_y(x,z,lift=.002):
 return .015-RY*math.sqrt(max(.01,1-(x/RX)**2-((z-HC)/RZ)**2))-lift-.010*math.exp(-(x/.021)**2-((z-1.411)/.045)**2)-.027*math.exp(-(x/.029)**2-((z-1.378)/.023)**2)
for side in [-1,1]:
 sphere('Ear',(side*.251,.009,1.395),(.046,.036,.067),'Skin',32,20)
 sphere('Inner ear',(side*.276,-.020,1.395),(.012,.008,.028),'Ear accent',24,16)
 # Modest realism: almond eye whites, hazel irises and gentle eyelid rims.
 x=side*.092;z=1.445
 ev=[];ef=[];NX=32;NY=8
 for row in range(NY+1):
  q=row/NY
  for j in range(NX+1):
   t=j/NX;xx=x-.049+.098*t
   lo=z-.023*math.sin(math.pi*t);hi=z+.030*math.sin(math.pi*t)
   zz=lo+(hi-lo)*q;ev.append((xx,face_y(xx,zz,.004),zz))
 for row in range(NY):
  for j in range(NX):
   k=row*(NX+1)+j;ef.append((k,k+1,k+NX+2,k+NX+1))
 mesh('Almond eye white',ev,ef,'Eye white')
 def disc(name,rx,rz,mat,lift,cx=x,cz=z):
  vv=[(cx,face_y(cx,cz,lift),cz)]
  for j in range(64):
   a=math.tau*j/64;xx=cx+rx*math.cos(a);zz=cz+rz*math.sin(a);vv.append((xx,face_y(xx,zz,lift),zz))
  mesh(name,vv,[(0,j+1,(j+1)%64+1) for j in range(64)],mat)
 disc('Hazel iris',.021,.025,'Hazel iris',.006)
 disc('Dark pupil',.010,.015,'Eye and mouth',.007)
 disc('Eye highlight',.0035,.004,'Teeth',.008,x-.005,z+.007)
 for upper in [True,False]:
  pp=[]
  for j in range(17):
   t=j/16;xx=x-.049+.098*t;zz=z+(.030 if upper else -.023)*math.sin(math.pi*t)
   pp.append((xx,face_y(xx,zz,.0048),zz))
  line('Upper eyelid' if upper else 'Lower eyelid',pp,.0025 if upper else .0015,'Ear accent' if upper else 'Skin')
 # Angular eyebrows carry the reference character's confident expression.
 pts=[(side*.043,1.531),(side*.084,1.550),(side*.144,1.535),(side*.141,1.518),(side*.086,1.530),(side*.048,1.514)]
 mesh('Expressive brown eyebrow',[(x,face_y(x,z-.024,.005),z-.024) for x,z in pts],[tuple(range(6))],'Brown hair',False)
# Nose is integrated into the head surface, with restrained nostril shading.
for side in [-1,1]:
 xx=side*.016;zz=1.365
 sphere('Nostril hint',(xx,face_y(xx,zz,.002),zz),(.0055,.0017,.0025),'Ear accent',24,12)
line('Soft lower lip',[(xx,face_y(xx,1.295-.025*math.sin(math.pi*t),.004),1.295-.025*math.sin(math.pi*t)) for t,xx in [(i/16,-.067+.134*i/16) for i in range(17)]],.0025,'Soft lip')

# A single morphable smile patch: narrow at rest, open during speech.
verts=[];N=40
for row in [0,1]:
 for i in range(N+1):
  t=i/N;xx=-.073+.146*t;arc=math.sin(math.pi*t)
  z=1.295-.014*arc-(.007*arc if row else 0)
  verts.append((xx,face_y(xx,z,.005),z))
mouth=mesh('Right animated mouth',verts,[(i,i+1,N+2+i,N+1+i) for i in range(N)],'Eye and mouth')
mouth.shape_key_add(name='Basis');key=mouth.shape_key_add(name='MouthOpen')
for i in range(N+1):
 t=i/N;v=key.data[N+1+i];v.co.z-=.034*math.sin(math.pi*t);v.co.y=face_y(v.co.x,v.co.z,.005)
for frame,value in [(1,0),(6,.8),(11,.15),(17,.6),(23,0),(30,.9),(36,.2),(43,.7),(49,0),(60,0)]:
 key.value=value;key.keyframe_insert(data_path='value',frame=frame)
mouth.data.shape_keys.animation_data.action.name='RightTalk';key.value=0

face_names={o.name for o in bpy.context.scene.objects if o not in before_face}

# Solid brown hairstyle with a swept, chunky quiff: a few bold Mii shapes.
verts=[];faces=[];N=80;J=24
for j in range(J+1):
 for i in range(N):
  a=math.tau*i/N;start=1.33+.27*max(0,math.cos(a))**.7
  z=start+(1.735-start)*j/J
  f=math.sqrt(max(.002,1-((z-HC)/.339)**2))
  verts.append((.260*f*math.sin(a),.025-.225*f*math.cos(a),z))
for j in range(J):
 for i in range(N):faces.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
mesh('Brown hair cap',verts,faces,'Brown hair')
outline=[(-.217,1.59),(-.242,1.72),(-.18,1.82),(-.139,1.783),(-.061,1.875),(-.022,1.804),(.067,1.831),(.165,1.764),(.229,1.651),(.187,1.57),(.084,1.586),(-.060,1.608)]
verts=[(x,-.145,z) for x,z in outline]+[(x*.91,.095,z-.04) for x,z in outline]
L=len(outline);faces=[tuple(reversed(range(L))),tuple(range(L,L*2))]+[(i,(i+1)%L,(i+1)%L+L,i+L) for i in range(L)]
quiff=mesh('Swept Mii quiff',verts,faces,'Brown hair',False)
bev=quiff.modifiers.new('Rounded sculpted hair edges','BEVEL');bev.width=.020;bev.segments=4;bpy.context.view_layer.objects.active=quiff;bpy.ops.object.modifier_apply(modifier=bev.name)
mod=quiff.modifiers.new('Clean hair normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
for points in [[(-.135,-.168,1.633),(-.16,-.168,1.706),(-.145,-.168,1.757)],[(-.045,-.168,1.638),(-.079,-.168,1.720),(-.071,-.168,1.800)],[(.061,-.168,1.618),(.025,-.168,1.699),(.021,-.168,1.756)]]:
 line('Simple hair part',points,.003,'Hair groove')

# The broadcaster's recognisable headset and boom microphone.
line('Headband',[(-.285,.022,1.43),(-.251,.035,1.66),(-.10,.050,1.755),(0,.05,1.777),(.16,.04,1.727),(.26,.03,1.60),(.285,.02,1.43)],.018,'Headset')
for side in [-1,1]:
 sphere('Headphone cushion',(side*.280,.015,1.409),(.035,.065,.083),'Headset',32,20)
 sphere('Headphone shell',(side*.307,.015,1.409),(.026,.062,.076),'Headset',32,20)
 sphere('Headphone inset',(side*.329,.012,1.409),(.005,.039,.050),'Headset inset',24,16)
line('Microphone boom',[(.311,-.020,1.387),(.292,-.164,1.315),(.187,-.238,1.290),(.093,-.249,1.285)],.009,'Headset')
sphere('Microphone foam',(.077,-.250,1.285),(.040,.024,.025),'Headset',32,20)

# Convert curves and batch static geometry; keep the animated mouth separate.
for o in list(bpy.context.scene.objects):
 if o.type in {'CURVE','FONT'}:
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')

# One coherent deformation of skin, features and every mouth morph target.
# Preserve the hairline while refining cheek/jaw silhouette and chin projection.
def refine_face(p):
 x,y,z=p
 jaw=math.exp(-((z-1.235)/.105)**2)
 cheek=math.exp(-((z-1.410)/.070)**2)
 xx=x*(1-.14*jaw+.018*cheek)
 zz=z-.026*math.exp(-((z-1.155)/.155)**2)
 front=max(0,min(1,(.015-y)/.13))**2
 chin=.019*math.exp(-(x/.095)**2-((z-1.155)/.075)**2)
 cheeks=.009*math.exp(-((abs(x)-.125)/.060)**2-((z-1.385)/.055)**2)
 return Vector((xx,y-front*(chin+cheeks),zz))
for o in bpy.context.scene.objects:
 if o.type!='MESH' or o.name not in face_names: continue
 mat=o.matrix_world;inv=mat.inverted()
 if o.data.shape_keys:
  for keyblock in o.data.shape_keys.key_blocks:
   for v in keyblock.data:v.co=inv@refine_face(mat@v.co)
 else:
  for v in o.data.vertices:v.co=inv@refine_face(mat@v.co)


# Rounder shared silhouette. Transform all head geometry and morph targets,
# including glasses, hair and headset; blend at the neck junction.
def round_head(p):
 x,y,z=p
 w=max(0,min(1,(z-1.065)/.045));w=w*w*(3-2*w)
 return Vector((x*(1+.10*w),.015+(y-.015)*(1+.035*w),z-.16*(z-1.08)*w))
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 mat=o.matrix_world;inv=mat.inverted()
 if o.data.shape_keys:
  for block in o.data.shape_keys.key_blocks:
   for v in block.data:v.co=inv@round_head(mat@v.co)
 else:
  for v in o.data.vertices:v.co=inv@round_head(mat@v.co)


# Pose arms before batching, then fold legs into a chair-friendly sitting pose.
from mathutils import Matrix
turn=Matrix.Rotation(math.radians(-65),4,'X')
pivot=Vector((0,.015,.92))
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 arm=o.name.startswith(('Sleeve','Simple mitten hand','Thumb','Green short sleeve','White cuff'))
 mat=o.matrix_world;inv=mat.inverted()
 blocks=[b.data for b in o.data.shape_keys.key_blocks] if o.data.shape_keys else [o.data.vertices]
 for block in blocks:
  for v in block:
   p=mat@v.co
   if arm:p=pivot+turn@(p-pivot)
   if p.z>=.50:
    p=Vector((p.x*1.25,.18+p.y*1.25,.66+(p.z-.50)*1.25))
   elif p.z>=.30:
    p=Vector((p.x*1.25,.18-(.50-p.z)*1.7+p.y*1.25,.66+p.y*.15))
   else:
    p=Vector((p.x*1.25,-.16+p.y*1.25,.16+(p.z-.086)*(.50/.214)))
   v.co=inv@p

static=[o for o in bpy.context.scene.objects if o.type=='MESH' and o!=mouth]
bpy.ops.object.select_all(action='DESELECT')
for o in static:o.select_set(True)
bpy.context.view_layer.objects.active=static[0];bpy.ops.object.join();figure=bpy.context.object;figure.name='EuroMaxCycling_Mii_Right'
bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=60;bpy.context.scene.render.fps=30;bpy.context.scene.frame_set(1)
for o in bpy.context.scene.objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'euromax_right_mii.glb'),export_format='GLB',export_yup=True,export_apply=False,export_morph=True,export_animation_mode='ACTIONS')
stats={'style':'Right v05, round head and photo-inspired green-trim polo','triangles':sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in [figure,mouth]),'meshes':2,'mouth_animation':'CommentaryTalk / MouthOpen','height_m':1.7478}
(OUT/'model_info.json').write_text(json.dumps(stats,indent=2))


bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).with_name('right_seated.blend')),compress=True)
print('SEATED_ACTOR_OK Right')
