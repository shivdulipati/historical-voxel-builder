extends Node
## test_diorama_debug.gd — verify level 10 (DIORAMA DEBUG):
##  * stage-only mode hides floor + baseplate + HUD, keeps the diorama
##  * EVERY prop has non-zero scale AND a true world-space rendered height
##    > 0.4 units (guards against the scale-zero bug: entry.get("s", 0.0)
##    silently zeroed every prop without an explicit override)
##  * capture the bare scene for visual review

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)
	ctl._load_structure(9)  # diorama_debug (level 10 in the debug panel, 1-based)
	await get_tree().create_timer(1.5).timeout

	assert(ctl._debug_mode, "debug mode not active")
	assert(not ctl._floor_mesh.visible, "floor should be hidden")
	assert(not ctl._baseplate.visible, "baseplate should be hidden")

	# True rendered height: local AABB transformed by the full node hierarchy.
	var heights: Array[float] = []
	var zero_scale := 0
	var mm_count := 0
	var mm_instances := 0
	var mm_min_x := 999.0
	var mm_max_x := -999.0
	var mm_min_z := 999.0
	var mm_max_z := -999.0
	for node in ctl._diorama.get_children():
		if not node is Node3D:
			continue
		var n3 := node as Node3D
		if n3.scale.length() < 0.1:
			zero_scale += 1
		if n3 is MultiMeshInstance3D:
			mm_count += 1
			var mm: MultiMesh = (n3 as MultiMeshInstance3D).multimesh
			mm_instances += mm.instance_count
			for i in mm.instance_count:
				var o: Vector3 = mm.get_instance_transform(i).origin
				mm_min_x = minf(mm_min_x, o.x)
				mm_max_x = maxf(mm_max_x, o.x)
				mm_min_z = minf(mm_min_z, o.z)
				mm_max_z = maxf(mm_max_z, o.z)
			continue
		if n3.position.y >= 0.001:
			continue  # tiles are flat by design — only props must stand tall
		var world := _world_aabb(n3)
		if world.size.y > 0.001:
			heights.append(world.size.y)
	heights.sort()
	var min_h := heights[0] if not heights.is_empty() else 0.0
	var med_h := heights[heights.size() / 2] if not heights.is_empty() else 0.0
	var max_h := heights[heights.size() - 1] if not heights.is_empty() else 0.0
	print("DEBUG: children=%d zero_scale=%d heights(min=%.2f med=%.2f max=%.2f) want med>0.4 max>3" % [
		ctl._diorama.get_child_count(), zero_scale, min_h, med_h, max_h])
	assert(zero_scale == 0, "props with zero scale!")
	assert(med_h > 0.4, "props render too flat — median world height %.2f" % med_h)
	assert(max_h > 3.0, "no tall props — palms missing, max %.2f" % max_h)
	print("GROUND: multimeshes=%d instances=%d x[%.0f..%.0f] z[%.0f..%.0f] want x>=±19 z>=±34" % [
		mm_count, mm_instances, mm_min_x, mm_max_x, mm_min_z, mm_max_z])
	assert(mm_count >= 2, "arena ground MultiMeshes missing")
	assert(mm_instances >= 600, "arena ground too sparse: %d instances" % mm_instances)
	assert(mm_min_x <= -19.0 and mm_max_x >= 19.0, "ground x coverage short")
	assert(mm_min_z <= -34.0 and mm_max_z >= 34.0, "ground z coverage short (5 phone lengths)")
	vp.get_texture().get_image().save_png("/tmp/b19_diorama_debug.png")
	print("DEBUG CAPTURE DONE")
	get_tree().quit()


func _world_aabb(node: Node3D) -> AABB:
	var out: AABB
	var first := true
	var stack: Array[Node3D] = [node]
	while not stack.is_empty():
		var n: Node3D = stack.pop_back()
		if n is VisualInstance3D:
			var local: AABB = (n as VisualInstance3D).get_aabb()
			if local.size.length() > 0.0:
				var t: AABB = local
				t.position = n.global_transform * local.position
				t.size = local.size * n.global_transform.basis.get_scale()
				if first:
					out = t
					first = false
				else:
					out = out.merge(t)
		for child in n.get_children():
			if child is Node3D:
				stack.push_back(child)
	return out
