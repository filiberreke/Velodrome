extends RefCounted
## Explicitly reuse only the live bike's mesh, never a Vélodrome cabin.
static var parts:Array[Dictionary]=[]
static func build(parent:Node3D,position:Vector3,yaw:float)->Node3D:
	if parts.is_empty():
		var original=preload("res://assets/riders/velodrome_rider.glb").instantiate()
		var bike:MeshInstance3D=original.find_child("Bike",true,false)
		for i in bike.mesh.get_surface_count():
			var arrays:Array=bike.mesh.surface_get_arrays(i).duplicate()
			arrays[Mesh.ARRAY_BONES]=null;arrays[Mesh.ARRAY_WEIGHTS]=null
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			parts.append({"mesh":mesh,"material":bike.get_active_material(i)})
		original.free()
	var root:=Node3D.new();root.name="GentParkedBike";root.position=position;root.rotation.y=yaw;parent.add_child(root)
	for part in parts:
		var n:=MeshInstance3D.new();n.mesh=part.mesh;n.material_override=part.material;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(n)
	return root
