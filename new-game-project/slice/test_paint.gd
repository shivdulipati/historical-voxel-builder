extends Node3D
## test_paint.gd — BUILD 9: painted (parked) cells must stay physics-solid so
## later layers stack on them (the pyramid mid-layer paint bug).

const SliceScene = preload("res://slice/mastaba_slice.tscn")

func _ready() -> void:
	var slice := SliceScene.instantiate()
	add_child(slice)
	await get_tree().process_frame
	# Pyramid of Giza = structure index 2.
	slice._load_structure(2)
	await get_tree().process_frame
	# Paint the base cell at the origin the way the paint tool does.
	slice._on_paint_requested(Vector3i(0, 0, 0), "limestone")
	await get_tree().physics_frame
	# A fresh block hovering over that cell must stack ON TOP of the parked
	# block (stack height 1.5 => grid y=1), not fall through to the floor (0.5).
	var probe = slice.SliceBlock.new()
	slice.add_child(probe)
	probe.limit_x = slice._st["limits"].x
	probe.limit_z = slice._st["limits"].z
	probe.limit_y = slice._st["limits"].y
	probe.global_position = Vector3(0, 6, 0)
	await get_tree().physics_frame
	var h: float = probe._get_stack_height(0, 0)
	print("PAINT-TEST: stack height over painted cell = ", h, " (want 1.5)")
	print("PAINT-TEST: ", "PASS" if absf(h - 1.5) < 0.01 else "FAIL")
	get_tree().quit()
