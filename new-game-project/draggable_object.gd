extends RigidBody3D

var is_dragging = false
var camera: Camera3D
var drag_plane: Plane

## Shifts the drag target above and away from the thumb so the object stays visible.
## X and Z components are fixed; Y is driven at runtime by current_y_offset.
@export var touch_offset: Vector3 = Vector3(0, 4.5, -1.5)

## Vertical lift above the drag plane. Updated by the OffsetSlider in the debug panel.
var current_y_offset: float = 4.5

## Y-height of the drop indicator ghost. Updated by the GhostSlider in the debug panel.
var current_ghost_height: float = 0.0

## Y position the block center rests at when placed flush on the Y=0 floor.
## For a 1×1×1 block with a centered pivot this is 0.5.
const FLOOR_Y: float = 0.5

var _mesh: MeshInstance3D
var _material: ShaderMaterial

## Ghost indicator that slides on the floor while the object floats above it.
@onready var _drop_indicator: MeshInstance3D = $DropIndicator

## Index of the touch point currently dragging this object. -1 means mouse.
var _drag_touch_index: int = -1

## Screen position of the active drag finger, kept current via InputEventScreenDrag.
var _drag_touch_pos: Vector2 = Vector2.ZERO

## Accumulated Y-axis rotation target so rapid double-taps queue correctly.
var _target_rotation_y: float = 0.0

## True once the block has been snapped to the grid after a drop.
var is_placed: bool = false

## Wall-clock time (seconds) when the current press on a placed block began.
var touch_start_time: float = 0.0

## True while a finger is held on a placed block and we are waiting for the long-press threshold.
var is_pressing: bool = false

## Grid coordinate (integer-valued Vector3) where this block is currently placed.
var current_grid_position: Vector3 = Vector3.ZERO

## Tracks the last snapped XZ cell the ghost occupied; used for trail painting.
var last_hover_pos: Vector3 = Vector3(999, 999, 999)

## Color identifier used for win-condition matching against the target puzzle.
var block_color_name: String = ""
var block_color: Color = Color.WHITE


func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	add_to_group("draggable")

	_mesh = get_node("MeshInstance3D") as MeshInstance3D
	if _mesh:
		_material = ShaderMaterial.new()
		_material.shader = load("res://block.gdshader")
		_mesh.set_surface_override_material(0, _material)


func _input(event: InputEvent) -> void:
	var main_scene = get_tree().current_scene
	if main_scene.current_tool == 3: # 3 == ToolMode.ROTATE
		return

	# While waiting for a long-press on a placed block, watch only for the
	# matching finger lifting early — that cancels the pick-up attempt.
	if is_placed and is_pressing:
		if event is InputEventScreenTouch and not event.pressed and event.index == _drag_touch_index:
			is_pressing       = false
			_drag_touch_index = -1
		return

	# All logic below only applies while this block is being dragged.
	if not is_dragging:
		return

	# --- Release detection (primary finger lifted or mouse button released) ---
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
		is_dragging       = false
		_drag_touch_index = -1
		_drop_to_grid()
		return

	# --- Rotation: a second finger tapping anywhere (mobile) OR right-click (desktop) ---
	# On a physical iPhone screen, any InputEventScreenTouch whose index differs
	# from the finger already owning the drag is guaranteed to be a separate finger.
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
		var tween = create_tween()
		tween.tween_property(self, "rotation:y", rotation.y + (PI / 2.0), 0.08)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
		return

	# --- Track the active drag finger's screen position for physics projection ---
	if event is InputEventScreenDrag and event.index == _drag_touch_index:
		_drag_touch_pos = event.position


