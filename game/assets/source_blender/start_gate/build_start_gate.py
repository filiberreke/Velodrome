"""Editable pursuit start gate. Blender 5.2; metres, Blender -Y forward.
Exported GLB: +Z forward, Y up. Origin on floor under held rear axle.
"""
import bpy, math, json, os
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30
scene.frame_start, scene.frame_end = 1, 46

def material(name, color, metal=0, rough=.4):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    return m
red=material('Powder coated racing red',(.62,.018,.025),.45,.3)
steel=material('Brushed steel',(.43,.48,.53),.8,.27)
black=material('Rubber and protective pads',(.018,.022,.028),0,.77)
dark=material('Actuator housing',(.045,.055,.064),.6,.35)
white=material('Neutral white plates',(.84,.86,.82),.1,.38)
gate=bpy.data.objects.new('StartGate_ROOT',None); scene.collection.objects.link(gate)
parts=[]
def finish(o,name,mat,parent=gate):
    o.name=name; o.data.materials.append(mat); o.parent=parent; parts.append(o)
    return o
def box(name, pos, size, mat, parent=gate, bevel=.007):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos); o=bpy.context.object
    o.dimensions=size; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Soft manufactured edges','BEVEL'); mod.width=bevel; mod.segments=2
        o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return finish(o,name,mat,parent)
def beam(name,a,b,width,depth,mat=red):
    a,b=Vector(a),Vector(b); o=box(name,(a+b)/2,(width,depth,(b-a).length),mat)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler(); return o
def rod(name,a,b,r,mat=steel,parent=gate):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object; o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,mat,parent)

# Open throat faces the bicycle; rear axle is at (0,0,.335).
for s,label in [(-1,'Left'),(1,'Right')]:
    x=s*.40
    beam(label+'_base_runner',(x,-.085,.10),(x,.66,.10),.055,.06)
    beam(label+'_front_sloping_leg',(x,-.055,.12),(s*.245,.22,1.08),.055,.055)
    beam(label+'_rear_sloping_leg',(x,.62,.12),(s*.245,.42,1.08),.055,.055)
    beam(label+'_top_rail',(s*.245,.19,1.08),(s*.245,.45,1.08),.06,.06)
    beam(label+'_mid_brace',(s*.345,.08,.43),(s*.345,.55,.43),.038,.038)
    # Two grips for the two helpers; grips are part of the machine.
    rod(label+'_carry_handle',(s*.27,.25,1.115),(s*.27,.43,1.115),.021,black)
    for y in [-.045,.60]:
        rod(label+'_threaded_leveling_foot',(x,y,.018),(x,y,.14),.010)
        box(label+'_rubber_foot',(x,y,.014),(.105,.09,.028),black)
        rod(label+'_adjustment_collar',(x,y,.075),(x,y,.092),.018,dark)
    # Wheels are raised off the track while the feet support the device.
    rod(label+'_transport_wheel',(x-.021,.68,.073),(x+.021,.68,.073),.057,black)
    rod(label+'_wheel_hub',(x-.024,.68,.073),(x+.024,.68,.073),.018)
    for z,y,bx in [(.16,-.04,.394),(.43,.12,.345),(1.08,.26,.245)]:
        rod(label+'_frame_fastener',(s*(bx+.025),y,z),(s*(bx+.036),y,z),.009,steel)
    box(label+'_clamp_mount',(s*.345,.17,.376),(.055,.08,.13),red)
beam('Rear_lower_crossbar',(-.4,.61,.13),(.4,.61,.13),.055,.055)
beam('Upper_crossbar',(-.245,.42,1.08),(.245,.42,1.08),.055,.055)
beam('Rear_diagonal_brace',(-.35,.60,.19),(.245,.42,.96),.03,.03)
box('Release_control_housing',(0,.46,.72),(.17,.14,.21),dark)
rod('Vertical_release_cylinder',(0,.43,.36),(0,.43,.68),.032,steel)
rod('Release_piston',(0,.43,.68),(0,.43,.84),.012,steel)
beam('Release_linkage_rear',(0,.43,.38),(.27,.43,.335),.024,.024,steel)
beam('Release_linkage_side',(.27,.43,.335),(.27,.17,.335),.024,.024,steel)
box('Rear_neutral_identity_plate',(0,.665,.32),(.42,.015,.20),white)
rod('Manual_release_lever',(.03,.43,.87),(.18,.43,.95),.012,steel)
rod('Manual_release_grip',(.18,.43,.95),(.26,.43,.95),.019,black)

