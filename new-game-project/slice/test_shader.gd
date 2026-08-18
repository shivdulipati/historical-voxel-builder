extends Node
## test_shader.gd — minimal shader isolation: one ghost.gdshader box and one
## block.gdshader box (both fill=RED, alpha=0.3) over the sand floor + baseplate
## tile. Pixel-analyzed to verify transparency actually renders.

func _ready() -> void:
	var vp := get_viewport()
	vp.size = Vector2i(400, 400)

	# Floor (sand)
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(20, 1, 20)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.85, 0.75, 0.55)
	floor_mesh.mesh = floor_box
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(0, -0.5, 0)
	add_child(floor_mesh)

	# One baseplate tile with the grid shader
	var tile := MeshInstance3D.new()
	var tile_box := BoxMesh.new()
	tile_box.size = Vector3(1.0, 0.05, 1.0)
	var tile_mat := ShaderMaterial.new()
	tile_mat.resource_local_to_scene = true
	tile_mat.shader = load("res://baseplate.gdshader")
	tile.mesh = tile_box
	tile.material_override = tile_mat
	tile.position = Vector3(-2, 0.025, 0)
	add_child(tile)

	# Ghost-shader box: red, alpha 0.3
	var ghost := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(1.0, 1.0, 1.0)
	var gm := ShaderMaterial.new()
	gm.resource_local_to_scene = true
	gm.shader = load("res://ghost.gdshader")
	gm.set_shader_parameter("fill_color", Color(1.0, 0.0, 0.0))
	gm.set_shader_parameter("alpha", 0.3)
	ghost.mesh = gb
	ghost.material_override = gm
	ghost.position = Vector3(0, 0.5, 0)
	add_child(ghost)

	# Block-shader box: red, alpha 0.3
	var block := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.0, 1.0, 1.0)
	var bm := ShaderMaterial.new()
	bm.resource_local_to_scene = true
	bm.shader = load("res://block.gdshader")
	bm.set_shader_parameter("albedo_color", Color(1.0, 0.0, 0.0))
	bm.set_shader_parameter("alpha", 0.3)
	block.mesh = bb
	block.material_override = bm
	block.position = Vector3(3, 0.5, 0)
	add_child(block)

	# Camera straight down
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 12.0
	cam.position = Vector3(0, 10, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	add_child(cam)

	# Sun + ambient (the slice's lighting setup)
	var sun := DirectionalLight3D.new()
	sun.position = Vector3(6, 10, 4)
	add_child(sun)
	sun.look_at(Vector3.ZERO)
	sun.light_color = Color("#FFF2D0")
	sun.light_energy = 1.4
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#8FC1E8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#FFF2D0")
	environment.ambient_light_energy = 0.6
	env.environment = environment
	add_child(env)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img := vp.get_texture().get_image()
	img.save_png("/tmp/b7_shader_test.png")
	print("IMG_SIZE=", img.get_size())
	# Full-width row dump at y=200: floor | tile | ghost | block layout.
	var row := ""
	for x in range(0, 400, 20):
		var c: Color = img.get_pixel(x, 200)
		row += "x%d(%.2f,%.2f,%.2f) " % [x, c.r, c.g, c.b]
	print("ROW200: ", row)
	print("SHADER TEST SAVED")
	get_tree().quit()
