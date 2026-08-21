extends Node3D
## test_pickup.gd — BUILD 11: long-press pickup must respect the deletability
## rule (support beneath + nothing above). Also verifies the Great Wall level
## is fully completable with the banner on the tower roof.

const SliceScene = preload("res://slice/mastaba_slice.tscn")

func _ready() -> void:
	var slice := SliceScene.instantiate()
	add_child(slice)
	await get_tree().process_frame

	# --- Pickup gating (Göbekli, stack of 2) ---
	var a = slice.SliceBlock.new()
	slice.add_child(a)
	a.limit_x = slice._st["limits"].x
	a.limit_z = slice._st["limits"].z
	a.limit_y = slice._st["limits"].y
	a.place_at(Vector3i(0, 0, 0), slice._st["colors"]["limestone"], "limestone")
	var b = slice.SliceBlock.new()
	slice.add_child(b)
	b.limit_x = slice._st["limits"].x
	b.limit_z = slice._st["limits"].z
	b.limit_y = slice._st["limits"].y
	b.place_at(Vector3i(0, 1, 0), slice._st["colors"]["limestone"], "limestone")
	await get_tree().physics_frame

	# Long-press the BOTTOM block: must be rejected (block stays placed).
	a._is_pressing = true
	a._drag_touch_index = 0
	a._touch_start_time = (Time.get_ticks_msec() / 1000.0) - 0.5
	await get_tree().physics_frame
	var bottom_blocked: bool = a.is_placed and not a.is_dragging and not a._is_pressing

	# Long-press the TOP block: must be allowed (picks up into a drag).
	b._is_pressing = true
	b._drag_touch_index = 0
	b._touch_start_time = (Time.get_ticks_msec() / 1000.0) - 0.5
	await get_tree().physics_frame
	var top_allowed: bool = not b.is_placed and b.is_dragging

	print("PICKUP-TEST: bottom pickup blocked = ", bottom_blocked, " (want true) ", "PASS" if bottom_blocked else "FAIL")
	print("PICKUP-TEST: top pickup allowed = ", top_allowed, " (want true) ", "PASS" if top_allowed else "FAIL")

	# --- Great Wall (index 6) completability: every target cell reachable ---
	slice._load_structure(6)
	await get_tree().process_frame
	slice._start_beat(slice.Beat.RESTORATION)
	await get_tree().process_frame
	var zenith: Dictionary = slice._st["zenith"]
	print("PICKUP-TEST: wall zenith cells = ", zenith.size(), " (want 9)")
	# Every zenith cell must have support beneath (ground or a placed cell).
	var unsupported := []
	for pos in zenith:
		var below := Vector3i(pos.x, pos.y - 1, pos.z)
		var has_below: bool = slice._st["core"].has(below) or zenith.has(below) or pos.y == 0
		if not has_below:
			unsupported.append(pos)
	print("PICKUP-TEST: unsupported zenith cells = ", unsupported, " (want [])")
	var ok: bool = unsupported.is_empty() and zenith.size() == 9 and bottom_blocked and top_allowed
	print("PICKUP-TEST: ", "ALL PASS" if ok else "FAIL")
	get_tree().quit()
