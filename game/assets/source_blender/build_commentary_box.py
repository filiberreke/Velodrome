"""EuroMaxCycling broadcast suite. Blender 5.x --background --python this_file.py.
Metres, floor at Z=0, front=-Y (Godot +Z). All visible details are exported meshes.
Reference: user-approved broadcast booth mockup and supplied commentator banner.
"""
from pathlib import Path
import bpy, math, json, random, sys
sys.path.insert(0,str(Path(__file__).resolve().parent))

from mathutils import Vector

GAME=Path(__file__).resolve().parents[2]
OUT=GAME/'assets/broadcast'; OUT.mkdir(parents=True,exist_ok=True)
VERIFY=GAME/'verification/commentary_box'; VERIFY.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(71)
M={}
FONT=None
for font_path in ['C:/Windows/Fonts/arialbd.ttf','/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf']:
 if Path(font_path).exists():FONT=bpy.data.fonts.load(font_path);break
def mat(name,hex,metal=0,rough=.5,emit=0,alpha=1):
 m=bpy.data.materials.new(name); m.use_nodes=True
 rgb=tuple(int(hex[i:i+2],16)/255 for i in (0,2,4))
 rgb=tuple(((v+.055)/1.055)**2.4 if v>.04045 else v/12.92 for v in rgb)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*rgb,alpha)
 p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;p.inputs['Alpha'].default_value=alpha
 if emit:p.inputs['Emission Color'].default_value=(*rgb,1);p.inputs['Emission Strength'].default_value=emit
 if alpha<1:m.surface_render_method='BLENDED';m.use_transparency_overlap=False
 M[name]=m;return m
mat('Navy enamel','092655',.32,.29);mat('Navy acoustic','12243c',0,.95)
mat('Brushed aluminium','aeb8c3',.78,.28);mat('Graphite','151c27',.25,.42)
mat('Rubber','171a20',0,.9);mat('White shirt','efeee9',0,.78)
mat('Seam','d1d0ce',0,.84);mat('Skin','e7aa77',0,.58);mat('Skin shadow','c37f56',0,.65)
mat('Lips','a85a42',0,.65);mat('Mouth','412b29',0,.75);mat('Teeth','fff4df',0,.4)
mat('Eye white','fff9ec',0,.25);mat('Iris','6c4024',0,.35);mat('Pupil','121419',0,.3)
mat('Hair','613a24',0,.57);mat('Hair light','805131',0,.55)
mat('White logo','ffffff',.05,.4);mat('Red','d3092d',.15,.35);mat('Gold','f6be35',.35,.35)
mat('Warm LED','fff0d1',0,.35,3);mat('Blue LED','74c6ff',0,.3,2)
mat('Screen','122d44',.2,.23,.3);mat('Screen cyan','56bdcf',0,.45,1)
mat('Glass','a8cddd',.05,.15,0,.075);mat('Bottle','aad7e7',.1,.2,0,.5)

def finish(o,name,m):
 o.name=name;o.data.materials.append(M[m]);return o
def box(name,c,s,m,bevel=.012):
 bpy.ops.mesh.primitive_cube_add(size=1,location=c);o=bpy.context.object;o.scale=s
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Machined edge','BEVEL');mod.width=bevel;mod.segments=3
  bpy.ops.object.modifier_apply(modifier=mod.name)
  mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
 return finish(o,name,m)
def ell(name,c,s,m,seg=28,rings=16):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=c)
 o=bpy.context.object;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for p in o.data.polygons:p.use_smooth=True
 return finish(o,name,m)
def rod(name,a,b,r,m,vertices=12):
 a,b=Vector(a),Vector(b);d=b-a
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d.length,location=(a+b)/2)
 o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
 for p in o.data.polygons:p.use_smooth=True
 return finish(o,name,m)
def line(name,pts,r,m):
 cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=4;cu.bevel_depth=r;cu.bevel_resolution=1
 sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(pts)-1)
 for p,co in zip(sp.bezier_points,pts):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(o);cu.materials.append(M[m]);return o
def poly(name,pts,m):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(pts,[],[tuple(range(len(pts)))]);mesh.update()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);mesh.materials.append(M[m]);return o
def text(name,body,c,size,m,align='CENTER'):
 cu=bpy.data.curves.new(name,'FONT');cu.body=body;cu.size=size;cu.shear=.14;cu.resolution_u=5;cu.bevel_resolution=1
 if FONT:cu.font=FONT
 cu.size=size;cu.align_x=align;cu.extrude=.0015;cu.bevel_depth=.0005
 o=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(o);o.location=c;o.rotation_euler=(math.pi/2,0,0);cu.materials.append(M[m]);return o
