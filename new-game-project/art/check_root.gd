extends Node
## art/check_root.gd — instantiate a few GLBs and print the ROOT node's
## transform + each mesh child's GLOBAL position, to detect baked-in offsets
## that would sink props below the floor surface (y=0).

func _ready() -> void:
	for name in ["tree_palmTall", "rock_largeB", "ground_pathRocks", "grass", "tent_smallClosed"]:
		var ps: PackedScene = load("res://art/nature/%s.glb" % name)
		var inst := ps.instantiate()
		add_child(inst)
		await get_tree().process_frame
		print("== %s root pos=%s rot=%s scale=%s" % [name, inst.position, inst.rotation, inst.scale])
		var stack: Array[Node3D] = [inst]
		var n := 0
		while not stack.is_empty() and n < 8:
			var node: Node3D = stack.pop_back()
			if node is MeshInstance3D or node is VisualInstance3D:
				print("   child '%s' global_pos=%s local_pos=%s" % [node.name, node.global_position, node.position])
				n += 1
			for child in node.get_children():
				if child is Node3D:
					stack.push_back(child)
		inst.queue_free()
	await get_tree().process_frame
	get_tree().quit()
