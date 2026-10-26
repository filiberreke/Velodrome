"""Blender front/back visual QA of the country atlases on both editable rigs.

NATIONAL_KIT_PREVIEWS selects output; NATIONAL_KIT_FILTER limits country IDs.
This renders a separate studio scene and never modifies model source files.
"""
from pathlib import Path
import bpy
import json
import os
from mathutils import Vector

HERE=Path(__file__).resolve().parent
OUT=Path(os.environ.get('NATIONAL_KIT_PREVIEWS',str(HERE/'national_kit_previews')))
OUT.mkdir(parents=True,exist_ok=True)
entries=json.loads((HERE.parent/'riders/national_kits/catalog.json').read_text(encoding='utf-8'))
selected=os.environ.get('NATIONAL_KIT_FILTER','').split(',')
if selected != ['']: entries=[entry for entry in entries if entry['id'] in selected]
for entry in entries:
    for kind in ('rider','pursuit'):
        bpy.ops.wm.open_mainfile(filepath=str(HERE/f'velodrome_{kind}_rig.blend'))
        scene=bpy.context.scene; scene.frame_set(7)
        body=bpy.data.objects['Rider']
        skin=bpy.data.materials['skin'].diffuse_color
        kit=bpy.data.images.load(str(HERE.parent/'riders/national_kits'/entry['id']/'skinsuit.png'))
        helmet=bpy.data.images.load(str(HERE.parent/'riders/national_kits'/entry['id']/'helmet.png'))
        for material in body.data.materials:
            nt=material.node_tree; bsdf=nt.nodes.get('Principled BSDF')
            if material.name.endswith('_kit') or material.name in ('helmet','helmet2'):
                tex=nt.nodes.new('ShaderNodeTexImage')
                tex.image=kit if material.name.endswith('_kit') else helmet
                if material.name.endswith('_kit') and entry['sleeves']=='short':
                    mix=nt.nodes.new('ShaderNodeMixRGB'); mix.inputs[1].default_value=skin
                    nt.links.new(tex.outputs['Alpha'],mix.inputs[0]); nt.links.new(tex.outputs['Color'],mix.inputs[2])
                    nt.links.new(mix.outputs[0],bsdf.inputs['Base Color'])
                else: nt.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
            if material.name=='visor':
                bsdf.inputs['Base Color'].default_value=(.003,.004,.006,1)
                bsdf.inputs['Alpha'].default_value=.88
            if material.name.startswith('decal_'):
                for link in list(bsdf.inputs['Alpha'].links): nt.links.remove(link)
                for node in list(nt.nodes):
                    if node.type == 'TEX_IMAGE': nt.nodes.remove(node)
                bsdf.inputs['Alpha'].default_value=0
        bpy.data.objects['Bike'].hide_render=True
        scene.render.engine='CYCLES'; scene.cycles.samples=8
        scene.render.resolution_x=400; scene.render.resolution_y=480; scene.render.resolution_percentage=100
        scene.world=bpy.data.worlds.new('KitQAWorld'); scene.world.use_nodes=True
        scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.17,.20,1)
        scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
        def aim(ob,target): ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
        for position in [(2,-3,4),(-2,2,3)]:
            bpy.ops.object.light_add(type='AREA',location=position)
            light=bpy.context.object; light.data.energy=600; light.data.size=3; aim(light,(0,0,1))
        for view,position in [('front',(0,-3.5,1.0)),('back',(0,3.5,2.7))]:
            bpy.ops.object.camera_add(location=position)
            camera=bpy.context.object; camera.data.type='ORTHO'; camera.data.ortho_scale=1.65
            aim(camera,(0,-.12,1.02)); scene.camera=camera
            scene.render.filepath=str(OUT/f'{entry["id"]}_{kind}_{view}.png')
            bpy.ops.render.render(write_still=True)
        print('COUNTRY_PREVIEW_OK',entry['id'],kind,flush=True)
