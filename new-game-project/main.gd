extends Node3D

enum ToolMode { SINGLE, PAINT, ERASER }
var current_tool: ToolMode = ToolMode.SINGLE

@export var block_scene: PackedScene

var _elapsed: float = 0.0
var global_y_offset: float = 1.5
var global_ghost_height: float = 0.0

var target_puzzle: Dictionary = {}
var current_build: Dictionary = {}

var current_level_index: int = 0
var total_levels: int = 0

## Half-extents of the active grid, derived from levels.json dimensions.
## limit_x = (dim_x - 1) / 2,  limit_z = (dim_z - 1) / 2
var limit_x: float = 1.0
var limit_z: float = 1.0
var limit_y: float = 1.0

@onready var _timer_label: Label   = $HUD/Control/TimerLabel
@onready var _block_list           = $HUD/Control/InventoryTray/ScrollContainer/BlockList
@onready var _restart_btn: Button  = $HUD/Control/RestartButton
@onready var _debug_btn: Button    = $HUD/Control/DebugButton
@onready var _debug_panel: Control = $HUD/Control/DebugPanel
@onready var _offset_slider: HSlider = $HUD/Control/DebugPanel/VBoxContainer/OffsetSlider
@onready var _ghost_slider: HSlider  = $HUD/Control/DebugPanel/VBoxContainer/GhostSlider

@onready var camera_pivot = $CameraPivot
@onready var reference_world = $HUD/Control/ReferenceContainer/SubViewport/ReferenceWorld
@onready var _win_panel: Control     = $HUD/Control/WinPanel
@onready var _next_level_btn: Button = $HUD/Control/WinPanel/NextLevelBtn

@onready var _grid_mesh: MeshInstance3D = $BlueprintTarget

@onready var btn_single = $HUD/Control/ToolTray/BtnSingle
@onready var btn_paint  = $HUD/Control/ToolTray/BtnPaint
@onready var btn_eraser = $HUD/Control/ToolTray/BtnEraser

@onready var ref_container    = $HUD/Control/ReferenceContainer
@onready var inspect_overlay  = $HUD/Control/InspectOverlay
@onready var inspect_close_btn   = $HUD/Control/InspectOverlay/InspectWindow/CloseBtn
@onready var inspect_rot_left    = $HUD/Control/InspectOverlay/InspectWindow/InspectRotLeftBtn
@onready var inspect_rot_right   = $HUD/Control/InspectOverlay/InspectWindow/InspectRotRightBtn
@onready var ref_world = $HUD/Control/ReferenceContainer/SubViewport/ReferenceWorld

## Prevents queuing a new orbit while one is already animating.
var is_orbiting: bool = false

## Accumulated Y rotation for the inspect-view TargetBlocks pivot.
var _inspect_target_rotation_y: float = 0.0
## Prevents queuing a new inspect rotation while one is already animating.
var _inspect_is_rotating: bool = false


func _ready() -> void:
	_restart_btn.pressed.connect(_on_restart_pressed)
	_debug_btn.pressed.connect(_on_debug_pressed)
	_offset_slider.value_changed.connect(_on_offset_slider_changed)
	_ghost_slider.value_changed.connect(_on_ghost_slider_changed)

	$HUD/Control/RotateLeftBtn.pressed.connect(_on_rotate_left_pressed)
	$HUD/Control/RotateRightBtn.pressed.connect(_on_rotate_right_pressed)

	for child in _block_list.get_children():
		child.gui_input.connect(_on_inventory_gui_input.bind(child))

	_debug_panel.visible = false
	_win_panel.visible   = false
	inspect_overlay.visible = false
	_next_level_btn.pressed.connect(_on_next_level_pressed)
	ref_container.gui_input.connect(_on_ref_container_gui_input)
	inspect_close_btn.pressed.connect(func(): inspect_overlay.visible = false)
	inspect_rot_left.pressed.connect(_on_inspect_rot_left)
	inspect_rot_right.pressed.connect(_on_inspect_rot_right)

	btn_single.pressed.connect(func(): set_tool(ToolMode.SINGLE))
	btn_paint.pressed.connect(func(): set_tool(ToolMode.PAINT))
	btn_eraser.pressed.connect(func(): set_tool(ToolMode.ERASER))
	set_tool(ToolMode.SINGLE)

	var _ok := load_level(current_level_index + 1)


