extends RigidBody3D
## slice_block.gd — Self-contained draggable block for the mastaba slice.
## Port of draggable_object.gd mechanics (drag-plane raycast, stack-height ray,
## freeze-on-place, long-press pickup, second-finger rotate) but SIGNAL-BASED:
## no coupling to a main-scene API. The slice controller owns all game state.
## Also the base class for MULTI-CELL PIECES (T-cap, roof slab): same body,
## N unit cells, atomic place/remove, support-rule validation on drop.

const PIECES = preload("res://slice/pieces.gd")

signal placed(pos: Vector3i, color_name: String)
signal removed(pos: Vector3i)
signal paint_requested(pos: Vector3i, color_name: String)
## Multi-cell pieces emit these instead of placed/removed — one body, N cells.
signal piece_placed(origin: Vector3i, cells: Array, color_name: String)
signal piece_removed(cells: Array)

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
## Armed press from the tray: finger that pressed the swatch, waiting to be
## promoted to a full drag once it moves past DRAG_SLOP (a plain tap keeps
## the hovering brick instead of dropping it).
var _armed_touch_index := -1
var _armed_touch_origin := Vector2.ZERO
const DRAG_SLOP := 14.0

## Multi-cell piece data (empty = single cube).
var piece_cells: Array = []          # local cell offsets from the origin cell
var piece_anchors: Array = []        # local cells that must have support beneath
var piece_min_anchors := 1
## Y-rotation steps (90° each) applied while held; the cells rotate with the body.
var _rotation_steps := 0
## World cells this block occupies after placement (piece path).
var _placed_cells: Array = []
var _cell_meshes: Array = []
var _extra_indicators: Array = []
var _target_rotation_y := 0.0
var _touch_start_time := 0.0
var _is_pressing := false
var current_grid_position := Vector3i.ZERO
var _audio: AudioStreamPlayer
var last_hover_cell := Vector3i(999, 999, 999)


func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	add_to_group("slice_blocks")
	# Everything in the world joins this group so the controller can wipe ALL
	# blocks (built, atlas, rubble, survivors) in one pass on restart / view.
	add_to_group("world_blocks")
	input_ray_pickable = true
	input_event.connect(_on_input_event)

	# --- Build the visual: one unit box per cell (piece = compound body) ---
	var cell_list: Array = piece_cells if not piece_cells.is_empty() else [Vector3i.ZERO]
	for local_pos in cell_list:
		var box := BoxMesh.new()
		box.size = Vector3(SIZE, SIZE, SIZE)
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.position = Vector3(local_pos)
		add_child(mesh)
		_cell_meshes.append(mesh)

		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(SIZE, SIZE, SIZE)
		shape.shape = box_shape
		shape.position = Vector3(local_pos)
		add_child(shape)

	_mesh = _cell_meshes[0]

	_material = ShaderMaterial.new()
	_material.resource_local_to_scene = true
	_material.shader = load("res://block.gdshader")
	for mesh in _cell_meshes:
		mesh.set_surface_override_material(0, _material)
	set_block_color(block_color, block_color_name)

	# --- Drop indicator ghost (flat translucent square on the landing cell) ---
	_drop_indicator = MeshInstance3D.new()
	var ghost_mat := ShaderMaterial.new()
	ghost_mat.resource_local_to_scene = true
	ghost_mat.shader = load("res://block.gdshader")
	# DARK indicator — the light plate and white blocks swallow white; dark
	# reads against both.
	ghost_mat.set_shader_parameter("albedo_color", Color(0.12, 0.09, 0.05, 1.0))
	ghost_mat.set_shader_parameter("alpha", 0.9)
	var ghost_box := BoxMesh.new()
	ghost_box.size = Vector3(1.12, 0.02, 1.12)
	_drop_indicator.mesh = ghost_box
	_drop_indicator.material_override = ghost_mat
	_drop_indicator.visible = false
	add_child(_drop_indicator)

	# One extra landing indicator per cell for multi-cell pieces.
	for i in range(cell_list.size() - 1):
		var ind := MeshInstance3D.new()
		var gm := ShaderMaterial.new()
		gm.resource_local_to_scene = true
		gm.shader = load("res://block.gdshader")
		gm.set_shader_parameter("albedo_color", Color(0.12, 0.09, 0.05, 1.0))
		gm.set_shader_parameter("alpha", 0.9)
		var gb := BoxMesh.new()
		gb.size = Vector3(1.12, 0.02, 1.12)
		ind.mesh = gb
		ind.material_override = gm
		ind.visible = false
		add_child(ind)
		_extra_indicators.append(ind)

	# --- Placement click sound (reuse project's click3.ogg) ---
	_audio = AudioStreamPlayer.new()
	_audio.stream = load("res://click3.ogg")
	add_child(_audio)

	# Single blocks: keep the single cell mesh centered on the body origin.
	# Multi-cell pieces must NOT be recentered — each cell mesh keeps its own
	# local offset or the compound body collapses (a 1x3 T-cap rendered as
	# 1x2 with two cells overlapping at the handle; the third cell's shadow
	# still fell 1x3, exposing the mismatch).
	if piece_cells.is_empty():
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
	_placed_cells = [pos]
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

	# Armed press from the tray: promote to a real drag once the finger moves
	# past the slop; a plain tap (lift without moving) leaves the hovering
	# brick in place for the player to grab later.
	if _armed_touch_index != -1:
		if event is InputEventScreenDrag and event.index == _armed_touch_index:
			if event.position.distance_to(_armed_touch_origin) > DRAG_SLOP:
				_start_drag(_armed_touch_index, event.position)
				return
		elif event is InputEventScreenTouch and not event.pressed and event.index == _armed_touch_index:
			_armed_touch_index = -1
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
		_rotation_steps = (_rotation_steps + 1) % 4
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
	for ind in _extra_indicators:
		ind.visible = false
	_tween_alpha(1.0)

	if not piece_cells.is_empty():
		_drop_piece_to_grid()
		return

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


