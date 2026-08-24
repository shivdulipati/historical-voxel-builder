extends Node
## test_diorama_debug.gd — verify level 10 (DIORAMA DEBUG) with the blob
## diorama:
##  * stage-only mode hides the diorama + baseplate + HUD
##  * the blob diorama is built (mask + grass + strata) — the debug stage
##    is the island in isolation
##  * capture the bare scene for visual review

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)
	ctl._load_structure(9)  # diorama_debug (level 10 in the debug panel, 1-based)
	await get_tree().create_timer(1.5).timeout

	assert(ctl._debug_mode, "debug mode not active")
	assert(not ctl._diorama.visible, "diorama should be hidden in debug mode")
	assert(not ctl._baseplate.visible, "baseplate should be hidden")

	var dia: Node3D = ctl._diorama
	var nodes := dia.get_children()
	var prop_count := 0
	for c in nodes:
		if (c as Node3D) != null and not ((c as Node3D).name in ["Main", "LedgeL", "ExtR", "PlatBack", "CornerFR"]):
			prop_count += 1
	print("DEBUG: nodes=%d props=%d" % [nodes.size(), prop_count])
	assert(nodes.size() >= 13, "composition not built in debug stage")
	assert(prop_count >= 8, "props missing in debug stage")
	# Re-enable the diorama so the capture shows the full stage.
	ctl._diorama.visible = true
	ctl._camera.size = 55.0
	ctl._pivot.rotation = Vector3(-0.45, 0.8, 0.0)
	await get_tree().create_timer(0.5).timeout
	vp.get_texture().get_image().save_png("/tmp/b25_diorama_debug.png")
	print("DEBUG CAPTURE DONE")
	get_tree().quit()