func set_tool(mode: ToolMode) -> void:
	current_tool = mode
	btn_single.modulate = Color.GREEN if mode == ToolMode.SINGLE else Color.WHITE
	btn_paint.modulate  = Color.GREEN if mode == ToolMode.PAINT  else Color.WHITE
	btn_eraser.modulate = Color.GREEN if mode == ToolMode.ERASER else Color.WHITE


func _on_inventory_gui_input(event: InputEvent, item_node: Control) -> void:
	var is_touch = event is InputEventScreenTouch and event.pressed
	var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and OS.get_name() not in ["iOS", "Android"]

	if not (is_touch or is_click):
		return

	item_node.accept_event()

	if block_scene == null:
		push_warning("Main: block_scene is not assigned in the Inspector.")
		return

	var new_block = block_scene.instantiate()
	new_block.current_y_offset = global_y_offset
	new_block.current_ghost_height = global_ghost_height
	add_child(new_block)
	if "color" in item_node:
		new_block.set_block_color(item_node.color, item_node.name)

	var touch_index: int = event.index if is_touch else -1
	new_block._start_drag(touch_index, event.position)


func _process(delta: float) -> void:
	_elapsed += delta
	_timer_label.text = "%02d:%02d" % [int(_elapsed) / 60, int(_elapsed) % 60]


func _on_restart_pressed() -> void:
	_win_panel.visible = false
	var _ok := load_level(current_level_index + 1)


func _on_debug_pressed() -> void:
	_debug_panel.visible = not _debug_panel.visible


func _on_offset_slider_changed(value: float) -> void:
	global_y_offset = value
	for node in get_tree().get_nodes_in_group("draggable"):
		if "current_y_offset" in node:
			node.current_y_offset = value


func _on_ghost_slider_changed(value: float) -> void:
	global_ghost_height = value
	for node in get_tree().get_nodes_in_group("draggable"):
		if "current_ghost_height" in node:
			node.current_ghost_height = value


func _on_rotate_left_pressed() -> void:
	if is_orbiting:
		return
	is_orbiting = true
	var tween = create_tween()
	tween.tween_property(camera_pivot, "rotation:y", camera_pivot.rotation.y + (PI / 2.0), 0.3)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	is_orbiting = false


func _on_rotate_right_pressed() -> void:
	if is_orbiting:
		return
	is_orbiting = true
	var tween = create_tween()
	tween.tween_property(camera_pivot, "rotation:y", camera_pivot.rotation.y - (PI / 2.0), 0.3)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	is_orbiting = false


