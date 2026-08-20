extends Node3D
## test_debug.gd — BUILD 9: render-verifies the debug level-jump panel
## (large controls, no clipping) plus the Debug button position.

const SliceScene = preload("res://slice/mastaba_slice.tscn")

func _ready() -> void:
	var slice := SliceScene.instantiate()
	add_child(slice)
	await get_tree().process_frame
	slice._epilogue_card.visible = false
	slice._skip_btn.visible = false
	slice._debug_panel.visible = true
	await get_tree().create_timer(0.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/slice_b9_debug.png")
	print("DEBUG-TEST: captured /tmp/slice_b9_debug.png")
	get_tree().quit()
