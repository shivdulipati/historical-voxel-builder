extends Node
## test_bp.gd — windowed render test for the BlueprintView: captures the plan
## and elevation views to /tmp/bp_test.png so we can verify what actually draws.

func _ready() -> void:
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)

	# Replicate the sheet layout: two views side by side.
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

	var DATA = preload("res://slice/mastaba_data.gd")
	plan_view.set_data(DATA.plan_layers(), DATA.elevation_cells())
	elev_view.set_data(DATA.plan_layers(), DATA.elevation_cells())

	print("PLAN_LAYERS: ", DATA.plan_layers())
	print("ELEV_KEYS: ", DATA.elevation_cells().size())

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var img := vp.get_texture().get_image()
	img.save_png("/tmp/bp_test.png")
	print("SAVED /tmp/bp_test.png ", img.get_size())
	get_tree().quit()
