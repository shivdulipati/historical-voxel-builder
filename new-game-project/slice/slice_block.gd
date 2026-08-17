extends RigidBody3D
## slice_block.gd — Self-contained draggable block for the mastaba slice.
## Port of draggable_object.gd mechanics (drag-plane raycast, stack-height ray,
## freeze-on-place, long-press pickup, second-finger rotate) but SIGNAL-BASED:
## no coupling to a main-scene API. The slice controller owns all game state.

signal placed(pos: Vector3i, color_name: String)
signal removed(pos: Vector3i)
signal paint_requested(pos: Vector3i, color_name: String)

## Tool modes mirror the reloc-proto tools: 0 SINGLE, 1 PAINT, 2 ERASER, 3 ROTATE.
var current_tool := 0

## Block size half-extent (unit voxel).
const SIZE := 1.0
const FLOOR_Y := 0.5

## Grid limits set by the controller (mastaba_data LIMIT_*).
var limit_x := 3.0
var limit_z := 1.0
var limit_y := 3.0

## Touch offset so the block floats above/behind the thumb while dragging.
var touch_offset := Vector3(0.0, 5.5, -2.5)
var current_y_offset := 5.5

## Center the drag plane passes through. Camera-facing plane = drag works from
## any view (top/front/side), not just top-down.
var drag_plane_center := Vector3(0.0, 1.5, 0.0)

var is_dragging := false
var is_placed := false
var camera: Camera3D
var drag_plane := Plane(Vector3.UP, Vector3.ZERO)
var block_color := Color.WHITE
var block_color_name := ""

var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _drop_indicator: MeshInstance3D
var _drag_touch_index := -1
var _drag_touch_pos := Vector2.ZERO
var _target_rotation_y := 0.0
var _touch_start_time := 0.0
var _is_pressing := false
var current_grid_position := Vector3i.ZERO
var _audio: AudioStreamPlayer
var last_hover_cell := Vector3i(999, 999, 999)


func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	add_to_group("slice_blocks")
	input_ray_pickable = true
	input_event.connect(_on_input_event)

	# --- Build the visual: unit box with the project block shader ---
	var box := BoxMesh.new()
	box.size = Vector3(SIZE, SIZE, SIZE)

	_mesh = MeshInstance3D.new()
	_mesh.mesh = box
	add_child(_mesh)

	_material = ShaderMaterial.new()
	_material.resource_local_to_scene = true
	_material.shader = load("res://block.gdshader")
	_mesh.set_surface_override_material(0, _material)
	set_block_color(block_color, block_color_name)

	# --- Collision ---
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(SIZE, SIZE, SIZE)
	shape.shape = box_shape
	add_child(shape)

	# --- Drop indicator ghost (flat translucent square on the landing cell) ---
	_drop_indicator = MeshInstance3D.new()
	var ghost_mat := ShaderMaterial.new()
	ghost_mat.resource_local_to_scene = true
	ghost_mat.shader = load("res://block.gdshader")
	ghost_mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
	ghost_mat.set_shader_parameter("alpha", 0.7)
	var ghost_box := BoxMesh.new()
	ghost_box.size = Vector3(1.06, 0.02, 1.06)
	_drop_indicator.mesh = ghost_box
	_drop_indicator.material_override = ghost_mat
	_drop_indicator.visible = false
	add_child(_drop_indicator)

	# --- Placement click sound (reuse project's click3.ogg) ---
	_audio = AudioStreamPlayer.new()
	_audio.stream = load("res://click3.ogg")
	add_child(_audio)

	# Give the shader a subtle snap-to-grid look.
	_mesh.position = Vector3.ZERO


func set_block_color(color: Color, color_name: String = "") -> void:
	block_color = color
	block_color_name = color_name
	if _material:
		_material.set_shader_parameter("albedo_color", color)


## Instantly park the block on a grid cell (used by controller for ghosts/restore).
func place_at(pos: Vector3i, color: Color, color_name: String) -> void:
	set_block_color(color, color_name)
	global_position = Vector3(pos.x, pos.y + FLOOR_Y, pos.z)
	is_placed = true
	current_grid_position = pos
	freeze = true
	gravity_scale = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if not is_inside_tree():
		return
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = false


