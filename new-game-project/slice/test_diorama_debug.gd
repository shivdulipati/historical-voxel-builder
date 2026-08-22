extends Node
## test_diorama_debug.gd — verify level 10 (DIORAMA DEBUG) with the new
## earth-slice diorama:
##  * stage-only mode hides the earth slice + baseplate + HUD
##  * the mastaba earth slice is built (slab top at y=0, strata bound,
##    fossils placed) — the debug stage is the slice in isolation
##  * capture the bare scene for visual review

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)
	ctl._load_structure(9)  # diorama_debug (level 10 in the debug panel, 1-based)
	await get_tree().create_timer(1.5).timeout

	assert(ctl._debug_mode, "debug mode not active")
	assert(not ctl._earth_slice.visible, "earth slice should be hidden in debug mode")
	assert(not ctl._baseplate.visible, "baseplate should be hidden")

	var slab: MeshInstance3D = null
	for child in ctl._earth_slice.get_children():
		if child.name == "EarthSlab":
			slab = child
	assert(slab != null, "EarthSlab missing in debug stage")
	var box := slab.mesh as BoxMesh
	var top_y: float = slab.position.y + box.size.y / 2.0
	print("DEBUG: slab top_y=%.3f fossils=%d bones=%d" % [
		top_y, ctl._earth_slice.fossil_count, ctl._earth_slice.bone_count])
	assert(absf(top_y) < 0.001, "slab top face must sit at y=0")
	assert(ctl._earth_slice.fossil_count >= 6, "fossils missing in debug stage")
	assert(ctl._earth_slice.bone_count >= 1, "bone missing in debug stage")
	assert((slab.material_override as ShaderMaterial).get_shader_parameter("strata_tex") != null,
			"strata texture not bound")
	# Re-enable the slice so the capture shows the full stage.
	ctl._earth_slice.visible = true
	ctl._camera.size = 55.0
	ctl._pivot.rotation = Vector3(-0.45, 0.8, 0.0)
	await get_tree().create_timer(0.5).timeout
	vp.get_texture().get_image().save_png("/tmp/b23_diorama_debug.png")
	print("DEBUG CAPTURE DONE")
	get_tree().quit()
