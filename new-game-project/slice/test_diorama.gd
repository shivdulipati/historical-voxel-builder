extends Node
## test_diorama.gd — BUILD 14/15: capture the mastaba diorama (desert stage:
## sand ground + palms + rocks around the baseplate) at the default camera.

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)
	ctl._load_structure(1)  # mastaba — builds diorama + raising beat
	await get_tree().create_timer(1.5).timeout
	vp.get_texture().get_image().save_png("/tmp/b14_diorama_mastaba.png")
	print("DIORAMA CAPTURE DONE")
	get_tree().quit()