## Snaps the block to the nearest 1×1×1 world-space grid cell with a short tween.
## If the snapped position falls outside the active grid limits, the block is deleted.
func _drop_to_grid() -> void:
	linear_velocity  = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_drop_indicator.visible = false

	_tween_alpha(1.0)

	var snap_x: float = round(global_position.x)
	var snap_z: float = round(global_position.z)
	var snap_y: float = _get_stack_height(snap_x, snap_z)
	var final_snap_pos := Vector3(snap_x, snap_y, snap_z)

	gravity_scale = 0.0
	freeze = true
	$CollisionShape3D.disabled = false

	# We add +0.1 to the X/Z limits to prevent floating-point errors from rejecting valid center-snaps
	var main_scene = get_tree().current_scene
	if abs(snap_x) <= (main_scene.limit_x + 0.1) and abs(snap_z) <= (main_scene.limit_z + 0.1) and snap_y <= main_scene.limit_y:
		_tween_to(final_snap_pos)
		_squish_on_land()
		$AudioStreamPlayer.play()
		Input.vibrate_handheld(50)
		is_placed = true
		current_grid_position = Vector3(snap_x, round(snap_y - FLOOR_Y), snap_z)
		main_scene.current_build[current_grid_position] = block_color_name
		print("Block Dropped -> Color: ", block_color_name, " | Saved Pos: ", current_grid_position)
		main_scene.check_win_condition()
	else:
		queue_free()


## Casts a ray straight down at (snap_x, snap_z) and returns the Y center the
## new block should occupy. Excludes self so the held block is never the hit target.
func _get_stack_height(snap_x: float, snap_z: float) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(snap_x, 100.0, snap_z),
		Vector3(snap_x, -1.0,  snap_z)
	)
	query.exclude = [get_rid()]
	var result := space.intersect_ray(query)
	if result:
		return result.position.y + 0.5
	return FLOOR_Y


func set_block_color(new_color: Color, color_name: String = "") -> void:
	if _material == null:
		return
	_material.set_shader_parameter("albedo_color", new_color)
	block_color = new_color
	if color_name != "":
		block_color_name = color_name


func _tween_to(target: Vector3) -> void:
	var t = get_tree().create_tween()
	t.tween_property(self, "global_position", target, 0.1)\
	 .set_trans(Tween.TRANS_SINE)\
	 .set_ease(Tween.EASE_OUT)


## Plays a squish-and-bounce on the mesh scale timed to start when the block lands.
## The interval matches _tween_to's duration so both tweens are naturally in sync.
func _squish_on_land() -> void:
	var drop_tween = create_tween()
	drop_tween.tween_interval(0.1)
	drop_tween.tween_property($MeshInstance3D, "scale", Vector3(1.3, 0.5, 1.3), 0.05)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	drop_tween.tween_property($MeshInstance3D, "scale", Vector3(0.8, 1.25, 0.8), 0.1)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)
	drop_tween.tween_property($MeshInstance3D, "scale", Vector3.ONE, 0.15)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)



func _on_input_event(_camera, event, _position, _normal, _shape_idx) -> void:
	var main_scene = get_tree().current_scene
	if main_scene.current_tool == 3: # 3 == ToolMode.ROTATE
		return

	# --- Eraser tool: delete this block on touch/click ---
	var is_press: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if is_placed and is_press and get_tree().current_scene.current_tool == 2:
		var main_scene_erase = get_tree().current_scene
		main_scene_erase.current_build.erase(current_grid_position)
		main_scene_erase.check_win_condition()
		Input.vibrate_handheld(100)
		queue_free()
		return

	if event is InputEventScreenTouch and event.pressed:
		if is_placed:
			# Block is resting on the grid — arm the long-press timer instead of
			# dragging immediately. _physics_process will promote this to a drag
			# once the finger has been held for long enough.
			is_pressing       = true
			touch_start_time  = Time.get_ticks_msec() / 1000.0
			_drag_touch_index = event.index
			_drag_touch_pos   = event.position
		else:
			_start_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and OS.get_name() not in ["iOS", "Android"]:
		# Mouse always picks up immediately (desktop testing convenience).
		if is_placed:
			var main_scene_mouse = get_tree().current_scene
			main_scene_mouse.current_build.erase(current_grid_position)
			is_placed = false
		_start_drag(-1, event.position)


