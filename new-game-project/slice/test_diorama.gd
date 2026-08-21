extends Node
## test_diorama.gd — verify the mastaba diorama:
##  * clear ring (baseplate limits + 1 tile) contains NO props
##  * diorama covers ~3 phone widths (props/tiles out to r ≈ 23)
##  * the default view's OUTER annulus (outside the build area) carries
##    visible texture — the "busy" gate, measured in pixels.

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)
	ctl._load_structure(1)  # mastaba — builds diorama + raising beat
	await get_tree().create_timer(1.5).timeout

	var lim: Vector3 = ctl._st["limits"]
	var clear := Rect2(-(lim.x + 1.0), -(lim.z + 1.0), 2.0 * (lim.x + 1.0), 2.0 * (lim.z + 1.0))
	var inside := 0
	var count := 0
	var max_r := 0.0
	for node in ctl._diorama.get_children():
		count += 1
		if node is Node3D:
			var p: Vector3 = node.position
			var r: float = Vector2(p.x, p.z).length()
			if r > max_r:
				max_r = r
			# Tiles sit at y≈0.005 (floor texture continues in the ring by
			# design); props sit at y=0 and must stay outside the clear ring.
			if p.y < 0.001 and clear.has_point(Vector2(p.x, p.z)):
				inside += 1
	print("DIORAMA: props+tiles=%d max_r=%.1f (want >= 22) inside_clear_ring=%d (want 0)" % [count, max_r, inside])
	assert(inside == 0, "props inside the clear ring!")
	assert(max_r >= 22.0, "diorama does not cover 3 phone widths")

	# Busy gate: sample the OUTER annulus of the default view (corner strips
	# away from the build grid + ghost cluster). Want > 15% non-sand pixels.
	var img := vp.get_texture().get_image()
	var total := 0
	var nonsand := 0
	for y in range(400, 1250, 3):
		for x in range(0, 1080, 3):
			# Skip the central band where the baseplate/ghosts live (approx:
			# middle 55% of width around x=540, minus nothing else).
			if absf(x - 540.0) < 300.0:
				continue
			var c: Color = img.get_pixel(x, y)
			total += 1
			if c.r < 0.94 or c.g < 0.94:
				nonsand += 1
	var pct := 100.0 * nonsand / maxf(total, 1)
	print("BUSY: outer-annulus non-sand %.1f%% (want > 15%%)" % pct)
	assert(pct > 15.0, "outer annulus looks empty")
	# Left/right balance: count in-frame props by screen half (the BUILD 15
	# complaint was a bare right half — palms all clustered left).
	var left := 0
	var right := 0
	for node in ctl._diorama.get_children():
		var p2: Vector3 = node.position
		if p2.y >= 0.001:
			continue  # tiles only, skip
		var sp2: Vector2 = ctl._camera.unproject_position(p2)
		if sp2.x >= 0 and sp2.x <= 1080 and sp2.y >= 400 and sp2.y <= 1250:
			if sp2.x < 540:
				left += 1
			else:
				right += 1
	print("BALANCE: in-frame props left=%d right=%d" % [left, right])
	vp.get_texture().get_image().save_png("/tmp/b16_diorama_mastaba.png")
	# Side-view capture: the floor slab must read as a thin ground line now
	# (was a 1-unit-tall brown wall in BUILD 15's side view).
	ctl._snap_camera(Vector3(0.0, -PI / 2.0, 0.0))
	await get_tree().create_timer(0.6).timeout
	vp.get_texture().get_image().save_png("/tmp/b16_diorama_side.png")
	print("DIORAMA CAPTURE DONE")
	get_tree().quit()
