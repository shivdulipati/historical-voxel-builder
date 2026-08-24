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

	# --- Transcription: 29 blocks from Test_01.model, marker box respected ---
	var dia: Node3D = ctl._diorama
	var nodes := dia.get_children()
	print("BLOB: total nodes=%d (want 29)" % nodes.size())
	assert(nodes.size() == 29, "must transcribe all 29 blocks from the .model")
	var moving := 0
	var marker_violations := 0
	for c in nodes:
		var n := c as Node3D
		if n == null:
			continue
		if n.name.begins_with("block-moving"):
			moving += 1
		# The 3x4 marker box: only block-moving blocks may sit inside it.
		if absf(n.position.x) <= 1.5 and absf(n.position.z) <= 1.5:
			if not n.name.begins_with("block-moving"):
				marker_violations += 1
	print("BLOB: moving=%d marker-violations=%d (want 12 and 0)" % [moving, marker_violations])
	assert(moving == 12, "the 3x4 marker must be 12 block-moving blocks")
	assert(marker_violations == 0, "a non-marker block sits in the structure/baseplate area")
	var base := dia.get_node("block-grass-overhang-large-tall_00")
	assert(base.scale.is_equal_approx(Vector3(4.5, 1.1, 4.5)), "main base scale wrong")
	assert(absf(base.position.y + 2.2) < 0.01, "main base top must sit at y=0")

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
