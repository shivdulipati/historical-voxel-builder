extends Node
## test_piece.gd — headless validation of the multi-cell piece pipeline:
## compound body build, support-rule drop, Y-rotation, atomic rejection.

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	ctl._load_structure(0)          # Göbekli
	ctl._start_beat(1)              # RESTORATION — T-caps are the target
	await get_tree().process_frame
	await get_tree().process_frame

	var SliceBlock = preload("res://slice/slice_block.gd")
	var PIECES = preload("res://slice/pieces.gd")

	# --- Build one real pillar stem at (0,-1): cells (0,-1,0) and (0,-1,1).
	for y in [0, 1]:
		var stem := SliceBlock.new()
		ctl.add_child(stem)
		stem.place_at(Vector3i(0, y, -1), Color.WHITE, "limestone")

	await get_tree().physics_frame
	await get_tree().physics_frame

	# --- Spawn a T-cap through the controller (compound body + tray wiring).
	ctl._spawn_piece_in_hand("t_cap", Vector2(540, 900), -1)
	await get_tree().process_frame
	var piece = null
	for b in get_tree().get_nodes_in_group("slice_blocks"):
		if not b.piece_cells.is_empty():
			piece = b
			break
	print("PIECE cells=%d meshes=%d" % [piece.piece_cells.size(), piece._cell_meshes.size()])
	assert(piece._cell_meshes.size() == 3)

	# --- Valid drop: centre the cap on the pillar top → origin (0,2,-1).
	piece.global_position = Vector3(0, 7, -1)
	await get_tree().physics_frame
	piece._drop_piece_to_grid()
	await get_tree().process_frame
	print("PLACED cells=%s placed=%s completed=%d" % [piece._placed_cells, piece.is_placed, ctl.completed_cells.size()])
	assert(piece.is_placed)
	assert(piece._placed_cells.size() == 3)
	assert(piece._placed_cells.has(Vector3i(0, 2, -1)))
	assert(ctl.completed_cells.size() == 3)

	# --- Invalid drop: rotated 90° → cap cells overlap the placed cap → reject.
	var piece2 := SliceBlock.new()
	piece2.limit_x = ctl._st["limits"].x
	piece2.limit_z = ctl._st["limits"].z
	piece2.limit_y = ctl._st["limits"].y
	piece2.piece_cells = PIECES.pieces()["t_cap"]["cells"]
	piece2.piece_anchors = PIECES.pieces()["t_cap"]["anchors"]
	piece2.piece_min_anchors = 1
	piece2.set_block_color(Color.WHITE, "limestone")
	piece2.gravity_scale = 0.0
	piece2._rotation_steps = 1
	ctl.add_child(piece2)
	piece2.global_position = Vector3(0, 7, -1)
	piece2.piece_placed.connect(ctl._on_piece_placed)
	piece2.piece_removed.connect(ctl._on_piece_removed)
	await get_tree().physics_frame
	piece2._drop_piece_to_grid()
	await get_tree().create_timer(0.6).timeout  # rejection = 0.35s flash, then free
	print("ROTATED freed=%s completed=%d" % [not is_instance_valid(piece2), ctl.completed_cells.size()])
	assert(not is_instance_valid(piece2))
	assert(ctl.completed_cells.size() == 3)

	# --- Support-rule rejection: drop where there is NO pillar (0,0).
	var piece3 := SliceBlock.new()
	piece3.limit_x = ctl._st["limits"].x
	piece3.limit_z = ctl._st["limits"].z
	piece3.limit_y = ctl._st["limits"].y
	piece3.piece_cells = PIECES.pieces()["t_cap"]["cells"]
	piece3.piece_anchors = PIECES.pieces()["t_cap"]["anchors"]
	piece3.piece_min_anchors = 1
	piece3.set_block_color(Color.WHITE, "limestone")
	piece3.gravity_scale = 0.0
	ctl.add_child(piece3)
	piece3.global_position = Vector3(0, 7, 0)
	piece3.piece_placed.connect(ctl._on_piece_placed)
	piece3.piece_removed.connect(ctl._on_piece_removed)
	await get_tree().physics_frame
	piece3._drop_piece_to_grid()
	await get_tree().create_timer(0.6).timeout  # rejection = 0.35s flash, then free
	print("NO_SUPPORT freed=%s" % [not is_instance_valid(piece3)])
	assert(not is_instance_valid(piece3))

	print("PIECE_TESTS PASS")
	get_tree().quit()