def logo(x,y,z,scale):
 # Brand has been renamed by the user: every display reads EuroMaxCycling.
 text('EuroMax wordmark','EuroMax',(x+.12*scale,y,z+.10*scale),.42*scale,'White logo')
 box('Cycling red plaque',(x+.17*scale,y+.008,z-.11*scale),(1.55*scale,.018,.40*scale),'Red',.025*scale)
 text('Cycling wordmark','Cycling',(x+.17*scale,y-.015,z-.235*scale),.34*scale,'White logo')
 for i in range(7):
  angle=math.radians(70+i*33);cx=x-.65*scale+math.cos(angle)*.46*scale;cz=z+.04*scale+math.sin(angle)*.46*scale
  pts=[(cx+math.sin(j*math.pi/5)*(.10 if j%2==0 else .043)*scale,y-.018,cz+math.cos(j*math.pi/5)*(.10 if j%2==0 else .043)*scale) for j in range(10)]
  poly('European star',pts,'Gold')

# Structural shell: individually bevelled powder-coated cassettes and exposed metal.
box('Raised structural floor',(0,0,.02),(5.8,3.4,.20),'Graphite',.035)
box('Carpet',(0,0,.13),(5.55,3.16,.035),'Navy acoustic')
for x in [-2.89,2.89]:
 box('Side spandrel',(x,0,.58),(.12,3.35,.95),'Navy enamel',.025)
 for y in [-1.65,-.25,1.65]:box('Side upright',(x,y,1.5),(.10,.10,2.95),'Brushed aluminium')
 for z in [.13,1.04,2.90]:box('Side rail',(x,0,z),(.10,3.4,.085),'Brushed aluminium')
 for y in [-.95,.72]:box('Side glazing',(x,y,1.97),(.015,1.27,1.79),'Glass',0)
box('Rear wall',(0,1.64,1.48),(5.8,.12,2.82),'Navy enamel')
for x in [-2.4,-2,-1.6,1.6,2,2.4]:
 box('Acoustic panel',(x,1.56,1.75),(.32,.035,1.55),'Navy acoustic')
 for k in range(6):box('Acoustic slot',(x-.12+k*.048,1.532,1.75),(.014,.012,1.48),'Graphite',.003)
logo(0,1.55,1.92,1.08)
text('Rear channel','LIVE  /  TRACKSIDE COMMENTARY',(0,1.525,1.25),.077,'White logo')
for x,w in [(-1.96,1.76),(0,2.05),(1.96,1.76)]:
 box('Front navy cassette',(x,-1.65,.59),(w,.12,.89),'Navy enamel',.025)
for x in [-2.87,-2.05,2.05,2.87]:
 box('Front frame',(x,-1.73,1.50),(.065,.10,2.91),'Brushed aluminium')
 for z in [.21,.95,2.79]:rod('Hex bolt',(x,-1.79,z),(x,-1.802,z),.021,'Graphite',6)
for z in [.12,1.05,2.91]:box('Front cross rail',(0,-1.72,z),(5.82,.105,.09),'Brushed aluminium')
for x,w in [(-2.48,.72),(0,4.02),(2.48,.72)]:box('Front glazing',(x,-1.69,1.97),(w,.012,1.77),'Glass',0)
logo(0,-1.724,.62,.85)
for x in [-1.98,1.98]:logo(x,-1.724,.62,.44)
box('Roof',(0,0,2.94),(5.98,3.54,.15),'Navy enamel',.03)
box('Ceiling',(0,0,2.84),(5.65,3.20,.06),'Graphite')
for x in [-2.1,-.7,.7,2.1]:
 box('Luminaire housing',(x,-.18,2.79),(.47,1.15,.065),'Brushed aluminium')
 for y in [-.48,.10]:box('Diffuser',(x,y,2.75),(.37,.38,.018),'Warm LED',.005)
 rod('Rear spotlight',(x,1.21,2.74),(x,1.21,2.65),.065,'Graphite',20)
 ell('Spot lens',(x,1.21,2.64),(.05,.05,.012),'Blue LED',16,8)