jaws=[]
for s,label in [(-1,'Left'),(1,'Right')]:
    pivot=bpy.data.objects.new(label+'_Clamp_SLIDE',None); scene.collection.objects.link(pivot); pivot.parent=gate
    jaws.append((pivot,s))
    rod(label+'_clamp_guide',(s*.09,.17,.335),(s*.37,.17,.335),.025,steel)
    box(label+'_sliding_carriage',(s*.205,.17,.335),(.105,.09,.085),dark,parent=pivot)
    box(label+'_axle_support_arm',(s*.12,.065,.335),(.042,.24,.045),steel,parent=pivot)
    rod(label+'_axle_cup',(s*.055,0,.335),(s*.125,0,.335),.024,black,parent=pivot)
    rod(label+'_cup_flange',(s*.112,0,.335),(s*.126,0,.335),.033,steel,parent=pivot)

def animate(o, positions):
    for frame,loc in positions:
        o.location=loc; o.keyframe_insert(data_path='location',frame=frame)
    action=o.animation_data.action; action.name=o.name+'_release'
    # Avoid Bezier anticipation: withdrawal must not begin before jaws open.
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:key.interpolation='LINEAR'
    track=o.animation_data.nla_tracks.new(); track.name='ReleaseAndWithdraw'
    track.strips.new(action.name,1,action); o.animation_data.action=None
for jaw,s in jaws: animate(jaw,[(1,(0,0,0)),(5,(s*.11,0,0)),(46,(s*.11,0,0))])
animate(gate,[(1,(0,0,0)),(7,(0,0,0)),(36,(0,1.1,0)),(46,(0,1.1,0))])
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for o in [gate]+parts+[j[0] for j in jaws]:o.select_set(True)
bpy.context.view_layer.objects.active=gate
bpy.ops.export_scene.gltf(filepath=str(OUT/'pursuit_start_gate.glb'),use_selection=True,export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_frame_range=True)

# Refined team helpers: atlas-compatible polos, rounded joints and gripping fingers.
shirtmat=material('Helper_Shirt_Atlas',(.16,.27,.43),0,.72)
denim=material('Tailored navy trousers',(.025,.045,.085),0,.82)
seam=material('Trouser stitching',(.08,.12,.18),0,.85)
skin=material('Warm skin',(.60,.34,.21),0,.6)
skin2=material('Light skin',(.88,.62,.43),0,.6)
hair=material('Brown hair',(.045,.023,.015),0,.85)
lip=material('Natural lip line',(.24,.10,.065),0,.7)
iris=material('Brown iris',(.10,.055,.025),0,.42)
def ellipsoid(name,pos,scale,mat,parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=pos)
    o=bpy.context.object; o.scale=scale
    for poly in o.data.polygons:poly.use_smooth=True
    return finish(o,name,mat,parent)
def taper(name,a,b,r1,r2,mat,parent):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=r1,radius2=r2,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    for poly in o.data.polygons:poly.use_smooth=poly.loop_total==4
    mod=o.modifiers.new('Rounded cuffs and joints','BEVEL');mod.width=.008;mod.segments=3
    o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return finish(o,name,mat,parent)
