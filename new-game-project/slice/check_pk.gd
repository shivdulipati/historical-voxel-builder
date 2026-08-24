extends Node
func _ready() -> void:
	for p in ["res://art/platformer/tree.glb", "res://art/platformer/block-grass-overhang-low-long.glb"]:
		var scn := load(p) as PackedScene
		var inst := scn.instantiate()
		add_child(inst)
		await get_tree().process_frame
		_collect(inst, p)
	get_tree().quit(0)

func _collect(n: Node, tag: String) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var m := mi.get_active_material(s)
				print("PK: ", tag, " surf=", s, " mat=", m)
				if m is StandardMaterial3D:
					var sm := m as StandardMaterial3D
					print("PK:   albedo=", sm.albedo_color, " tex=", sm.albedo_texture)
	for c in n.get_children():
		_collect(c, tag)