func _input(event: InputEvent) -> void:
	# ROTATE tool: the camera owns all gestures; blocks stand by.
	if current_tool == 3:
		return

	# While waiting for a long-press on a placed block, watch only for the
	# matching finger lifting early — that cancels the pick-up attempt.
	if is_placed and _is_pressing:
		if event is InputEventScreenTouch and not event.pressed and event.index == _drag_touch_index:
			_is_pressing = false
			_drag_touch_index = -1
		return

	if not is_dragging:
		return

	# --- Release detection (primary finger lifted or mouse released) ---
	var is_touch_release: bool = (
		event is InputEventScreenTouch
		and (not event.pressed or event.is_canceled())
		and event.index == _drag_touch_index
	)
	var is_mouse_release: bool = (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	)
	if is_touch_release or is_mouse_release:
		is_dragging = false
		_drag_touch_index = -1
		_drop_to_grid()
		return

	# --- Rotation: second finger tap (mobile) OR right-click (desktop) ---
	var is_second_finger: bool = (
		event is InputEventScreenTouch
		and event.pressed
		and event.index != _drag_touch_index
	)
	var is_right_click: bool = (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_RIGHT
	)
	if is_second_finger or is_right_click:
		_target_rotation_y += PI / 2.0
		var tween := create_tween()
		tween.tween_property(self, "rotation:y", _target_rotation_y, 0.08)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return

	# --- Track the active drag finger's screen position ---
	if event is InputEventScreenDrag and event.index == _drag_touch_index:
		_drag_touch_pos = event.position


func _drop_to_grid() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_drop_indicator.visible = false
	_tween_alpha(1.0)

	var snap_x := roundi(global_position.x)
	var snap_z := roundi(global_position.z)
	var snap_y := _get_stack_height(snap_x, snap_z)
	var final_snap_pos := Vector3(snap_x, snap_y, snap_z)

	gravity_scale = 0.0
	freeze = true
	_disable_collision(false)

	# +0.1 tolerance prevents float error rejecting valid center-snaps.
	if absf(snap_x) <= limit_x + 0.1 and absf(snap_z) <= limit_z + 0.1 and snap_y <= limit_y:
		_tween_to(final_snap_pos)
		_squish_on_land()
		_audio.play()
		Input.vibrate_handheld(50)
		is_placed = true
		current_grid_position = Vector3i(snap_x, roundi(snap_y - FLOOR_Y), snap_z)
		placed.emit(current_grid_position, block_color_name)
	else:
		queue_free()


## Casts a ray straight down at (snap_x, snap_z) and returns the Y center the
## new block should occupy. Excludes self so the held block is never the hit.
func _get_stack_height(snap_x: int, snap_z: int) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(snap_x, 100.0, snap_z),
		Vector3(snap_x, -1.0, snap_z)
	)
	query.exclude = [get_rid()]
	var result := space.intersect_ray(query)
	if result:
		return result.position.y + 0.5
	return FLOOR_Y


func _start_drag(touch_index: int, touch_pos: Vector2) -> void:
	_drag_touch_index = touch_index
	_drag_touch_pos = touch_pos
	last_hover_cell = Vector3i(999, 999, 999)
	is_dragging = true
	gravity_scale = 0.0
	freeze = false
	_disable_collision(true)
	_tween_alpha(0.4)
	_drop_indicator.visible = true
	_stop_hover_pulse()
	# Camera-facing drag plane through the build center: works from top, front,
	# and side views alike.
	var cam_forward: Vector3 = -camera.global_transform.basis.z
	drag_plane = Plane(cam_forward.normalized(), drag_plane_center)


## Hover pulse: floating brick signals "drag me into position" (tapped from tray).
var _hover_tween: Tween

