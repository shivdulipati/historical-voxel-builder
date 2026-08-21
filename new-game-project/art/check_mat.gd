extends Node
## art/check_mat.gd — dump the material of the first mesh in a GLB (class,
## albedo, texture) to see why arena models render flat white.

func _ready() -> void:
	for path in ["res://art/arena/floor.glb", "res://art/arena/floor-detail.glb",
			"res://art/arena/tree.glb", "res://art/arena/bricks.glb", "res://art/arena/stairs.glb"]:
		var ps: PackedScene = load(path)
		var inst := ps.instantiate()
		add_child(inst)
		await get_tree().process_frame
		var found := _describe(inst, path)
		print(found)
		inst.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _describe(node: Node3D, path: String) -> String:
	var stack: Array[Node3D] = [node]
	while not stack.is_empty():
		var n: Node3D = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var m := mi.mesh.surface_get_material(0)
			if m == null:
				return "%s: no material" % path
			var extra := ""
			if m is StandardMaterial3D:
				var sm := m as StandardMaterial3D
				var tex := "<none>"
				if sm.albedo_texture != null:
					tex = str(sm.albedo_texture.resource_path)
				extra = " albedo=%s tex=%s vcolor=%s" % [sm.albedo_color, tex, sm.vertex_color_use_as_albedo]
			return "%s: %s%s" % [path, m.get_class(), extra]
		for child in n.get_children():
			if child is Node3D:
				stack.push_back(child)
	return "%s: no mesh" % path
