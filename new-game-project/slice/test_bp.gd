extends Node
## test_bp.gd — windowed render test for BlueprintView across structures.
## Captures plan+elevation for structure index passed via cmdline, default 0.

func _ready() -> void:
	var idx := 0
	if OS.get_cmdline_user_args().size() > 0:
		idx = int(OS.get_cmdline_user_args()[0])
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)

	var STRUCTS = preload("res://slice/structures.gd")
	var st: Dictionary = STRUCTS.structures()[idx]

	var ctl := Control.new()
	ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ctl)

	var plan_view := preload("res://slice/mastaba_slice.gd").BlueprintView.new()
	plan_view.custom_minimum_size = Vector2(470, 340)
	plan_view.size = Vector2(470, 340)
	plan_view.mode = 0  # MODE_PLAN
	plan_view.position = Vector2(20, 40)
	ctl.add_child(plan_view)

	var elev_view := preload("res://slice/mastaba_slice.gd").BlueprintView.new()
	elev_view.custom_minimum_size = Vector2(470, 340)
	elev_view.size = Vector2(470, 340)
	elev_view.mode = 1  # MODE_ELEVATION
	elev_view.position = Vector2(510, 40)
	ctl.add_child(elev_view)

	plan_view.set_data(STRUCTS.plan_layers(st), STRUCTS.elevation_cells(st), st["colors"])
	elev_view.set_data(STRUCTS.plan_layers(st), STRUCTS.elevation_cells(st), st["colors"])

	print("STRUCT[%d]: %s core=%d zenith=%d survivor=%d" % [
		idx, st["id"], st["core"].size(), st["zenith"].size(), st["survivor"].size()])
	print("PLAN_LAYERS: ", STRUCTS.plan_layers(st))

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var img := vp.get_texture().get_image()
	img.save_png("/tmp/bp_test_%d.png" % idx)
	print("SAVED /tmp/bp_test_%d.png" % idx)
	get_tree().quit()