## Where this block would land right now: origin cell + all world cells,
## honouring the held rotation. Single cubes keep their old stack rule.
func _snapped_cells() -> Dictionary:
	var origin_x := roundi(global_position.x)
	var origin_z := roundi(global_position.z)
	var origin_y := 0
	if piece_cells.is_empty():
		origin_y = roundi(_get_stack_height(origin_x, origin_z) - FLOOR_Y)
	else:
		var best_y := -100000.0
		for a in piece_anchors:
			var local := _rotate_cell(a)
			best_y = maxf(best_y, _get_stack_height(origin_x + local.x, origin_z + local.z) - FLOOR_Y - float(local.y))
		if piece_anchors.is_empty():
			best_y = _get_stack_height(origin_x, origin_z) - FLOOR_Y
		origin_y = roundi(best_y)
	var cells: Array = []
	for c in (piece_cells if not piece_cells.is_empty() else [Vector3i.ZERO]):
		var local := _rotate_cell(c)
		cells.append(Vector3i(origin_x + local.x, origin_y + local.y, origin_z + local.z))
	return {"origin": Vector3i(origin_x, origin_y, origin_z), "cells": cells}


func _rotate_cell(cell: Vector3i) -> Vector3i:
	return PIECES.rotate_cell(cell, _rotation_steps % 4)


## Position the landing indicators (one per piece cell) at each cell's base.
func _update_piece_indicators(cells: Array) -> void:
	for i in range(cells.size()):
		var ind: MeshInstance3D = _drop_indicator if i == 0 else _extra_indicators[i - 1]
		var cell: Vector3i = cells[i]
		ind.global_position = Vector3(cell.x, cell.y - 0.5 + 0.02, cell.z)


## True if any placed block (single or piece, including parked/painted cells)
## occupies the world cell. Point query at the cell CENTER — a vertical ray
## would graze the support block below (its top face IS the cell's bottom)
## and falsely reject. Matches by script so parked painted blocks (removed
## from slice_blocks) still count as occupancy.
func _world_occupied(cell: Vector3i) -> bool:
	var space := get_world_3d().direct_space_state
	var params := PhysicsPointQueryParameters3D.new()
	params.position = Vector3(cell.x, cell.y + FLOOR_Y, cell.z)
	params.exclude = [get_rid()]
	for hit in space.intersect_point(params, 8):
		var collider = hit.collider
		if collider is Node and collider.get_script() == get_script():
			return true
	return false