func _start_drag(touch_index: int, touch_pos: Vector2) -> void:
	_drag_touch_index = touch_index
	_drag_touch_pos   = touch_pos
	last_hover_pos    = Vector3(999, 999, 999)
	is_dragging       = true
	gravity_scale     = 0.0
	freeze            = false
	$CollisionShape3D.disabled = true
	_tween_alpha(0.4)
	_drop_indicator.visible = true

	drag_plane = Plane(Vector3.UP, Vector3.ZERO)


func _rotate_90() -> void:
	_target_rotation_y += PI / 2.0
	var t = get_tree().create_tween()
	t.tween_property(self, "rotation:y", _target_rotation_y, 0.15)\
	 .set_trans(Tween.TRANS_QUAD)\
	 .set_ease(Tween.EASE_OUT)


func _tween_alpha(target_alpha: float) -> void:
	if _material == null:
		return

	var current_alpha: float = 1.0
	var val = _material.get_shader_parameter("alpha")
	if val != null:
		current_alpha = float(val)

	var t = get_tree().create_tween()
	t.tween_method(
		func(a: float): _material.set_shader_parameter("alpha", a),
		current_alpha,
		target_alpha,
		0.15
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	# Long-press threshold: promote the held press into a full drag.
	if is_placed and is_pressing:
		var elapsed: float = (Time.get_ticks_msec() / 1000.0) - touch_start_time
		if elapsed > 0.3:
			var main_scene_lp = get_tree().current_scene
			main_scene_lp.current_build.erase(current_grid_position)
			is_placed  = false
			is_pressing = false
			_start_drag(_drag_touch_index, _drag_touch_pos)

	if global_position.y < -5.0:
		is_dragging             = false
		is_placed               = false
		is_pressing             = false
		gravity_scale           = 1.0
		linear_velocity         = Vector3.ZERO
		angular_velocity        = Vector3.ZERO
		global_position         = Vector3(0, 2, 0)
		rotation                = Vector3.ZERO
		_target_rotation_y      = 0.0
		_drag_touch_index       = -1
		_drop_indicator.visible = false
		_tween_alpha(1.0)

	if is_dragging and camera:
		# Use the tracked touch position for touch input; fall back to mouse.
		var screen_pos = _drag_touch_pos if _drag_touch_index != -1 else get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(screen_pos)
		var ray_normal = camera.project_ray_normal(screen_pos)

		var target_pos = drag_plane.intersects_ray(ray_origin, ray_normal)

		if target_pos != null:
			var effective_offset = Vector3(touch_offset.x, current_y_offset, touch_offset.z)

			# Ghost predicts the snapped landing position, flush on top of any existing stack.
			var hover_snap_x: float = round(target_pos.x + effective_offset.x)
			var hover_snap_z: float = round(target_pos.z + effective_offset.z)
			var hover_y: float = _get_stack_height(hover_snap_x, hover_snap_z)
			var target_ghost_pos := Vector3(hover_snap_x, hover_y, hover_snap_z)
			_drop_indicator.global_position = _drop_indicator.global_position.lerp(target_ghost_pos, delta * 15.0)

			var current_xz := Vector2(hover_snap_x, hover_snap_z)
			var last_xz    := Vector2(last_hover_pos.x, last_hover_pos.z)

			if get_tree().current_scene.current_tool == 1: # PAINT
				if current_xz != last_xz:
					if last_hover_pos.x != 999: # Skip the very first initial pickup frame
						var main_scene = get_tree().current_scene
						if abs(last_hover_pos.x) <= (main_scene.limit_x + 0.1) and abs(last_hover_pos.z) <= (main_scene.limit_z + 0.1) and last_hover_pos.y <= main_scene.limit_y:
							main_scene.paint_block_at(last_hover_pos, block_color_name, block_color)
					last_hover_pos = target_ghost_pos

			var push_vector = (target_pos + effective_offset - global_position) / delta

			linear_velocity  = push_vector
			angular_velocity = Vector3.ZERO
