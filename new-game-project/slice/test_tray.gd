extends Node
## test_tray.gd — BUILD 14: capture the mastaba RESTORATION tray to verify
## (a) tray is taller than before, (b) swatches are SMALLER than the tray with
## visible margin all around (block contained inside tray, not filling it),
## (c) ALL level materials are offered in phase 2 (mudbrick included) — the
## phase-2 deletion deadlock fix.

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)
	ctl._load_structure(1)   # mastaba
	ctl._start_beat(1)       # RESTORATION — the phase where mudbrick went missing
	await get_tree().create_timer(1.2).timeout
	print("PALETTE=%s" % str(ctl._palette))
	assert(ctl._palette.has("mudbrick"), "mudbrick must be on tray during phase 2")
	vp.get_texture().get_image().save_png("/tmp/b14_tray.png")
	print("TRAY CAPTURE DONE")
	get_tree().quit()
