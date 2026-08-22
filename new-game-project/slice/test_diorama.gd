extends Node
## test_diorama.gd — verify the mastaba EARTH-SLICE diorama:
##  * the slab exists with its top face at y=0 (block resting plane)
##  * the strata texture is bound to the slab material
##  * fossils are embedded in the sides (>= 6 sprites + the bone)
##  * the sky is the beat shader and every beat repaints distinct colors
##  * the idle bob moves the stage only when hands-off
##  * captures: default view + all four beat skies + side + top views

const BEATS := [
	[0, "raising"],
	[1, "restoration"],
	[2, "decay"],
	[3, "excavation"],
]

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)
	ctl._load_structure(1)  # mastaba — builds earth slice + raising beat
	await get_tree().create_timer(1.5).timeout

	# --- Slab: exists, top at y=0, strata texture bound ---
	var slab: MeshInstance3D = null
	for child in ctl._earth_slice.get_children():
		if child.name == "EarthSlab":
			slab = child
	assert(slab != null, "EarthSlab missing")
	var box := slab.mesh as BoxMesh
	assert(box != null, "slab is not a BoxMesh")
	var top_y: float = slab.position.y + box.size.y / 2.0
	print("SLAB: top_y=%.3f (want 0.0) size=%s" % [top_y, box.size])
	assert(absf(top_y) < 0.001, "slab top face must sit at y=0")
	assert(absf(box.size.x - box.size.z) < 0.01, "slab should be square")
	assert(box.size.y > 6.0, "slab too thin — strata need depth")
	var mat := slab.material_override as ShaderMaterial
	assert(mat != null, "slab needs the strata shader")
	assert(mat.get_shader_parameter("strata_tex") != null, "strata texture not bound")
	assert(mat.get_shader_parameter("top_tex") != null, "top sand texture not bound")

	# --- Fossils: sprites embedded in the sides + the procedural bone ---
	print("FOSSILS: sprites=%d bones=%d (want >= 6 and >= 1)" % [
		ctl._earth_slice.fossil_count, ctl._earth_slice.bone_count])
	assert(ctl._earth_slice.fossil_count >= 6, "too few fossil sprites")
	assert(ctl._earth_slice.bone_count >= 1, "bone missing")
	var fossil_3d := 0
	for child in ctl._earth_slice.get_children():
		if child is Sprite3D:
			fossil_3d += 1
			var p: Vector3 = child.position
			var radial := maxf(absf(p.x), absf(p.z))
			assert(radial > 20.0, "fossil not on a slab side: %s at %s" % [child.name, p])
	assert(fossil_3d >= 6, "fossil sprites not all placed")

	# --- Sky: beat shader + distinct palette per beat ---
	assert(ctl._sky_mat != null, "sky material missing")
	assert(ctl._sky_mat.shader.resource_path == "res://art/sky_beat.gdshader", "wrong sky shader")
	var tops := {}
	for b in BEATS:
		ctl.current_beat = b[0]
		ctl._apply_beat_sky()
		var c: Color = ctl._sky_mat.get_shader_parameter("top_col")
		tops[b[1]] = c
		print("SKY %s: top_col=%s" % [b[1], c])
	assert(tops.size() == 4, "missing beat palettes")
	var distinct := true
	for key in tops:
		for other in tops:
			if key != other and tops[key].is_equal_approx(tops[other]):
				distinct = false
	assert(distinct, "two beats share the same sky top color")
	ctl.current_beat = 0
	ctl._apply_beat_sky()
	assert(ctl._sky_mat.get_shader_parameter("stars_alpha") == 0.0
			or ctl._sky_mat.get_shader_parameter("stars_alpha") == 0, "raising must be starless")
	assert(ctl._sky_mat.get_shader_parameter("moon_alpha") == 0.0, "raising must be moonless")

	# --- Idle bob: still under touch, moving when hands-off ---
	ctl._last_touch_time = Time.get_ticks_msec() / 1000.0
	await get_tree().create_timer(0.3).timeout
	assert(absf(ctl.position.y) < 0.001, "stage must not bob during/right after touch")
	ctl._last_touch_time = Time.get_ticks_msec() / 1000.0 - 5.0
	var max_bob := 0.0
	for i in 6:
		await get_tree().create_timer(0.25).timeout
		max_bob = maxf(max_bob, absf(ctl.position.y))
	print("BOB: max stage y=%.4f (want > 0.001 when idle)" % max_bob)
	assert(max_bob > 0.001, "idle bob not moving the stage")
	ctl._last_touch_time = Time.get_ticks_msec() / 1000.0
	await get_tree().create_timer(0.3).timeout

	# --- Captures: frame the whole slab (zoom out), then beat skies + views ---
	ctl._camera.size = 55.0
	ctl._pivot.rotation = Vector3(-0.45, 0.8, 0.0)
	ctl._pivot.position = Vector3.ZERO
	await get_tree().create_timer(0.5).timeout
	vp.get_texture().get_image().save_png("/tmp/b23_slice_default.png")
	for b in BEATS:
		ctl.current_beat = b[0]
		ctl._apply_beat_sky()
		await get_tree().create_timer(0.35).timeout
		vp.get_texture().get_image().save_png("/tmp/b23_sky_%s.png" % b[1])
	ctl.current_beat = 0
	ctl._apply_beat_sky()
	ctl._pivot.rotation = Vector3(0.0, PI * 0.52, 0.0)  # eye-level side view
	await get_tree().create_timer(0.35).timeout
	vp.get_texture().get_image().save_png("/tmp/b23_slice_side.png")
	ctl._pivot.rotation = Vector3(-PI / 2.0, 0.0, 0.0)  # top-down
	await get_tree().create_timer(0.35).timeout
	vp.get_texture().get_image().save_png("/tmp/b23_slice_top.png")
	print("EARTH-SLICE CAPTURES DONE")
	get_tree().quit()
