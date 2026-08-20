extends Node3D
## test_save.gd — BUILD 8 save/restore round-trip. Run twice:
##   mode=save : completes Göbekli restoration, saves, quits
##   mode=load : boots fresh and verifies the saved state restored

const SliceScene = preload("res://slice/mastaba_slice.tscn")

func _ready() -> void:
	var mode := "save"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="):
			mode = a.get_slice("=", 1)
	var slice := SliceScene.instantiate()
	add_child(slice)
	await get_tree().process_frame

	if mode == "save":
		slice._start_beat(slice.Beat.RESTORATION)
		await get_tree().process_frame
		for pos in slice._st["zenith"]:
			var color_name: String = slice._st["zenith"][pos]
			slice.completed_cells[pos] = color_name
			var block = slice.SliceBlock.new()
			slice.add_child(block)
			block.limit_x = slice._st["limits"].x
			block.limit_z = slice._st["limits"].z
			block.limit_y = slice._st["limits"].y
			block.place_at(pos, slice._st["colors"][color_name], color_name)
		slice._save_game()
		print("SAVE-TEST: beat=", slice.current_beat,
			" cells=", slice.completed_cells.size())
	elif mode == "excav":
		# Simulate a player mid-excavation with 2 of 3 mounds left.
		slice._start_beat(slice.Beat.EXCAVATION)
		await get_tree().process_frame
		var cells = slice.STRUCTS.dust_cells(slice._st).keys()
		for i in range(cells.size() - 1):
			slice._spawn_dust_at(cells[i])
		slice._dust_total = cells.size()
		slice._dust_cleared = 1
		slice._save_game()
		print("EXCAV-TEST: mounds=", slice.dust_mounds.size(),
			" total=", slice._dust_total, " cleared=", slice._dust_cleared)
	else:
		print("LOAD-TEST: beat=", slice.current_beat,
			" cells=", slice.completed_cells.size(),
			" blocks=", get_tree().get_nodes_in_group("slice_blocks").size(),
			" mounds=", slice.dust_mounds.size(),
			" cleared=", slice._dust_cleared,
			" scaffold=", slice.scaffold_mode)
	get_tree().quit()