def atlas_uv(o,region,origin,axis,extent,sleeve=False):
    # Same padded cylindrical atlas as the rider's skinsuit_uv.py.
    bpy.context.view_layer.update()
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    origin,axis=Vector(origin),Vector(axis).normalized()
    lateral=Vector((1,0,0));lateral=(lateral-axis*lateral.dot(axis)).normalized()
    back=axis.cross(lateral).normalized()
    x0,y0,x1,y1=region
    for poly in o.data.polygons:
        coords=[]
        for li in poly.loop_indices:
            d=o.matrix_world @ o.data.vertices[o.data.loops[li].vertex_index].co-origin
            u=(math.atan2(d.dot(lateral),d.dot(back))/(2*math.pi))%1
            v=max(0,min(1,d.dot(axis)/extent))
            if sleeve:v=1-v*.42
            coords.append((li,u,v))
        if max(c[1] for c in coords)-min(c[1] for c in coords)>.5:
            coords=[(li,u+1 if u<.5 else u,v) for li,u,v in coords]
        for li,u,v in coords:uv.data[li].uv=(x0+u/1.5*(x1-x0),y0+v*(y1-y0))
def torso(name,x,parent):
    profiles=[(.965,.148,.101),(1.00,.16,.11),(1.15,.18,.126),(1.31,.196,.119),(1.37,.173,.09),(1.425,.071,.060)]
    verts=[];faces=[];n=40
    for z,rx,ry in profiles:
        for i in range(n):
            a=i*math.tau/n;verts.append((x+rx*math.cos(a),.46+ry*math.sin(a),z))
    for ring in range(len(profiles)-1):
        for i in range(n):
            a=ring*n+i;b=ring*n+(i+1)%n;faces.append((a,b,b+n,a+n))
    faces.append(tuple(reversed(range(n))))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);scene.collection.objects.link(o);finish(o,name,shirtmat,parent)
    for poly in mesh.polygons:poly.use_smooth=True
    sub=o.modifiers.new('Soft tailored fabric','SUBSURF');sub.levels=1
    atlas_uv(o,(.02,.52,.60,.98),(x,.46,.965),(0,0,1),.46)
    return o
def stash_animation(o):
    action=o.animation_data.action;action.name=o.name+'_walk'
    track=o.animation_data.nla_tracks.new();track.name='ReleaseAndWithdraw'
    track.strips.new(action.name,1,action);o.animation_data.action=None
