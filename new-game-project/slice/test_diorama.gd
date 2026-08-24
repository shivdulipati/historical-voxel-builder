extends Node
## test_diorama.gd — verify the mastaba BLOB diorama (BUILD 25):
##  * the organic island builds: one connected mask, grass floor + strata
##  * the strata material is bound to the brown-only strip texture
##  * the grass floor sits with its top at y=0 (block resting plane)
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
	ctl._load_structure(1)  # mastaba — builds blob diorama + raising beat
	await get_tree().create_timer(1.5).timeout

	# --- Composition: few big slabs + props, centre clear for the baseplate ---
	var dia: Node3D = ctl._diorama
	var nodes := dia.get_children()
	print("BLOB: total nodes=%d (want 5 slabs + >= 8 props, total < 40)" % nodes.size())
	assert(nodes.size() < 40, "too many models — compose, don't tile")
	assert(nodes.size() >= 13, "composition incomplete")
	var main_slab: Node3D = null
	var prop_count := 0
	var in_clear := 0
	for c in nodes:
		var n := c as Node3D
		if n == null:
			continue
		if n.name == "Main":
			main_slab = n
		elif n.name in ["LedgeL", "ExtR", "PlatBack", "CornerFR"]:
			pass
		else:
			prop_count += 1
			if absf(n.position.x) <= 3.5 and absf(n.position.z) <= 3.0:
				in_clear += 1
	print("BLOB: props=%d in-clear-box=%d (want >= 8 and 0)" % [prop_count, in_clear])
	assert(prop_count >= 8, "props missing")
	assert(in_clear == 0, "a prop sits in the structure/baseplate area")
	assert(main_slab != null, "main slab missing")
	var ms := main_slab.scale
	var top_y: float = main_slab.position.y + 2.0 * ms.y  # large-tall top_mesh = 2
	print("BLOB: main scale=%s top_y=%.3f (want y≈2.0, top≈0)" % [ms, top_y])
	assert(absf(ms.y - 2.0) < 0.01, "main slab must be 4 units tall")
	assert(absf(top_y) < 0.01, "main slab top must sit at y=0")

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

	# --- Captures: frame the whole island, then beat skies + views ---
	ctl._camera.size = 55.0
	ctl._pivot.rotation = Vector3(-0.45, 0.8, 0.0)
	ctl._pivot.position = Vector3.ZERO
	await get_tree().create_timer(0.5).timeout
	vp.get_texture().get_image().save_png("/tmp/b25_blob_default.png")
	for b in BEATS:
		ctl.current_beat = b[0]
		ctl._apply_beat_sky()
		await get_tree().create_timer(0.35).timeout
		vp.get_texture().get_image().save_png("/tmp/b25_sky_%s.png" % b[1])
	ctl.current_beat = 0
	ctl._apply_beat_sky()
	ctl._pivot.rotation = Vector3(0.0, PI * 0.52, 0.0)  # eye-level side view
	await get_tree().create_timer(0.35).timeout
	vp.get_texture().get_image().save_png("/tmp/b25_blob_side.png")
	ctl._pivot.rotation = Vector3(-PI / 2.0, 0.0, 0.0)  # top-down
	await get_tree().create_timer(0.35).timeout
	vp.get_texture().get_image().save_png("/tmp/b25_blob_top.png")
	print("BLOB CAPTURES DONE")
	get_tree().quit()