func start_hover_pulse() -> void:
	_stop_hover_pulse()
	var base_scale := scale
	_hover_tween = create_tween().set_loops()
	_hover_tween.set_parallel(true)
	_hover_tween.tween_property(self, "scale", base_scale * 1.12, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hover_tween.tween_property(self, "global_position:y", global_position.y + 0.2, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hover_tween.chain().tween_property(self, "scale", base_scale, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hover_tween.tween_property(self, "global_position:y", global_position.y, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_hover_pulse() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = null
	scale = Vector3.ONE


func _physics_process(delta: float) -> void:
	# Long-press threshold: promote a held press into a full drag.
	if is_placed and _is_pressing:
		var elapsed := (Time.get_ticks_msec() / 1000.0) - _touch_start_time
		if elapsed > 0.3:
			removed.emit(current_grid_position)
			is_placed = false
			_is_pressing = false
			_start_drag(_drag_touch_index, _drag_touch_pos)

	if global_position.y < -5.0:
		is_dragging = false
		is_placed = false
		_is_pressing = false
		gravity_scale = 1.0
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		global_position = Vector3(0, 2, 0)
		rotation = Vector3.ZERO
		_target_rotation_y = 0.0
		_drag_touch_index = -1
		_drop_indicator.visible = false
		_tween_alpha(1.0)

	if is_dragging and camera:
		var screen_pos := _drag_touch_pos if _drag_touch_index != -1 else get_viewport().get_mouse_position()
		var ray_origin := camera.project_ray_origin(screen_pos)
		var ray_normal := camera.project_ray_normal(screen_pos)
		var target_pos: Variant = drag_plane.intersects_ray(ray_origin, ray_normal)
		if target_pos != null:
			var effective_offset := Vector3(touch_offset.x, current_y_offset, touch_offset.z)
			var hover_snap_x := roundi(target_pos.x + effective_offset.x)
			var hover_snap_z := roundi(target_pos.z + effective_offset.z)
			var hover_y := _get_stack_height(hover_snap_x, hover_snap_z)
			var target_ghost_pos := Vector3(hover_snap_x, hover_y, hover_snap_z)
			# Drop indicator sits at the BASE of the landing cell (ground of that
			# cell), not its center — reads as "this block will rest here".
			var indicator_y := hover_y - 0.5 + 0.02
			var target_indicator_pos := Vector3(hover_snap_x, indicator_y, hover_snap_z)
			_drop_indicator.global_position = _drop_indicator.global_position.lerp(target_indicator_pos, delta * 15.0)

			# PAINT tool: emit a request for every newly-hovered cell.
			var hover_cell := Vector3i(hover_snap_x, roundi(hover_y - FLOOR_Y), hover_snap_z)
			if current_tool == 1 and hover_cell != last_hover_cell:
				last_hover_cell = hover_cell
				paint_requested.emit(hover_cell, block_color_name)

			var push_vector: Vector3 = (target_pos + effective_offset - global_position) / delta
			linear_velocity = push_vector
			angular_velocity = Vector3.ZERO


func _on_input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if current_tool == 3: # ROTATE — camera owns gestures
		return

	# ERASER tool: a press on a placed block removes it immediately.
	var is_press: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if is_placed and is_press and current_tool == 2:
		removed.emit(current_grid_position)
		queue_free()
		return

	if event is InputEventScreenTouch and event.pressed:
		if is_placed:
			# Arm the long-press timer instead of dragging immediately.
			_is_pressing = true
			_touch_start_time = Time.get_ticks_msec() / 1000.0
			_drag_touch_index = event.index
			_drag_touch_pos = event.position
		else:
			_start_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and OS.get_name() not in ["iOS", "Android"]:
		# Mouse always picks up immediately (desktop testing convenience).
		if is_placed:
			removed.emit(current_grid_position)
			is_placed = false
		_start_drag(-1, event.position)


func _disable_collision(disabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = disabled


func _tween_to(target: Vector3) -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, 0.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _squish_on_land() -> void:
	if _mesh == null:
		return
	var tween := create_tween()
	tween.tween_interval(0.1)
	tween.tween_property(_mesh, "scale", Vector3(1.3, 0.5, 1.3), 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_mesh, "scale", Vector3(0.8, 1.25, 0.8), 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_mesh, "scale", Vector3.ONE, 0.15)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _tween_alpha(target_alpha: float) -> void:
	if _material == null:
		return
	var current_alpha := 1.0
	var val = _material.get_shader_parameter("alpha")
	if val != null:
		current_alpha = float(val)
	var tween := create_tween()
	tween.tween_method(
		func(a: float): _material.set_shader_parameter("alpha", a),
		current_alpha,
		target_alpha,
		0.15
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Decay animation: sink the block into the ground and fade it out.
func decay_sink(delay: float, duration: float = 1.2) -> void:
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(self, "global_position:y", -1.5, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(
		func(a: float): _material.set_shader_parameter("alpha", a),
		1.0,
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
