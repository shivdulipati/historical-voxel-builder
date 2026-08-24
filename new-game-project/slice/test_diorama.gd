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

	# --- Sky: texture + beat tint + distinct palette per beat ---
	assert(ctl._sky_mat != null, "sky material missing")
	assert(ctl._sky_mat.shader.resource_path == "res://art/sky_beat.gdshader", "wrong sky shader")
	assert(ctl._sky_mat.get_shader_parameter("sky_tex") != null, "skybox texture not bound")
	assert(ctl._camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "camera must be perspective")
	assert(absf(ctl._camera.fov - 60.0) < 0.1, "camera fov should be 60")
	var tints := {}
	var skyboxes := {}
	for b in BEATS:
		ctl.current_beat = b[0]
		ctl._apply_beat_sky()
		var c: Color = ctl._sky_mat.get_shader_parameter("tint")
		tints[b[1]] = c
		var tex: Texture2D = ctl._sky_mat.get_shader_parameter("sky_tex")
		skyboxes[b[1]] = tex.resource_path if tex != null else ""
		print("SKY %s: tint=%s tex=%s" % [b[1], c, skyboxes[b[1]]])
	assert(tints.size() == 4, "missing beat palettes")
	var distinct := true
	for key in tints:
		for other in tints:
			if key != other and tints[key].is_equal_approx(tints[other]):
				distinct = false
	assert(distinct, "two beats share the same sky tint")
	# Day maps to noon, night maps to excavation.
	assert(skyboxes["restoration"].ends_with("sky_day.png"), "noon must use the day skybox")
	assert(skyboxes["excavation"].ends_with("sky_night.png"), "night must use the night skybox")
	assert(skyboxes["raising"].ends_with("sky_morning.png"), "dawn must use the morning skybox")
	# BUILD 34: the sky must be standard-equirect oriented (not inverted) and
	# zoomed so the night moon lands inside the reachable sky band. Assert the
	# SHADER's declared defaults via RenderingServer (ShaderMaterial
	# get_shader_parameter returns Nil until the param is set).
	var flip_def: float = RenderingServer.shader_get_parameter_default(ctl._sky_mat.shader.get_rid(), "flip_v")
	var zoom_def: float = RenderingServer.shader_get_parameter_default(ctl._sky_mat.shader.get_rid(), "v_zoom")
	assert(absf(flip_def - 1.0) < 0.01, "sky mapping must be standard equirect (flip_v=1)")
	assert(absf(zoom_def - 1.3) < 0.01, "sky vertical zoom should be 1.3")

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
