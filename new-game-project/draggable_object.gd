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

## True once the block has been snapped to the grid after a drop.
var is_placed: bool = false

## Wall-clock time (seconds) when the current press on a placed block began.
var touch_start_time: float = 0.0

## True while a finger is held on a placed block and we are waiting for the long-press threshold.
var is_pressing: bool = false

## Grid coordinate (integer-valued Vector3) where this block is currently placed.
var current_grid_position: Vector3 = Vector3.ZERO

## Color identifier used for win-condition matching against the target puzzle.
var block_color_name: String = ""


func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	add_to_group("draggable")

	_mesh = get_node("MeshInstance3D") as MeshInstance3D
	if _mesh:
		# Duplicate so each instance owns its own material copy.
		_material = _mesh.get_active_material(0).duplicate() as StandardMaterial3D
		_mesh.set_surface_override_material(0, _material)


func _input(event: InputEvent) -> void:
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
## If released inside the TrashZone the block spins into a black hole and vanishes.
## If the snapped position falls outside the BlueprintTarget volume, the block is deleted.
func _drop_to_grid() -> void:
	linear_velocity  = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_drop_indicator.visible = false

	var trash_zone    = _get_drag_ui()[0]
	var inventory_tray = _get_drag_ui()[1]

	# --- Trash zone check ---
	if trash_zone and trash_zone.is_visible_in_tree() and trash_zone.get_global_rect().has_point(_drag_touch_pos):
		var main_scene_trash = get_tree().current_scene
		main_scene_trash.current_build.erase(current_grid_position)
		freeze = true
		$CollisionShape3D.disabled = true
		var tween = create_tween().set_parallel(true)
		tween.tween_property(self, "scale", Vector3.ZERO, 0.25)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_IN)
		tween.tween_property(self, "rotation:y", rotation.y + (PI * 4.0), 0.25)
		await tween.finished
		trash_zone.visible = false
		if inventory_tray: inventory_tray.visible = true
		queue_free()
		return

	# Not trashed — restore UI and continue with normal grid placement.
	if trash_zone:      trash_zone.visible     = false
	if inventory_tray:  inventory_tray.visible  = true

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
		_squish_on_land()
		$AudioStreamPlayer.play()
		is_placed = true
		current_grid_position = final_snap_pos - Vector3(0.5, 0.5, 0.5)
		var main_scene_fb = get_tree().current_scene
		main_scene_fb.current_build[current_grid_position] = block_color_name
		print("Block Dropped -> Color: ", block_color_name, " | Saved Pos: ", current_grid_position)
		main_scene_fb.check_win_condition()
		return

	var blueprint := blueprints[0]
	var bounds: AABB = blueprint.global_transform * blueprint.mesh.get_aabb()

	if bounds.has_point(final_snap_pos):
		_tween_to(final_snap_pos)
		_squish_on_land()
		$AudioStreamPlayer.play()
		is_placed = true
		current_grid_position = final_snap_pos - Vector3(0.5, 0.5, 0.5)
		var main_scene = get_tree().current_scene
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
	_material.albedo_color = new_color
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
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Mouse always picks up immediately (desktop testing convenience).
		if is_placed:
			var main_scene_mouse = get_tree().current_scene
			main_scene_mouse.current_build.erase(current_grid_position)
			is_placed = false
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

	var trash_zone    = _get_drag_ui()[0]
	var inventory_tray = _get_drag_ui()[1]
	if trash_zone:     trash_zone.visible     = true
	if inventory_tray: inventory_tray.visible = false

	drag_plane = Plane(Vector3.UP, Vector3.ZERO)


## Returns [trash_zone, inventory_tray] looked up by group — null if not found.
func _get_drag_ui() -> Array:
	var trash_zones    := get_tree().get_nodes_in_group("trash_zone")
	var inventory_trays := get_tree().get_nodes_in_group("inventory_tray")
	return [
		trash_zones[0]    if trash_zones.size()    > 0 else null,
		inventory_trays[0] if inventory_trays.size() > 0 else null,
	]



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
		var _ui := _get_drag_ui()
		if _ui[0]: (_ui[0] as Node).set("visible", false)
		if _ui[1]: (_ui[1] as Node).set("visible", true)
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
