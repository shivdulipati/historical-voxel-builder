extends Node3D
## test_render.gd — BUILD 8 render verification: captures the slice at Göbekli
## RESTORATION with the core built, a T-Cap piece placed on a pillar, and a
## T-Cap hovering in hand. Used to vision-verify the ghost outline, the
## baseplate grid, and the 1x3 piece shape.

const SliceScene = preload("res://slice/mastaba_slice.tscn")

func _ready() -> void:
	var slice := SliceScene.instantiate()
	add_child(slice)
	await get_tree().process_frame

	# Jump to RESTORATION with the raising core already built (stems).
	slice._start_beat(slice.Beat.RESTORATION)
	await get_tree().process_frame
	var core: Dictionary = slice._st["core"]
	for pos in core:
		var color_name: String = core[pos]
		slice.completed_cells[pos] = color_name
		var block = slice.SliceBlock.new()
		slice.add_child(block)
		block.limit_x = slice._st["limits"].x
		block.limit_z = slice._st["limits"].z
		block.limit_y = slice._st["limits"].y
		block.place_at(pos, slice._st["colors"][color_name], color_name)
	slice._refresh_ghosts()
	slice._update_progress()
	await get_tree().physics_frame

	# T-Cap piece hovering in hand (the shape under test: 3 cells wide).
	slice._spawn_piece_in_hand("t_cap", Vector2(540, 1000), -1)

	# A second T-Cap dropped onto the front pillar (0, 2) stem top.
	var piece = slice.SliceBlock.new()
	slice.add_child(piece)
	piece.limit_x = slice._st["limits"].x
	piece.limit_z = slice._st["limits"].z
	piece.limit_y = slice._st["limits"].y
	piece.piece_cells = slice.PIECES.pieces()["t_cap"]["cells"]
	piece.piece_anchors = slice.PIECES.pieces()["t_cap"]["anchors"]
	piece.set_block_color(slice._st["colors"]["limestone"], "limestone")
	piece.global_position = Vector3(0, 8, 2)
	await get_tree().physics_frame
	piece._drop_piece_to_grid()

	await get_tree().create_timer(1.0).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/slice_b8_iso.png")

	# Top-down view to verify the grid reads in both directions.
	slice._snap_camera(Vector3(-PI / 2.0, 0.0, 0.0))
	await get_tree().create_timer(0.6).timeout
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png("/tmp/slice_b8_top.png")

	# Close-up of a ghost T-cap (far pillar at z=-2) to judge outline width.
	slice._snap_camera(Vector3(-0.35, 0.0, 0.0))
	slice._pivot.position = Vector3(0.0, 3.2, -2.0)
	slice._camera.size = 4.2
	await get_tree().create_timer(0.6).timeout
	var img3 := get_viewport().get_texture().get_image()
	img3.save_png("/tmp/slice_b8_ghost_close.png")

	print("RENDER-TEST: captured /tmp/slice_b8_iso.png + _top.png + _ghost_close.png")
	get_tree().quit()
