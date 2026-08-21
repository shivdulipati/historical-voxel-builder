extends Node
## test_diorama.gd — BUILD 15: verify the mastaba diorama:
##  * clear ring (baseplate limits + 1 tile) contains NO props
##  * diorama covers ~3 phone widths (props/tiles out to r ≈ 23)
##  * capture the render for visual review.

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)
	ctl._load_structure(1)  # mastaba — builds diorama + raising beat
	await get_tree().create_timer(1.5).timeout

	var lim: Vector3 = ctl._st["limits"]
	var clear := Rect2(-(lim.x + 1.0), -(lim.z + 1.0), 2.0 * (lim.x + 1.0), 2.0 * (lim.z + 1.0))
	var inside := 0
	var count := 0
	var max_r := 0.0
	var visible_count := 0
	for node in ctl._diorama.get_children():
		count += 1
		if node is Node3D:
			var p: Vector3 = node.position
			var r: float = Vector2(p.x, p.z).length()
			if r > max_r:
				max_r = r
			if node.is_visible_in_tree():
				visible_count += 1
			# Tiles sit at y≈0.005 (floor texture continues in the ring by
			# design); props sit at y=0 and must stay outside the clear ring.
			if p.y < 0.001 and clear.has_point(Vector2(p.x, p.z)):
				inside += 1
	print("DIORAMA: props+tiles=%d visible=%d max_r=%.1f (want >= 22) inside_clear_ring=%d (want 0)" % [count, visible_count, max_r, inside])
	assert(inside == 0, "props inside the clear ring!")
	assert(max_r >= 22.0, "diorama does not cover 3 phone widths")
	# Deterministic screen-projection check: sample props + the nearest tile.
	var vp_size := vp.get_visible_rect().size
	var n_props := 0
	for node in ctl._diorama.get_children():
		var p: Vector3 = node.position
		if p.y < 0.001:  # a prop
			var sp: Vector2 = ctl._camera.unproject_position(p)
			var in_frame := sp.x >= 0 and sp.x <= vp_size.x and sp.y >= 0 and sp.y <= vp_size.y
			print("  prop at %s -> screen %s in_frame=%s" % [p, sp.round(), in_frame])
			n_props += 1
			if n_props >= 10:
				break
	vp.get_texture().get_image().save_png("/tmp/b15_diorama_mastaba.png")
	# Top-down diagnostic: every prop/tile projects into frame.
	ctl._snap_camera(Vector3(-PI / 2.0, 0.0, 0.0))
	await get_tree().create_timer(0.6).timeout
	vp.get_texture().get_image().save_png("/tmp/b15_diorama_top.png")
	print("DIORAMA CAPTURE DONE")
	get_tree().quit()