## Atomic piece placement: validate limits, occupancy and the support rule for
## the WHOLE piece; only then freeze and emit piece_placed once.
func _drop_piece_to_grid() -> void:
	var snapped := _snapped_cells()
	var origin: Vector3i = snapped["origin"]
	var cells: Array = snapped["cells"]

	var ok := true
	var supported := 0
	for a in piece_anchors:
		var local := _rotate_cell(a)
		var cell := Vector3i(origin.x + local.x, origin.y + local.y, origin.z + local.z)
		var stack_top := _get_stack_height(cell.x, cell.z) - FLOOR_Y
		if absf(stack_top - float(cell.y)) < 0.01:
			supported += 1
		elif stack_top > float(cell.y) + 0.4:
			ok = false  # a block pokes up into the anchor cell
			break
	if supported < piece_min_anchors:
		ok = false

	if ok:
		for cell in cells:
			if absf(cell.x) > limit_x + 0.1 or absf(cell.z) > limit_z + 0.1 or cell.y > limit_y or cell.y < 0:
				ok = false
				break
			if _world_occupied(cell):
				ok = false
				break

	if not ok:
		var tween := create_tween()
		tween.tween_method(
			func(a: float): set_block_color(Color(0.9, 0.25, 0.2).lerp(block_color, a), block_color_name),
			0.0, 1.0, 0.35)
		tween.tween_callback(queue_free)
		return

	gravity_scale = 0.0
	freeze = true
	_disable_collision(false)
	_tween_to(Vector3(origin.x, origin.y + FLOOR_Y, origin.z))
	_squish_on_land()
	_audio.play()
	Input.vibrate_handheld(50)
	is_placed = true
	current_grid_position = origin
	_placed_cells = cells.duplicate()
	piece_placed.emit(origin, cells, block_color_name)


## True if this block (single or piece) occupies the given world cell.
func occupies(cell: Vector3i) -> bool:
	if not is_placed:
		return false
	if piece_cells.is_empty():
		return cell == current_grid_position
	return _placed_cells.has(cell)


## Emit the correct removal signal for this block's shape.
func _emit_removed() -> void:
	if not piece_cells.is_empty() and not _placed_cells.is_empty():
		piece_removed.emit(_placed_cells)
	else:
		removed.emit(current_grid_position)


func _start_drag(touch_index: int, touch_pos: Vector2) -> void:
	_armed_touch_index = -1
	_drag_touch_index = touch_index
	_drag_touch_pos = touch_pos
	last_hover_cell = Vector3i(999, 999, 999)
	is_dragging = true
	gravity_scale = 0.0
	freeze = false
	_disable_collision(true)
	_tween_alpha(0.4)
	_drop_indicator.visible = true
	for ind in _extra_indicators:
		ind.visible = true
	_stop_hover_pulse()
	# Camera-facing drag plane through the build center: works from top, front,
	# and side views alike.
	var cam_forward: Vector3 = -camera.global_transform.basis.z
	drag_plane = Plane(cam_forward.normalized(), drag_plane_center)


## Arms the block to a finger that pressed the tray swatch: the finger's drag
## (past slop) becomes this block's drag — direct drag-from-tray restored.
func _arm_drag(touch_index: int, touch_pos: Vector2) -> void:
	_armed_touch_index = touch_index
	_armed_touch_origin = touch_pos


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


## True while this block owns a finger: dragging, long-press pending, or
## armed from a tray press. The camera's free-orbit yields while true.
func is_grabbing() -> bool:
	return is_dragging or _is_pressing or _armed_touch_index != -1