for x in [-2.76,2.76]:
 line('Ceiling cable tray',[(x,-1.3,2.73),(x,.4,2.73),(x,1.4,2.73)],.035,'Rubber')
for z in [.20,2.73]:box('Linear LED',(0,-1.77,z),(5.6,.015,.014),'Warm LED',.003)

# Desk, rear producer rack, audio equipment, monitors, keycaps and cable routing.
box('Desk top',(0,-.70,1.00),(5.12,1.18,.085),'Graphite',.055)
box('Desk brushed edge',(0,-1.28,.985),(5.08,.028,.07),'Brushed aluminium')
for x in [-2.24,0,2.24]:box('Desk pedestal',(x,-.50,.56),(.13,.68,.82),'Brushed aluminium')
for x in [-1.13,1.13]:
 rod('Monitor stem',(x,-.94,1.03),(x,-.94,1.19),.025,'Brushed aluminium')
 box('Monitor foot',(x,-.94,1.045),(.35,.22,.025),'Graphite')
 o=box('Broadcast monitor',(x,-.95,1.23),(.90,.095,.38),'Graphite',.025);o.rotation_euler.x=math.radians(12)
 logo(x,-1.014,1.22,.18)
 # Display faces the presenters, on the rear-facing side of the chassis.
 panel=box('Monitor screen',(x,-.886,1.23),(.80,.008,.30),'Screen',.004);panel.rotation_euler.x=math.radians(12)
 for j in range(5):box('Timing row',(x-.07,-.873,1.13+j*.040),(.51,.006,.009),'Screen cyan',.001)
 box('Keyboard',(x,-.42,1.06),(.56,.20,.025),'Graphite')
 for row in range(4):
  for col in range(13):box('Keycap',(x-.25+col*.040,-.49+row*.043,1.078),(.032,.031,.009),'Rubber',.002)
 ell('Mouse',(x+.43,-.43,1.07),(.045,.075,.025),'Graphite',16,8)
 line('Monitor signal cable',[(x,-.91,1.18),(x,-.72,1.05),(x,-.60,.90),(x+.2,-.1,.35)],.009,'Rubber')
 box('Paper script',(x+.38,-.80,1.052),(.23,.31,.004),'White logo',.001)
 for j in range(7):box('Printed script',(x+.38,-.90+j*.026,1.055),(.17,.004,.001),'Navy enamel',0)
 rod('Pen',(x+.53,-.91,1.062),(x+.53,-.66,1.062),.007,'Red')
 # Water bottles, screw caps, labels and cups.
 bx=x-.58
 rod('Water bottle',(bx,-.72,1.05),(bx,-.72,1.28),.043,'Bottle',24)
 ell('Bottle shoulder',(bx,-.72,1.28),(.043,.043,.045),'Bottle',20,10)
 rod('Bottle cap',(bx,-.72,1.31),(bx,-.72,1.34),.026,'Navy enamel',20)
 rod('Bottle label',(bx,-.72,1.12),(bx,-.72,1.20),.044,'White logo',24)
 rod('Coffee cup',(x+.65,-.65,1.05),(x+.65,-.65,1.16),.043,'Navy enamel',24)
 line('Cup handle',[(x+.69,-.65,1.14),(x+.74,-.65,1.11),(x+.69,-.65,1.07)],.008,'Brushed aluminium')
box('Audio mixing console',(0,-.49,1.075),(.64,.43,.065),'Graphite')
for j in range(8):
 x=-.27+j*.077
 box('Fader slot',(x,-.46,1.112),(.008,.22,.005),'Rubber',0)
 box('Fader cap',(x,-.49+(j%3)*.05,1.122),(.032,.036,.014),'Brushed aluminium',.004)
 for k in range(3):rod('Gain knob',(x,-.66+k*.05,1.11),(x,-.66+k*.05,1.13),.011,'Red' if k==0 else 'Graphite')