func load_level(target_id: int) -> bool:
	# --- Parse levels.json and locate the requested level entry ---
	var file := FileAccess.open("res://levels.json", FileAccess.READ)
	if file == null:
		push_error("main.gd: cannot open res://levels.json (error %d)" % FileAccess.get_open_error())
		return false

	var json := JSON.new()
	var parse_err: int = json.parse(file.get_as_text())
	file.close()

	if parse_err != OK:
		push_error("main.gd: JSON parse error in levels.json — %s" % json.get_error_message())
		return false

	total_levels = (json.data as Array).size()

	var level_data: Dictionary = {}
	for entry: Dictionary in (json.data as Array):
		if entry.get("level_id", -1) == target_id:
			level_data = entry
			break

	if level_data.is_empty():
		return false

	# --- Derive grid half-extents from the level dimensions ---
	var dim: Dictionary = level_data["dimensions"]
	var dim_x: float = float(dim.get("x", 1))
	var dim_y: float = float(dim.get("y", 1))
	var dim_z: float = float(dim.get("z", 1))

	# maxf ensures boundaries never drop below 0 if the JSON contains an even number or 0.
	limit_x = maxf(0.0, (dim_x - 1.0) / 2.0)
	limit_z = maxf(0.0, (dim_z - 1.0) / 2.0)
	limit_y = dim_y

	# Size the grid as a true 3D volume and lift it so its base sits flush on the floor.
	_grid_mesh.mesh.size = Vector3(dim_x, dim_y, dim_z)
	_grid_mesh.position.y = dim_y / 2.0

	# --- Update grid shader to keep line density proportional to grid size ---
	_grid_mesh.get_active_material(0).set_shader_parameter(
		"line_thickness", 0.06 / dim_x
	)

	# --- Clear live blocks and reset state ---
	for block in get_tree().get_nodes_in_group("draggable"):
		block.queue_free()
	current_build.clear()
	_inspect_target_rotation_y = 0.0

	# --- Parse "x,y,z" string keys into Vector3 and populate target_puzzle ---
	target_puzzle.clear()
	var raw_puzzle: Dictionary = level_data.get("target_puzzle", {})
	for coord_key: String in raw_puzzle:
		var parts := coord_key.split(",")
		var grid_vec := Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
		target_puzzle[grid_vec] = raw_puzzle[coord_key]

	_build_reference_model()

	# --- Show only the block types permitted by this level ---
	var allowed: Array = level_data.get("allowed_blocks", [])
	for child in _block_list.get_children():
		child.visible = child.name in allowed

	return true


func _build_reference_model() -> void:
	# 1. Target ONLY the TargetBlocks folder for cleanup
	var target_container = reference_world.get_node("TargetBlocks")
	if target_container:
		for child in target_container.get_children():
			child.queue_free()
	else:
		push_warning("TargetBlocks node not found inside ReferenceWorld!")
		return

	# 2. Build the solid target blocks.
	for grid_pos: Vector3 in target_puzzle:
		var color_name: String = target_puzzle[grid_pos]

		var mat := StandardMaterial3D.new()
		match color_name:
			"Red":    mat.albedo_color = Color.RED
			"Blue":   mat.albedo_color = Color.BLUE
			"Green":  mat.albedo_color = Color.GREEN
			"Yellow": mat.albedo_color = Color.YELLOW
			"Orange": mat.albedo_color = Color.ORANGE
			"White":  mat.albedo_color = Color.WHITE
			_:        mat.albedo_color = Color.MAGENTA

		var box := BoxMesh.new()
		box.size = Vector3(1.0, 1.0, 1.0)

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = box
		mesh_instance.material_override = mat
		mesh_instance.position = grid_pos

		target_container.add_child(mesh_instance)

	# 3. Holographic bounding box that wraps all target blocks.
	var bounds_size := Vector3((limit_x * 2.0) + 1.0, limit_y, (limit_z * 2.0) + 1.0)
	var bounds_center := Vector3(0.0, limit_y / 2.0, 0.0)

	var holo_mat := StandardMaterial3D.new()
	holo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	holo_mat.albedo_color = Color(0.0, 1.0, 1.0, 0.2)
	holo_mat.emission_enabled = true
	holo_mat.emission = Color(0.0, 1.0, 1.0)

	var holo_box := BoxMesh.new()
	holo_box.size = bounds_size

	var holo_instance := MeshInstance3D.new()
	holo_instance.mesh = holo_box
	holo_instance.material_override = holo_mat
	holo_instance.position = bounds_center

	target_container.add_child(holo_instance)

	# 4. Frame the camera on the bounding box center.
	var ref_camera = reference_world.get_node_or_null("Camera3D")
	var ref_light = reference_world.get_node_or_null("DirectionalLight3D")

	if ref_camera:
		# Calculate the true diagonal width of the puzzle base
		var diagonal: float = sqrt((bounds_size.x * bounds_size.x) + (bounds_size.z * bounds_size.z))

		# The required size must encapsulate the diagonal width, or the total height for tall towers
		var required_size: float = maxf(diagonal, bounds_size.y * 1.5)

		# Move the camera back proportionally and look at the center
		ref_camera.position = bounds_center + Vector3(1.0, 1.2, 1.0).normalized() * (required_size * 2.5)
		ref_camera.look_at(bounds_center)

		# Pad the final size by 20% to leave a comfortable margin around the puzzle edges
		if ref_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			ref_camera.size = required_size * 1.2

	if ref_light:
		ref_light.position = Vector3(2.0, 5.0, 3.0)
		ref_light.look_at(Vector3(0.0, 0.0, 0.0))


