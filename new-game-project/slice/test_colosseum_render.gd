extends Node3D
## test_colosseum_render.gd — BUILD 12: colosseum restoration — the upper
## seating ghosts must sit on the ring walls (nothing floating over the pit).

const SliceScene = preload("res://slice/mastaba_slice.tscn")

func _ready() -> void:
	var slice := SliceScene.instantiate()
	add_child(slice)
	await get_tree().process_frame
	slice._load_structure(8)
	await get_tree().process_frame
	# Build the raising core (rings) so restoration ghosts sit on real walls.
	for pos in slice._st["core"]:
		var color_name: String = slice._st["core"][pos]
		var b = slice.SliceBlock.new()
		slice.add_child(b)
		b.limit_x = slice._st["limits"].x
		b.limit_z = slice._st["limits"].z
		b.limit_y = slice._st["limits"].y
		b.place_at(pos, slice._st["colors"][color_name], color_name)
		slice.completed_cells[pos] = color_name
	slice._start_beat(slice.Beat.RESTORATION)
	await get_tree().create_timer(0.6).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/slice_b12_colosseum.png")
	print("COLOSSEUM-RENDER-TEST: captured /tmp/slice_b12_colosseum.png")
	get_tree().quit()
