extends Node
## test_topview.gd — render the full diorama from straight above (BUILD 38).
## Top-down: +x = screen right, +z = screen down. Elbows must sit at the
## earmark corners (±2.75, ±4.75) with arms along the edges.

var BLOB: Script

func _ready() -> void:
	BLOB = load("res://art/blob_poc.gd")
	var blob := Node3D.new()
	blob.set_script(BLOB)
	add_child(blob)
	# diorama center at origin
	blob.call("build", "diorama_debug")
	await get_tree().create_timer(0.3).timeout

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -30, 0)
	sun.light_energy = 1.2
	add_child(sun)

	var cam := Camera3D.new()
	cam.fov = 35
	add_child(cam)
	cam.make_current()
	cam.position = Vector3(0, 26, 0)
	cam.look_at(Vector3.ZERO, Vector3(0, 0, 1))

	var vp := get_viewport()
	vp.size = Vector2i(1100, 1100)
	await get_tree().create_timer(0.5).timeout
	vp.get_texture().get_image().save_png("/tmp/topview.png")
	print("TOPVIEW DONE")
	get_tree().quit()
