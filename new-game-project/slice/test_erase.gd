extends Node3D
## test_erase.gd — BUILD 10: deletability rule.
## A block is deletable iff nothing sits above it AND it has support beneath
## (ground counts). Pieces are atomic: all cells clear above + one supported.

const SliceScene = preload("res://slice/mastaba_slice.tscn")

func _ready() -> void:
	var slice := SliceScene.instantiate()
	add_child(slice)
	await get_tree().process_frame
	# Pin to Göbekli regardless of any save left by earlier test runs.
	slice._load_structure(0)
	await get_tree().process_frame
	# Stack column A at x=1: (1,0,0),(1,1,0),(1,2,0).
	var stack := []
	for y in range(3):
		var b = slice.SliceBlock.new()
		slice.add_child(b)
		b.limit_x = slice._st["limits"].x
		b.limit_z = slice._st["limits"].z
		b.limit_y = slice._st["limits"].y
		b.place_at(Vector3i(1, y, 0), slice._st["colors"]["limestone"], "limestone")
		stack.append(b)
	# Lone ground block.
	var g = slice.SliceBlock.new()
	slice.add_child(g)
	g.limit_x = slice._st["limits"].x
	g.limit_z = slice._st["limits"].z
	g.limit_y = slice._st["limits"].y
	g.place_at(Vector3i(2, 0, 0), slice._st["colors"]["limestone"], "limestone")
	# Stem column B at x=-1 with a T-cap on top.
	var stem := []
	for y in range(2):
		var s = slice.SliceBlock.new()
		slice.add_child(s)
		s.limit_x = slice._st["limits"].x
		s.limit_z = slice._st["limits"].z
		s.limit_y = slice._st["limits"].y
		s.place_at(Vector3i(-1, y, 0), slice._st["colors"]["limestone"], "limestone")
		stem.append(s)
	var cap = slice.SliceBlock.new()
	slice.add_child(cap)
	cap.limit_x = slice._st["limits"].x
	cap.limit_z = slice._st["limits"].z
	cap.limit_y = slice._st["limits"].y
	cap.piece_cells = slice.PIECES.pieces()["t_cap"]["cells"]
	cap.piece_anchors = slice.PIECES.pieces()["t_cap"]["anchors"]
	cap.set_block_color(slice._st["colors"]["limestone"], "limestone")
	cap.global_position = Vector3(-1, 8, 0)
	await get_tree().physics_frame
	cap._drop_piece_to_grid()
	await get_tree().create_timer(0.3).timeout  # let the land tween finish

	var fails := [0]
	var check := func(label: String, got: bool, want: bool):
		var ok := got == want
		if not ok:
			fails[0] += 1
		print("ERASE-TEST: ", label, " = ", got, " (want ", want, ") ", "PASS" if ok else "FAIL")

	check.call("stack bottom", stack[0]._is_deletable(), false)
	check.call("stack middle", stack[1]._is_deletable(), false)
	check.call("stack top", stack[2]._is_deletable(), true)
	check.call("lone ground block", g._is_deletable(), true)
	check.call("t-cap piece", cap._is_deletable(), true)
	check.call("stem top under cap", stem[1]._is_deletable(), false)

	# Removing the stack top must free the middle.
	stack[2].queue_free()
	await get_tree().physics_frame
	check.call("stack middle after top removed", stack[1]._is_deletable(), true)

	# --- Paint + erase connection (BUILD 12) ---
	# A painted cell must be visible to Erase: in slice_blocks, deletable,
	# and clearing it removes the completed cell.
	slice._on_paint_requested(Vector3i(-2, 0, 0), "limestone")
	await get_tree().physics_frame
	var parked = null
	for blk in get_tree().get_nodes_in_group("slice_blocks"):
		if blk.is_parked and blk.current_grid_position == Vector3i(-2, 0, 0):
			parked = blk
	check.call("painted cell found in slice_blocks", parked != null, true)
	if parked:
		check.call("painted cell deletable", parked._is_deletable(), true)
		parked._emit_removed()
		parked.queue_free()
		await get_tree().physics_frame
		check.call("painted cell cleared from completed", not slice.completed_cells.has(Vector3i(-2, 0, 0)), true)

	print("ERASE-TEST: ", "ALL PASS" if fails[0] == 0 else "%d FAIL" % fails[0])
	get_tree().quit()
