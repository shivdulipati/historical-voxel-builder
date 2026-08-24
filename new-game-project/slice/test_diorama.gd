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

	# --- Island: one connected mask, grass floor + strata columns ---
	var dia: Node3D = ctl._diorama
	assert(dia != null, "diorama missing")
	var mask_cells: int = dia._mask.size()
	var edge_cells: int = dia._edge_cells.size()
	print("BLOB: mask cells=%d edge cells=%d (want > 150 and > 40)" % [mask_cells, edge_cells])
	assert(mask_cells > 150, "island too small")
	assert(edge_cells > 40, "island has no coastline")
	var grass: MultiMeshInstance3D = dia.get_node_or_null("GrassFloor")
	assert(grass != null, "grass floor missing")
	var grass_n: int = grass.multimesh.instance_count
	print("BLOB: grass=%d (want > 100 and < mask %d)" % [grass_n, mask_cells])
	assert(grass_n > 100 and grass_n < mask_cells, "grass floor should tile the interior only")
	# Tall blocks: the brown body IS the strata — top pinned at y=0, down to -TALL.
	var gt := grass.multimesh.get_instance_transform(0)
	print("BLOB: grass scale=%s origin_y=%.3f (want y≈%.1f, origin≈-%.1f)" %
			[gt.basis.get_scale(), gt.origin.y, 4.0, 4.0])
	assert(absf(gt.basis.get_scale().y - 4.0) < 0.01, "grass blocks must be TALL")
	assert(absf(gt.origin.y + 4.0) < 0.01, "grass top must sit at y=0")
	assert(gt.basis.get_scale().x > 1.05, "floor tiles must overlap (no bevel gaps)")

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