box('On air housing',(0,-1.27,1.15),(.42,.06,.15),'Graphite')
text('On air','ON AIR',(0,-1.308,1.12),.07,'Red')
for x in [-2.40,2.40]:
 box('Equipment rack',(x,1.22,.64),(.55,.57,1.00),'Graphite')
 for j in range(5):
  box('Rack unit',(x,.92,.30+j*.16),(.47,.018,.13),'Rubber')
  for k in range(4):ell('Rack indicator',(x-.18+k*.035,.906,.32+j*.16),(.009,.004,.009),'Blue LED',8,4)
  for k in range(8):box('Cooling vent',(x+.03+k*.018,.907,.30+j*.16),(.006,.008,.055),'Brushed aluminium',0)
 # Ceiling-mounted PTZ camera with lens glass and tally.
 rod('Camera mount',(x,-1.30,2.72),(x,-1.30,2.53),.035,'Graphite')
 box('PTZ camera',(x,-1.30,2.43),(.27,.34,.23),'Graphite',.03)
 rod('Lens barrel',(x,-1.46,2.43),(x,-1.59,2.43),.067,'Rubber',24)
 ell('Lens optical glass',(x,-1.595,2.43),(.052,.008,.052),'Screen',24,12)
 box('Camera tally',(x,-1.48,2.54),(.05,.012,.018),'Red',.004)

def presenter(x,label):
 # Preserve the detailed office chair, replace the entire previous character.
 box('Chair cushion',(x,.23,.59),(.59,.55,.13),'Rubber')
 box('Chair back',(x,.52,1.00),(.58,.13,.76),'Rubber')
 rod('Chair piston',(x,.23,.17),(x,.23,.56),.045,'Brushed aluminium')
 for i in range(5):
  a=math.tau*i/5;end=(x+.33*math.cos(a),.23+.33*math.sin(a),.18)
  rod('Chair spoke',(x,.23,.22),end,.022,'Brushed aluminium');ell('Caster',end,(.04,.04,.045),'Rubber',12,8)
 before=set(bpy.context.scene.objects)
 bpy.ops.import_scene.gltf(filepath=str(OUT/'commentators'/('euromax_'+label.lower()+'_mii.glb')))
 actors=set(bpy.context.scene.objects)-before
 for o in actors:
  if o.parent not in actors:o.location.x+=x

presenter(-.90,'Left');presenter(.90,'Right')

# Share identical actor material slots so the two presenters do not duplicate draw surfaces.
known={}
aliases={'Soft lip':'Ear accent','Headset inset':'Headset','Collar shade':'Shirt','Hair groove':'Brown hair'}
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 for slot in o.material_slots:
  m=slot.material
  if m:
   base=m.name.split('.')[0]
   if base in aliases:
    replacement=bpy.data.materials.get(aliases[base])
    if replacement:slot.material=replacement;m=replacement
  if not m or not m.use_nodes:continue
  bsdf=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
  if not bsdf or any(i.is_linked for i in bsdf.inputs):continue
  signature=tuple(round(v,5) for v in bsdf.inputs['Base Color'].default_value)+(round(bsdf.inputs['Roughness'].default_value,5),round(bsdf.inputs['Metallic'].default_value,5),round(bsdf.inputs['Emission Strength'].default_value,5))
  if signature in known:slot.material=known[signature]
  else:known[signature]=m

# Convert text/curves, apply scales, batch opaque geometry by material. Glass remains
# in separate panes for transparent sorting. No collision, animation, or runtime CPU work.
for o in list(bpy.context.scene.objects):
 if o.type in {'FONT','CURVE'}:
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
opaque=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.data.shape_keys and o.data.materials[0].name not in ['Glass','Bottle']]
bpy.ops.object.select_all(action='DESELECT')
for o in opaque:o.select_set(True)
bpy.context.view_layer.objects.active=opaque[0];bpy.ops.object.join();body=bpy.context.object;body.name='EuroMaxCycling_Opaque'
body.data.calc_loop_triangles()
triangles=sum(len(o.data.loop_triangles) if o.data.loop_triangles else sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).with_name('euromax_cycling_box.blend')),compress=True)
bpy.context.scene.render.fps=30
bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=120
bpy.ops.export_scene.gltf(filepath=str(OUT/'euromax_cycling_box.glb'),export_format='GLB',export_yup=True,export_apply=False,export_cameras=False,export_lights=False,export_animations=True,export_morph=True,export_animation_mode='ACTIONS')
stats={'brand':'EuroMaxCycling','dimensions_m':[5.98,3.54,3.015],'triangles':triangles,'mesh_objects':sum(o.type=='MESH' for o in bpy.context.scene.objects),'materials':len(M),'coordinate_system':'Blender front -Y; Godot front +Z','seed':71}
(VERIFY/'asset_stats.json').write_text(json.dumps(stats,indent=2))
print('COMMENTARY_ASSET_OK',json.dumps(stats))
