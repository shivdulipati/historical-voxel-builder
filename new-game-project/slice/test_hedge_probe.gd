extends Node
## test_hedge_probe.gd — render ONE hedge-corner block from top/side to see
## its actual shape and orientation (BUILD 38).

func _ready() -> void:
	for model in ["hedge-corner", "stairs_half_corner", "debris_stone", "block-snow-large"]:
		var ps := load("res://art/platformer/%s.glb" % model) as PackedScene
		var inst := ps.instantiate()
		add_child(inst)
		inst.position = Vector3.ZERO
		# camera
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 40.0
		add_child(cam)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, -30, 0)
		sun.light_energy = 1.2
		add_child(sun)
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.4, 0.45, 0.55)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.6, 0.6, 0.65)
		env.ambient_light_energy = 0.8
		var we := WorldEnvironment.new()
		we.environment = env
		add_child(we)
		var vp := get_viewport()
		vp.size = Vector2i(900, 900)
		# axis markers: red cube at +x, blue cube at +z (world)
		var mx := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.25, 0.25, 0.25)
		mx.mesh = m
		mx.position = Vector3(0.9, 0.5, 0)
		mx.material_override = _color_mat(Color(1, 0, 0))
		add_child(mx)
		var mz := MeshInstance3D.new()
		mz.mesh = m
		mz.position = Vector3(0, 0.5, 0.9)
		mz.material_override = _color_mat(Color(0, 0, 1))
		add_child(mz)
		# top view
		cam.position = Vector3(0, 3.0, 0)
		cam.look_at(Vector3.ZERO, Vector3(0, 0, -1))
		await get_tree().create_timer(0.35).timeout
		vp.get_texture().get_image().save_png("/tmp/top_%s.png" % model)
		mx.free()
		mz.free()
		inst.free()
		cam.free()
		sun.free()
		we.free()
	print("HEDGE PROBE DONE")
	get_tree().quit()

func _color_mat(c: Color) -> Material:
	var sm := StandardMaterial3D.new()
	sm.albedo_color = c
	return sm
