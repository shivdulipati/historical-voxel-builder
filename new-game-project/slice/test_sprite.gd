extends Node
## Micro-test: does a Sprite3D with the fossil setup render at all?
func _ready() -> void:
	var tex := load("res://art/2d_src/ore_gold.png") as Texture2D
	print("TEX: ", tex, " size=", tex.get_width(), "x", tex.get_height())
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.0
	cam.position = Vector3(0, 0, 6)
	cam.current = true
	add_child(cam)
	var spr := Sprite3D.new()
	spr.texture = tex
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	spr.material_override = mat
	spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	spr.pixel_size = 0.7 / 128.0
	add_child(spr)
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/b23_sprite_test.png")
	var hits := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.5 and c.g > 0.3 and c.b < 0.4 and c.a > 0.5:
				hits += 1
	print("SPRITE-TEST: warm-pixel hits=", hits)
	get_tree().quit(0)