helper_objects=[]
for s,label,skinmat in [(-1,'Helper_Left',skin),(1,'Helper_Right',skin2)]:
    helper=bpy.data.objects.new(label,None);scene.collection.objects.link(helper);helper.parent=gate;parts.append(helper)
    x=s*.67;start=len(parts)
    torso(label+'_shirt',x,helper)
    ellipsoid(label+'_hips',(x,.48,.93),(.164,.115,.125),denim,helper)
    box(label+'_waistband',(x,.46,.974),(.285,.19,.023),denim,parent=helper,bevel=.012)
    rod(label+'_neck',(x,.46,1.40),(x,.46,1.51),.057,skinmat,helper)
    # Polo collar and short front placket; all use the same team atlas.
    for dx in [-.043,.043]:
        collar=ellipsoid(label+'_polo_collar',(x+dx,.411,1.407),(.043,.020,.027),shirtmat,helper)
        atlas_uv(collar,(.02,.52,.60,.98),(x,.46,.965),(0,0,1),.46)
    placket=box(label+'_shirt_placket',(x,.342,1.318),(.022,.008,.073),shirtmat,parent=helper,bevel=.003)
    atlas_uv(placket,(.02,.52,.60,.98),(x,.46,.965),(0,0,1),.46)
    for z in [1.335,1.31]:ellipsoid(label+'_polo_button',(x,.336,z),(.0035,.003,.0035),white,helper)
    ellipsoid(label+'_head',(x,.452,1.585),(.119,.108,.151),skinmat,helper)
    ellipsoid(label+'_jaw',(x,.425,1.531),(.095,.081,.082),skinmat,helper)
    ellipsoid(label+'_hair',(x,.481,1.685),(.121,.10,.063 if s==1 else .078),hair,helper)
    for dx in [-.114,.114]:
        ellipsoid(label+'_ear',(x+dx,.457,1.586),(.022,.021,.038),skinmat,helper)
        ellipsoid(label+'_ear_inner',(x+dx,.437,1.586),(.011,.006,.022),lip,helper)
        ellipsoid(label+'_sideburn',(x+dx*.96,.458,1.65),(.012,.031,.043),hair,helper)
    ellipsoid(label+'_nose_bridge',(x,.342,1.594),(.020,.022,.037),skinmat,helper)
    ellipsoid(label+'_nose',(x,.326,1.578),(.027,.023,.020),skinmat,helper)
    for dx in [-.041,.041]:
        ellipsoid(label+'_eye',(x+dx,.351,1.62),(.021,.010,.016),white,helper)
        ellipsoid(label+'_iris',(x+dx,.341,1.619),(.010,.005,.011),iris,helper)
        ellipsoid(label+'_pupil',(x+dx,.337,1.619),(.005,.003,.007),dark,helper)
        ellipsoid(label+'_eye_highlight',(x+dx-.003,.334,1.623),(.0025,.0015,.003),white,helper)
        ellipsoid(label+'_eyebrow',(x+dx,.351,1.65),(.025,.009,.0055),hair,helper)
    rod(label+'_smile_L',(x-.025,.343,1.541),(x,.337,1.537),.0028,lip,helper)
    rod(label+'_smile_R',(x,.337,1.537),(x+.025,.343,1.541),.0028,lip,helper)
    for index,yy in enumerate([.26,.43]):
        shoulder=Vector((x+s*(.125 if index else -.125),.43,1.335))
        elbow=Vector((s*.47,yy+.025,1.224));hand=Vector((s*.27,yy,1.115))
        cuff=shoulder.lerp(elbow,.58)
        taper(label+'_upper_arm',shoulder,elbow,.058,.048,skinmat,helper)
        ellipsoid(label+'_elbow',elbow,(.050,.050,.050),skinmat,helper)
        taper(label+'_forearm',elbow,hand,.048,.030,skinmat,helper)
        sleeve=taper(label+'_sleeve',shoulder,cuff,.086,.066,shirtmat,helper)
        atlas_uv(sleeve,(.62,.52,.78,.98) if index==0 else (.80,.52,.96,.98),shoulder,elbow-shoulder,(cuff-shoulder).length,True)
        ellipsoid(label+'_gripping_palm',hand,(.043,.047,.026),skinmat,helper)
        for finger in range(4):
            fy=yy-.028+finger*.017
            rod(label+'_finger_top',(s*.30,fy,1.125),(s*.267,fy,1.136),.008,skinmat,helper)
            rod(label+'_finger_curl',(s*.267,fy,1.136),(s*.25,fy,1.108),.008,skinmat,helper)
        ellipsoid(label+'_thumb',(hand.x+s*.028,yy-.035,1.100),(.017,.025,.018),skinmat,helper)
    for leg in [-1,1]:
        lx=x+leg*.082;hip=Vector((lx,.48,.93));k0=Vector((lx,.40,.53));a0=Vector((lx,.42,.12))
        thigh=taper(label+'_thigh',hip,k0,.083,.064,denim,helper)
        shin=taper(label+'_shin',k0,a0,.063,.046,denim,helper)
        kneecap=ellipsoid(label+'_rounded_knee',k0,(.064,.064,.065),denim,helper)
        foot=bpy.data.objects.new(label+'_Foot_'+str(leg),None);scene.collection.objects.link(foot);foot.parent=helper;parts.append(foot)
        shoe=ellipsoid(label+'_trainer',(lx,.35,.073),(.068,.128,.055),black,foot)
        box(label+'_shoe_sole',(lx,.35,.023),(.143,.255,.031),white,parent=foot,bevel=.012)
        box(label+'_heel_tab',(lx,.446,.080),(.07,.018,.035),white,parent=foot,bevel=.007)
        for yy in [.31,.335,.36]:box(label+'_shoelace',(lx,yy,.119),(.065,.006,.006),white,parent=foot,bevel=.002)
        for frame in [1,7,11,15,19,23,27,31,36,46]:
            phase=(frame-7)/29*math.pi*4+(0 if leg==1 else math.pi)
            moving=7<frame<36
            step=.12*math.sin(phase) if moving else 0;lift=.065*max(0,math.cos(phase)) if moving else 0
            ankle=Vector((lx,.42+step,.12+lift));knee=Vector((lx,.40+step*.45,.53+lift*.4))
            for o,a,b,original in [(thigh,hip,knee,(k0-hip).length),(shin,knee,ankle,(a0-k0).length)]:
                o.location=(a+b)/2;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.scale.z=(b-a).length/original
                for prop in ['location','rotation_euler','scale']:o.keyframe_insert(data_path=prop,frame=frame)
            kneecap.location=knee;kneecap.keyframe_insert(data_path='location',frame=frame)
            foot.location=(0,step,lift);foot.keyframe_insert(data_path='location',frame=frame)
        for o in [thigh,shin,kneecap,foot]:stash_animation(o)
    helper_objects += [helper]+parts[start:]
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for o in [gate]+parts+[j[0] for j in jaws]:o.select_set(True)
bpy.context.view_layer.objects.active=gate
bpy.ops.export_scene.gltf(filepath=str(OUT/'pursuit_start_gate_with_helpers.glb'),use_selection=True,export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_frame_range=True)

