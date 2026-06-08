extends RigidBody3D

var is_dragging = false
var camera: Camera3D
var drag_plane: Plane

## Shifts the drag target above and away from the thumb so the object stays visible.
## X and Z components are fixed; Y is driven at runtime by current_y_offset.
@export var touch_offset: Vector3 = Vector3(0, 1.5, -0.5)

## Vertical lift above the drag plane. Updated by the OffsetSlider in the debug panel.
var current_y_offset: float = 1.5

## Y-height of the drop indicator ghost. Updated by the GhostSlider in the debug panel.
var current_ghost_height: float = 0.0

## Y position the block center rests at when placed flush on the Y=0 floor.
## For a 1×1×1 block with a centered pivot this is 0.5.
const FLOOR_Y: float = 0.5

var _mesh: MeshInstance3D
var _material: StandardMaterial3D

## Ghost indicator that slides on the floor while the object floats above it.
@onready var _drop_indicator: MeshInstance3D = $DropIndicator

## Index of the touch point currently dragging this object. -1 means mouse.
var _drag_touch_index: int = -1

## Screen position of the active drag finger, kept current via InputEventScreenDrag.
var _drag_touch_pos: Vector2 = Vector2.ZERO

## Accumulated Y-axis rotation target so rapid double-taps queue correctly.
var _target_rotation_y: float = 0.0


func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	add_to_group("draggable")

	_mesh = get_node("MeshInstance3D") as MeshInstance3D
	if _mesh:
		# Duplicate so each instance owns its own material copy.
		_material = _mesh.get_active_material(0).duplicate() as StandardMaterial3D
		_mesh.set_surface_override_material(0, _material)


func _input(event: InputEvent) -> void:
	if not is_dragging:
		return

	var is_touch_release = (
		event is InputEventScreenTouch
		and (not event.pressed or event.is_canceled())
		and event.index == _drag_touch_index
	)
	var is_mouse_release = (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	)

	if is_touch_release or is_mouse_release:
		is_dragging       = false
		_drag_touch_index = -1
		_drop_to_grid()
		return

	# Second finger tap (mobile) or right-click (desktop) — rotate 90 degrees.
	var is_second_finger = (
		event is InputEventScreenTouch
		and event.pressed
		and event.index != _drag_touch_index
	)
	var is_right_click = (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_RIGHT
	)
	if is_second_finger or is_right_click:
		rotate_y(deg_to_rad(90))
		return

	if event is InputEventScreenDrag and event.index == _drag_touch_index:
		_drag_touch_pos = event.position


## Snaps the block to the nearest 1×1×1 world-space grid cell with a short tween.
## If the snapped position falls outside the BlueprintTarget volume, the block is deleted.
func _drop_to_grid() -> void:
	linear_velocity  = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_drop_indicator.visible = false
	_tween_alpha(1.0)

	var snap_x: float = floor(global_position.x) + 0.5
	var snap_z: float = floor(global_position.z) + 0.5
	var snap_y: float = _get_stack_height(snap_x, snap_z)
	var final_snap_pos := Vector3(snap_x, snap_y, snap_z)

	gravity_scale = 0.0
	freeze = true
	$CollisionShape3D.disabled = false

	var blueprints := get_tree().get_nodes_in_group("blueprint")
	if blueprints.is_empty():
		push_warning("DraggableObject: no node in group 'blueprint' found — dropping freely.")
		_tween_to(final_snap_pos)
		return

	var blueprint := blueprints[0]
	var bounds: AABB = blueprint.global_transform * blueprint.mesh.get_aabb()

	if bounds.has_point(final_snap_pos):
		_tween_to(final_snap_pos)
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


func set_block_color(new_color: Color) -> void:
	if _material == null:
		return
	_material.albedo_color = new_color


func _tween_to(target: Vector3) -> void:
	var t = get_tree().create_tween()
	t.tween_property(self, "global_position", target, 0.1)\
	 .set_trans(Tween.TRANS_SINE)\
	 .set_ease(Tween.EASE_OUT)


func _on_input_event(_camera, event, _position, _normal, _shape_idx) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_start_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_drag(-1, event.position)


func _start_drag(touch_index: int, touch_pos: Vector2) -> void:
	_drag_touch_index = touch_index
	_drag_touch_pos   = touch_pos
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
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var t = get_tree().create_tween()
	t.tween_property(_material, "albedo_color:a", target_alpha, 0.15)\
	 .set_trans(Tween.TRANS_SINE)\
	 .set_ease(Tween.EASE_OUT)
	if target_alpha >= 1.0:
		# Restore opaque rendering mode once fully solid so it renders correctly.
		t.tween_callback(func(): _material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED)


func _physics_process(delta: float) -> void:
	if global_position.y < -5.0:
		is_dragging             = false
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
			var hover_snap_x: float = floor(target_pos.x + effective_offset.x) + 0.5
			var hover_snap_z: float = floor(target_pos.z + effective_offset.z) + 0.5
			var hover_y: float = _get_stack_height(hover_snap_x, hover_snap_z)
			var target_ghost_pos := Vector3(hover_snap_x, hover_y, hover_snap_z)
			_drop_indicator.global_position = _drop_indicator.global_position.lerp(target_ghost_pos, delta * 15.0)

			var push_vector = (target_pos + effective_offset - global_position) / delta

			linear_velocity  = push_vector
			angular_velocity = Vector3.ZERO