func check_win_condition() -> void:
	print("--- WIN CHECK ---")
	print("Target: ", target_puzzle)
	print("Current: ", current_build)

	var is_match: bool = current_build.size() == target_puzzle.size()
	if is_match:
		for key in target_puzzle:
			if not current_build.has(key) or current_build[key] != target_puzzle[key]:
				is_match = false
				break

	if is_match:
		print("🏆 LEVEL COMPLETE! 🏆")
		_win_panel.visible = true
	else:
		print("❌ No match yet.")


func _on_next_level_pressed() -> void:
	_win_panel.visible = false

	var blocks := get_tree().get_nodes_in_group("draggable")
	if not blocks.is_empty():
		var tween := create_tween().set_parallel(true)
		for block in blocks:
			tween.tween_property(block, "scale", Vector3.ZERO, 0.3)\
				.set_trans(Tween.TRANS_BACK)\
				.set_ease(Tween.EASE_IN)
		await tween.finished

	if current_level_index + 1 < total_levels:
		current_level_index += 1
		var _ok := load_level(current_level_index + 1)
	else:
		print("GAME BEATEN!")


func _on_ref_container_gui_input(event: InputEvent) -> void:
	var is_touch = event is InputEventScreenTouch and event.pressed
	var is_click = event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if is_touch or is_click:
		inspect_overlay.visible = true


func _on_inspect_rot_left() -> void:
	if _inspect_is_rotating:
		return
	_inspect_is_rotating = true
	_inspect_target_rotation_y += PI / 2.0
	var pivot = ref_world.get_node_or_null("TargetBlocks")
	if pivot:
		var tween = create_tween()
		tween.tween_property(pivot, "rotation:y", _inspect_target_rotation_y, 0.3)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN_OUT)
		await tween.finished
	_inspect_is_rotating = false


func _on_inspect_rot_right() -> void:
	if _inspect_is_rotating:
		return
	_inspect_is_rotating = true
	_inspect_target_rotation_y -= PI / 2.0
	var pivot = ref_world.get_node_or_null("TargetBlocks")
	if pivot:
		var tween = create_tween()
		tween.tween_property(pivot, "rotation:y", _inspect_target_rotation_y, 0.3)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN_OUT)
		await tween.finished
	_inspect_is_rotating = false


func paint_block_at(grid_pos: Vector3, color_name: String, color_val: Color) -> void:
	if current_build.has(grid_pos):
		return
	var new_block = block_scene.instantiate()
	add_child(new_block)
	new_block.set_block_color(color_val, color_name)
	new_block.global_position = grid_pos
	new_block.is_placed = true
	new_block.current_grid_position = grid_pos
	new_block.freeze = true
	new_block.gravity_scale = 0.0
	new_block.get_node("CollisionShape3D").disabled = false

	new_block._squish_on_land()
	Input.vibrate_handheld(50)
	if new_block.has_node("AudioStreamPlayer"):
		new_block.get_node("AudioStreamPlayer").play()

	current_build[grid_pos] = color_name
	check_win_condition()
