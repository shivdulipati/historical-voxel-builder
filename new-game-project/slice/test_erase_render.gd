extends Node3D
## test_erase_render.gd — BUILD 10: render check for the eraser highlight
## (pulsing gold outline on deletable blocks only).

const SliceScene = preload("res://slice/mastaba_slice.tscn")

func _ready() -> void:
	var slice := SliceScene.instantiate()
	add_child(slice)
	await get_tree().process_frame
	# Göbekli raising: two 2-stacks + a lone ground block.
	var placements := [
		Vector3i(0, 0, 0), Vector3i(0, 1, 0),
		Vector3i(2, 0, 0), Vector3i(2, 1, 0),
		Vector3i(-2, 0, 0),
	]
	for p in placements:
		var b = slice.SliceBlock.new()
		slice.add_child(b)
		b.limit_x = slice._st["limits"].x
		b.limit_z = slice._st["limits"].z
		b.limit_y = slice._st["limits"].y
		b.place_at(p, slice._st["colors"]["limestone"], "limestone")
	await get_tree().physics_frame
	slice.set_tool(slice.Tool.ERASER)
	await get_tree().create_timer(0.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/slice_b10_erase.png")
	print("ERASE-RENDER-TEST: captured /tmp/slice_b10_erase.png")
	get_tree().quit()
