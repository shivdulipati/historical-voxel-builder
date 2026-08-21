extends Node
## test_diorama_debug.gd — verify level 10 (DIORAMA DEBUG): stage-only mode
## hides floor + baseplate + HUD, keeps the diorama, and captures the bare
## scene so the props can be judged with zero occlusion.

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)
	ctl._load_structure(9)  # diorama_debug (level 10 in the debug panel, 1-based)
	await get_tree().create_timer(1.5).timeout
	print("DEBUG: mode=%s floor_visible=%s baseplate_visible=%s diorama_children=%d" % [
		ctl._debug_mode, ctl._floor_mesh.visible, ctl._baseplate.visible, ctl._diorama.get_child_count()])
	assert(ctl._debug_mode, "debug mode not active")
	assert(not ctl._floor_mesh.visible, "floor should be hidden")
	assert(not ctl._baseplate.visible, "baseplate should be hidden")
	assert(ctl._diorama.get_child_count() > 200, "diorama should be populated")
	vp.get_texture().get_image().save_png("/tmp/b18_diorama_debug.png")
	print("DEBUG CAPTURE DONE")
	get_tree().quit()