func _physics_process(delta: float) -> void:
	# Long-press threshold: promote a held press into a full drag — but only
	# for deletable blocks. Picking a block up is the same as deleting it, so
	# the same rule applies: nothing above, support beneath. Otherwise a
	# support block could be dragged out from under a stack, leaving the
	# blocks above floating forever (the real Great Wall banner bug).
	if is_placed and _is_pressing:
		var elapsed := (Time.get_ticks_msec() / 1000.0) - _touch_start_time
		if elapsed > 0.3:
			if _is_deletable():
				_emit_removed()
				is_placed = false
				_is_pressing = false
				_start_drag(_drag_touch_index, _drag_touch_pos)
			else:
				Input.vibrate_handheld(80)
				_flash_rejected()
				_is_pressing = false
				_drag_touch_index = -1

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
		for ind in _extra_indicators:
			ind.visible = false
		_tween_alpha(1.0)

	if is_dragging and camera:
		var screen_pos := _drag_touch_pos if _drag_touch_index != -1 else get_viewport().get_mouse_position()
		var ray_origin := camera.project_ray_origin(screen_pos)
		var ray_normal := camera.project_ray_normal(screen_pos)
		var target_pos: Variant = drag_plane.intersects_ray(ray_origin, ray_normal)
		if target_pos != null:
			var effective_offset := Vector3(touch_offset.x, current_y_offset, touch_offset.z)
			if not piece_cells.is_empty():
				# Multi-cell piece: one landing indicator per cell, no paint.
				var snapped := _snapped_cells()
				_update_piece_indicators(snapped["cells"])
				var push_vector: Vector3 = (target_pos + effective_offset - global_position) / delta
				linear_velocity = push_vector
				angular_velocity = Vector3.ZERO
				return
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

	# ERASER tool: a press on a placed block removes it — only if it is
	# deletable (supported below, nothing stacked above it).
	var is_press: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if is_placed and is_press and current_tool == 2:
		if _is_deletable():
			_emit_removed()
			queue_free()
		else:
			Input.vibrate_handheld(80)
			_flash_rejected()
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
			_emit_removed()
			is_placed = false
		_start_drag(-1, event.position)


func _disable_collision(disabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = disabled


## Eraser rule: a block may be removed only when nothing sits on top of it
## AND it has support beneath (the ground counts). Pieces are atomic — every
## cell must be clear above, and at least one cell needs support (a T-cap's
## overhanging sides hang by design, supported by its stem anchor).
func _is_deletable() -> bool:
	if not is_placed:
		return false
	var cells: Array = _placed_cells if not piece_cells.is_empty() and not _placed_cells.is_empty() else [current_grid_position]
	var supported := false
	for cell in cells:
		if _world_occupied(Vector3i(cell.x, cell.y + 1, cell.z)):
			return false
		if cell.y == 0 or _world_occupied(Vector3i(cell.x, cell.y - 1, cell.z)):
			supported = true
	return supported


var _highlight_tween: Tween

## Erase-mode affordance: pulsing gold outline while the block is deletable.
func set_deletable_highlight(on: bool) -> void:
	if _material == null:
		return
	if on:
		_material.set_shader_parameter("outline", 1.0)
		if _highlight_tween == null or not _highlight_tween.is_valid():
			_highlight_tween = create_tween().set_loops()
			_highlight_tween.tween_method(_apply_outline_pulse, 0.025, 0.07, 0.6)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_highlight_tween.tween_method(_apply_outline_pulse, 0.07, 0.025, 0.6)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		if _highlight_tween and _highlight_tween.is_valid():
			_highlight_tween.kill()
		_highlight_tween = null
		_material.set_shader_parameter("outline", 0.0)
		_material.set_shader_parameter("outline_width", 0.035)


func _apply_outline_pulse(v: float) -> void:
	if _material:
		_material.set_shader_parameter("outline_width", v)


## Short red flash when the eraser rejects a block (not deletable).
func _flash_rejected() -> void:
	if _material == null:
		return
	var tween := create_tween()
	tween.tween_method(
		func(a: float): _material.set_shader_parameter("albedo_color", Color(0.9, 0.25, 0.2).lerp(block_color, a)),
		0.0, 1.0, 0.3)


func _tween_to(target: Vector3) -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, 0.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _squish_on_land() -> void:
	if _cell_meshes.is_empty():
		return
	for mesh in _cell_meshes:
		var tween := create_tween()
		tween.tween_interval(0.1)
		tween.tween_property(mesh, "scale", Vector3(1.3, 0.5, 1.3), 0.05)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(mesh, "scale", Vector3(0.8, 1.25, 0.8), 0.1)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(mesh, "scale", Vector3.ONE, 0.15)\
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
