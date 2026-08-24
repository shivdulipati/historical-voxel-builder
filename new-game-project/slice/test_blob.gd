extends Node
## test_blob.gd — POC render of the organic blob diorama: swaps the
## rectangular earth slice for the blob builder, gates the mask, and captures
## the default + side views for the look-decision.

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)
	ctl._load_structure(1)  # mastaba
	await get_tree().create_timer(1.2).timeout

	# Swap the rectangular slice for the blob (render POC only).
	ctl._earth_slice.free()
	ctl._earth_slice = preload("res://art/blob_poc.gd").new()
	ctl._earth_slice.name = "EarthSlice"
	ctl.add_child(ctl._earth_slice)
	ctl._earth_slice.build("mastaba")
	await get_tree().create_timer(0.8).timeout

	var mask_n: int = ctl._earth_slice._mask.size()
	var edge_n: int = ctl._earth_slice._edge_cells.size()
	print("BLOB: mask cells=%d edge cells=%d (want > 150 and > 40)" % [mask_n, edge_n])
	assert(mask_n > 150, "blob too small")
	assert(edge_n > 40, "blob outline too smooth")

	ctl._camera.size = 72.0
	ctl._pivot.rotation = Vector3(-0.45, 0.8, 0.0)
	ctl._pivot.position = Vector3.ZERO
	await get_tree().create_timer(0.5).timeout
	vp.get_texture().get_image().save_png("/tmp/b24_blob_default.png")
	ctl._camera.size = 88.0  # blob can reach ~49 wide — fit it with sky margin
	ctl._pivot.rotation = Vector3(-PI / 2.0, 0.0, 0.0)  # top-down mini-map view
	await get_tree().create_timer(0.5).timeout
	vp.get_texture().get_image().save_png("/tmp/b24_blob_top.png")
	ctl._camera.size = 64.0
	ctl._pivot.rotation = Vector3(0.0, 0.0, 0.0)
	await get_tree().create_timer(0.5).timeout
	vp.get_texture().get_image().save_png("/tmp/b24_blob_side.png")
	print("BLOB CAPTURES DONE")
	get_tree().quit()
