extends Node
## test_capture.gd — windowed captures for pixel verification of the baseplate
## grid and the ghost rendering (no vision model available — pixels are proof).

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)
	ctl._load_structure(0)
	ctl._start_beat(1)  # RESTORATION — 18 T-cap ghosts

	# Capture 1: grid only (Plan-only scaffold → zero ghosts).
	ctl.scaffold_mode = 2  # Scaffold.PLAN_ONLY
	ctl._refresh_ghosts()
	ctl._snap_camera(Vector3(-PI / 2.0, 0.0, 0.0))  # top view
	await get_tree().create_timer(0.9).timeout
	vp.get_texture().get_image().save_png("/tmp/b7_grid.png")

	# Capture 2: ghosts (Ghost scaffold).
	ctl.scaffold_mode = 0  # Scaffold.GHOST
	ctl._refresh_ghosts()
	await get_tree().create_timer(0.3).timeout
	vp.get_texture().get_image().save_png("/tmp/b7_ghosts.png")

	# Capture 3: after placing ONE real T-cap, its 3 ghost cells must vanish.
	var SliceBlock = preload("res://slice/slice_block.gd")
	for y in [0, 1]:
		var stem := SliceBlock.new()
		ctl.add_child(stem)
		stem.place_at(Vector3i(0, y, -1), Color.WHITE, "limestone")
	await get_tree().physics_frame
	await get_tree().physics_frame
	ctl._spawn_piece_in_hand("t_cap", Vector2(540, 900), -1)
	await get_tree().process_frame
	var piece = null
	for b in get_tree().get_nodes_in_group("slice_blocks"):
		if not b.piece_cells.is_empty():
			piece = b
			break
	piece.global_position = Vector3(0, 7, -1)
	await get_tree().physics_frame
	piece._drop_piece_to_grid()
	await get_tree().process_frame
	await get_tree().process_frame
	var ghost_count := get_tree().get_nodes_in_group("slice_ghosts").size()
	print("GHOSTS_AFTER_PLACE=%d (expect 15: 18 cap cells minus 3 placed)" % ghost_count)
	assert(ghost_count == 15)
	vp.get_texture().get_image().save_png("/tmp/b7_after_place.png")

	# Capture 4: landing indicators for a held piece must be DARK squares.
	var piece2 = null
	for b in get_tree().get_nodes_in_group("slice_blocks"):
		if not b.piece_cells.is_empty() and b != piece:
			piece2 = b
			break
	if piece2 == null:
		ctl._spawn_piece_in_hand("t_cap", Vector2(540, 900), -1)
		await get_tree().process_frame
		for b in get_tree().get_nodes_in_group("slice_blocks"):
			if not b.piece_cells.is_empty() and b != piece:
				piece2 = b
				break
	piece2.global_position = Vector3(0, 7, -1)
	await get_tree().physics_frame
	piece2._drop_indicator.visible = true
	for ind in piece2._extra_indicators:
		ind.visible = true
	piece2._update_piece_indicators([Vector3i(-1, 2, -1), Vector3i(0, 2, -1), Vector3i(1, 2, -1)])
	await get_tree().process_frame
	vp.get_texture().get_image().save_png("/tmp/b7_indicators.png")
	print("CAPTURES DONE")
	get_tree().quit()
