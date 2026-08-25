extends Node
## test_angle_probe.gd — render from the two mirror-candidate corners:
## yaw 45.8 deg (default NE view) and 225.8 deg (opposite corner, the
## AF-screenshot-style angle) for the mirror comparison (BUILD 36).

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)
	ctl._load_structure(1)
	await get_tree().create_timer(1.2).timeout
	ctl._hud_root.visible = false
	ctl._pivot.position = Vector3.ZERO
	ctl._pivot.rotation = Vector3(-0.45, 0.8, 0.0)
	await get_tree().create_timer(0.5).timeout
	vp.get_texture().get_image().save_png("/tmp/angle_ne.png")
	ctl._pivot.rotation = Vector3(-0.45, 0.8 + PI, 0.0)
	await get_tree().create_timer(0.5).timeout
	vp.get_texture().get_image().save_png("/tmp/angle_sw.png")
	print("ANGLE PROBE DONE")
	get_tree().quit()
