extends Node
## test_diorama_xray.gd — the user's diagnostic: hide the yellow floor mesh
## (and the bottom UI cards) and capture the same default view. If props are
## visible standing on the invisible ground plane, the floor was never hiding
## them — the bottom UI cards were covering the foreground band.

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)
	ctl._load_structure(1)  # mastaba
	await get_tree().create_timer(1.5).timeout

	# Capture 1: NORMAL view (everything visible) — baseline.
	vp.get_texture().get_image().save_png("/tmp/b16_xray_normal.png")

	# Capture 2: floor mesh hidden (collision stays — raycasts unaffected).
	ctl._floor_mesh.visible = false
	ctl._message_card.visible = false
	await get_tree().create_timer(0.4).timeout
	vp.get_texture().get_image().save_png("/tmp/b16_xray_nofloor.png")

	# Capture 3: floor hidden only (cards back) — isolates the card's cover.
	ctl._message_card.visible = true
	await get_tree().create_timer(0.4).timeout
	vp.get_texture().get_image().save_png("/tmp/b16_xray_nofloor_card.png")

	print("XRAY DONE")
	get_tree().quit()