# Product preview staging is excluded from the exported game asset.
floor=material('Studio floor',(.105,.13,.155),0,.65)
box('Preview_floor',(0,0,-.035),(200,200,.05),floor,parent=None,bevel=0)
scene.world=bpy.data.worlds.new('Studio'); scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.39,.48,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
for pos,power,size in [((2,-3,4),650,4),((-3,0,2),500,3),((0,4,3),800,3)]:
    bpy.ops.object.light_add(type='AREA',location=pos); l=bpy.context.object; l.data.energy=power; l.data.shape='DISK'; l.data.size=size
    l.rotation_euler=(Vector((0,.2,.55))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(); cam=bpy.context.object; scene.camera=cam; cam.data.type='ORTHO'
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1200; scene.render.resolution_y=1100; scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
def render(name,pos,target,scale):
    if os.environ.get('GATE_SKIP_RENDERS'):return
    if os.environ.get('GATE_RENDER_ONLY') and name != os.environ['GATE_RENDER_ONLY']:return
    cam.location=pos; cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.ortho_scale=scale
    scene.render.filepath=str(OUT/name); bpy.ops.render.render(write_still=True)
for o in helper_objects:o.hide_render=True
render('01_starttoestel.png',(2.2,-3.2,1.9),(0,.24,.53),1.65)
scene.frame_set(5)
render('02_klem_open.png',(1.5,-2.2,1.15),(0,.12,.39),1.12)
scene.frame_set(1)
for o in helper_objects:o.hide_render=False
render('04_met_twee_helpers.png',(3.0,-4,2.5),(0,.3,.85),2.65)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'pursuit_start_gate.blend'))

# Show alignment with the existing pursuit rider without including it in the asset.
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(next(p for p in OUT.parents if (p/'project.godot').is_file())/'assets/riders/velodrome_pursuit.glb'))
added=set(bpy.data.objects)-before
for o in added:
    if o.parent is None:o.location.y-=.4
scene.frame_set(1)
render('03_met_achtervolgingsfiets.png',(2.8,-3.5,2.0),(0,-.24,.70),2.35)
# Illustrative 12 degree banking, not a hardcoded angle for the game.
bank=bpy.data.objects.new('Preview_track_bank',None); scene.collection.objects.link(bank)
gate.parent=bank
for o in added:
    if o.parent is None:o.parent=bank
bpy.data.objects['Preview_floor'].parent=bank
bank.rotation_euler.y=math.radians(12)
render('05_helling_12_graden.png',(3.3,-4.6,2.7),(0,-.1,.8),2.9)
scene.frame_set(36)
render('06_weggetrokken_op_helling.png',(3.3,-4.6,2.7),(0,.25,.8),3.9)
print('START_GATE_COMPLETE', flush=True)
