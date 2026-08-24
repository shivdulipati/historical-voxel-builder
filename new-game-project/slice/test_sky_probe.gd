extends Node
## test_sky_probe.gd — skybox verification probe (BUILD 34):
##  1. renders the NIGHT skybox with the camera at max user pitch (0 rad)
##     facing the moon's azimuth (+150.8 deg, yaw +2.086) and captures it —
##     the moon must appear in the upper sky;
##  2. captures the default view for a whole-scene look.
## Orientation was settled by the labeled-texture probe (2026-08-24):
## flip_v=1 is the standard equirect mapping (texture top row at zenith).

func _ready() -> void:
	var ctl := preload("res://slice/mastaba_slice.gd").new()
	add_child(ctl)
	var vp := get_viewport()
	vp.size = Vector2i(1080, 1920)
	ctl._load_structure(1)
	ctl.current_beat = 3  # EXCAVATION — night skybox
	ctl._apply_beat_sky()
	await get_tree().create_timer(1.2).timeout

	ctl._hud_root.visible = false
	ctl._pivot.position = Vector3.ZERO
	# Camera forward at yaw t = (-sin t, -cos t); moon azimuth +150.8 deg.
	ctl._pivot.rotation = Vector3(0.0, 2.086, 0.0)
	await get_tree().create_timer(0.6).timeout
	vp.get_texture().get_image().save_png("/tmp/sky_night_fixed.png")

	ctl._pivot.rotation = Vector3(-0.45, 0.8, 0.0)
	await get_tree().create_timer(0.5).timeout
	vp.get_texture().get_image().save_png("/tmp/sky_night_default.png")
	print("SKY PROBE CAPTURES DONE")
	get_tree().quit()
