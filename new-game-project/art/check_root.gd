extends Node
## art/check_root.gd — instantiate a few GLBs and print the ROOT node's
## transform + each mesh child's GLOBAL position, to detect baked-in offsets
## that would sink props below the floor surface (y=0).

func _ready() -> void:
	for name in ["tree_palmTall", "rock_largeB", "rock_smallA", "grass", "plant_bush", "flower_yellowA", "ground_pathRocks", "stump_round", "tent_smallClosed", "log", "cactus_short"]:
		var ps: PackedScene = load("res://art/nature/%s.glb" % name)
		var inst := ps.instantiate()
		add_child(inst)
		await get_tree().process_frame
		print("== %s root pos=%s rot=%s scale=%s" % [name, inst.position, inst.rotation, inst.scale])
		var stack: Array[Node3D] = [inst]
		var n := 0
		while not stack.is_empty() and n < 10:
			var node: Node3D = stack.pop_back()
			if node is MeshInstance3D or node is VisualInstance3D:
				print("   child '%s' scale=%s aabb_size=%s" % [node.name, node.scale, _local_aabb(node).size])
				n += 1
			for child in node.get_children():
				if child is Node3D:
					stack.push_back(child)
		inst.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _local_aabb(node: Node3D) -> AABB:
	if node is VisualInstance3D:
		return (node as VisualInstance3D).get_aabb()
	return AABB()
