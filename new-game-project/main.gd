extends Node3D

enum ToolMode { SINGLE, PAINT, ERASER, ROTATE }
var current_tool: ToolMode = ToolMode.SINGLE

@export var block_scene: PackedScene

var _elapsed: float = 0.0
var global_y_offset: float = 1.5
var global_ghost_height: float = 0.0

var target_puzzle: Dictionary = {}
var current_build: Dictionary = {}

var current_level_index: int = 0
var total_levels: int = 0

const SAVE_PATH = "user://save_game.json"
var pending_saved_build: Dictionary = {}

var current_palette_name: String = "Candy Pop"
var current_color_map: Dictionary = {}

@export var block_icon_texture: Texture2D = preload("res://assets/models/block_icon.png")

const PALETTES: Dictionary = {
	"Soft Rainbow":    {"Red": Color("#FFCFD2"), "Orange": Color("#FDE4CF"), "Yellow": Color("#FBF8CC"), "Green": Color("#B9FBC0"), "Blue": Color("#A3C4F3"), "White": Color("#FFFFFF")},
	"Sunny Beach Day": {"Red": Color("#E76F51"), "Orange": Color("#F4A261"), "Yellow": Color("#E9C46A"), "Green": Color("#2A9D8F"), "Blue": Color("#264653"), "White": Color("#FFFFFF")},
	"Candy Pop":       {"Red": Color("#F15BB5"), "Orange": Color("#9B5DE5"), "Yellow": Color("#FEE440"), "Green": Color("#00F5D4"), "Blue": Color("#00BBF9"), "White": Color("#FFFFFF")},
	"Oceanic Cactus":  {"Red": Color("#FF6B6B"), "Orange": Color("#FF9F1C"), "Yellow": Color("#FFE66D"), "Green": Color("#4ECDC4"), "Blue": Color("#1A535C"), "White": Color("#F7FFF7")}
}

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
@onready var _offset_slider: HSlider  = $HUD/Control/DebugPanel/VBoxContainer/OffsetSlider
@onready var _ghost_slider: HSlider   = $HUD/Control/DebugPanel/VBoxContainer/GhostSlider
@onready var _level_spinbox: SpinBox  = $HUD/Control/DebugPanel/VBoxContainer/HBoxContainer/LevelSpinBox
@onready var _jump_btn: Button        = $HUD/Control/DebugPanel/VBoxContainer/HBoxContainer/JumpBtn

@onready var camera_pivot = $CameraPivot
@onready var reference_world = $HUD/Control/ReferenceContainer/SubViewport/ReferenceWorld
@onready var _win_panel: Control     = $HUD/Control/WinPanel
@onready var _next_level_btn: Button = $HUD/Control/WinPanel/NextLevelBtn

const _BASEPLATE_SCENE: PackedScene = preload("res://assets/models/baseplate_1x1.glb")
var _baseplate_container: Node3D

@onready var btn_single = $HUD/Control/ToolTray/BtnSingle
@onready var btn_paint  = $HUD/Control/ToolTray/BtnPaint
@onready var btn_eraser = $HUD/Control/ToolTray/BtnEraser

@onready var ref_camera_pivot = $HUD/Control/ReferenceContainer/SubViewport/ReferenceWorld/RefCameraPivot

@onready var btn_top    = $HUD/Control/CubeUI/CubeRow/BtnTop
@onready var btn_front  = $HUD/Control/CubeUI/CubeRow/BtnFront
@onready var btn_side   = $HUD/Control/CubeUI/CubeRow/BtnSide

@onready var btn_rotate = $HUD/Control/ToolTray/BtnRotate
@onready var btn_reset  = $HUD/Control/CubeUI/BtnReset

## Stores the initial isometric rotation of camera_pivot, set in _ready().
var default_cam_rot := Vector3.ZERO
## Tracks which CubeUI face button is currently active (null = isometric default).
var active_cube_face: Button = null

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

## Tracks two active touch points for pinch/pan gestures.
var _touch_points: Dictionary = {}   # index -> Vector2 position
var _last_pinch_distance: float = 0.0
var _last_pan_midpoint: Vector2 = Vector2.ZERO


func _apply_kenney_theme() -> void:
	var theme := Theme.new()

	# --- RECTANGLE BUTTONS (RestartBtn, DebugBtn, JumpBtn, NextLevelBtn,
	#     RotateLeftBtn, RotateRightBtn, InspectRotLeftBtn, InspectRotRightBtn) ---
	var rect_tex := load("res://assets/ui/kenney/button_rectangle_depth_gloss.png") as Texture2D
	if rect_tex:
		var rect_normal := StyleBoxTexture.new()
		rect_normal.texture = rect_tex
		rect_normal.texture_margin_left   = 8
		rect_normal.texture_margin_right  = 8
		rect_normal.texture_margin_top    = 8
		rect_normal.texture_margin_bottom = 8
		theme.set_stylebox("normal",  "Button", rect_normal)
		theme.set_stylebox("hover",   "Button", rect_normal)
		theme.set_stylebox("pressed", "Button", rect_normal)
		theme.set_stylebox("focus",   "Button", rect_normal)

	theme.set_color("font_color",         "Button", Color.WHITE)
	theme.set_color("font_hover_color",   "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color",   "Button", Color.WHITE)
	theme.set_font_size("font_size",      "Button", 16)

	# --- PANELS (WinPanel, DebugPanel, InspectWindow background) ---
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color         = Color(0.15, 0.15, 0.25, 0.92)
	panel_style.corner_radius_top_left     = 12
	panel_style.corner_radius_top_right    = 12
	panel_style.corner_radius_bottom_left  = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_left   = 2
	panel_style.border_width_right  = 2
	panel_style.border_width_top    = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.6, 1.0, 0.8)
	theme.set_stylebox("panel", "Panel",          panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# --- LABEL styling (TimerLabel) ---
	theme.set_color("font_color",        "Label", Color.WHITE)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))
	theme.set_constant("shadow_offset_x", "Label", 2)
	theme.set_constant("shadow_offset_y", "Label", 2)
	theme.set_font_size("font_size",     "Label", 20)

	# Apply theme globally
	get_tree().root.theme = theme


func _ready() -> void:
	_restart_btn.pressed.connect(_on_restart_pressed)
	_debug_btn.pressed.connect(_on_debug_pressed)
	_offset_slider.value_changed.connect(_on_offset_slider_changed)
	_ghost_slider.value_changed.connect(_on_ghost_slider_changed)

	$HUD/Control/RotateLeftBtn.pressed.connect(_on_rotate_left_pressed)
	$HUD/Control/RotateRightBtn.pressed.connect(_on_rotate_right_pressed)

	var dropdown: OptionButton = $HUD/Control/DebugPanel/VBoxContainer/PaletteDropdown
	dropdown.clear()
	for p_name in PALETTES.keys():
		dropdown.add_item(p_name)
	dropdown.item_selected.connect(_on_palette_selected)
	_apply_palette()
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

	default_cam_rot = camera_pivot.rotation
	btn_top.pressed.connect(func(): _snap_camera(Vector3(-PI / 2.0, 0.0, 0.0), btn_top))
	btn_front.pressed.connect(func(): _snap_camera(Vector3(0.0, 0.0, 0.0), btn_front))
	btn_side.pressed.connect(func(): _snap_camera(Vector3(0.0, -PI / 2.0, 0.0), btn_side))

	btn_rotate.pressed.connect(func(): set_tool(ToolMode.ROTATE))
	btn_reset.pressed.connect(_reset_camera_look)

	_baseplate_container = Node3D.new()
	_baseplate_container.name = "BaseplateContainer"
	add_child(_baseplate_container)

	_jump_btn.pressed.connect(_on_jump_pressed)

	load_game()
	var _ok := load_level(current_level_index + 1)
	_level_spinbox.min_value = 1
	_level_spinbox.max_value = total_levels
	_level_spinbox.value = current_level_index + 1
	_apply_kenney_theme()


func set_tool(mode: ToolMode) -> void:
	current_tool = mode
	var active_color   := Color(1.0, 0.85, 0.0)   # gold tint for active tool
	var inactive_color := Color.WHITE
	btn_single.modulate = active_color if mode == ToolMode.SINGLE else inactive_color
	btn_paint.modulate  = active_color if mode == ToolMode.PAINT  else inactive_color
	btn_eraser.modulate = active_color if mode == ToolMode.ERASER else inactive_color
	btn_rotate.modulate = active_color if mode == ToolMode.ROTATE else inactive_color


func _input(event: InputEvent) -> void:
	var is_touch_drag = event is InputEventScreenDrag
	var is_mouse_drag = event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if current_tool == ToolMode.ROTATE and (is_touch_drag or is_mouse_drag) and _touch_points.size() < 2:
		var sensitivity: float = 0.005
		camera_pivot.rotation.y -= event.relative.x * sensitivity
		camera_pivot.rotation.x -= event.relative.y * sensitivity
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI / 2.0, 0.0)

		# Magnetic snap to 90-degree increments (~5-degree pull margin)
		var snap_margin := 0.087
		var snap_step := PI / 2.0

		var target_x: float = round(camera_pivot.rotation.x / snap_step) * snap_step
		if abs(camera_pivot.rotation.x - target_x) < snap_margin:
			camera_pivot.rotation.x = target_x

		var target_y: float = round(camera_pivot.rotation.y / snap_step) * snap_step
		if abs(camera_pivot.rotation.y - target_y) < snap_margin:
			camera_pivot.rotation.y = target_y

		if ref_camera_pivot:
			ref_camera_pivot.rotation = camera_pivot.rotation

	# --- Two-finger Pinch Zoom + Pan (ROTATE mode only) ---
	if current_tool == ToolMode.ROTATE:
		if event is InputEventScreenTouch:
			if event.pressed:
				_touch_points[event.index] = event.position
			else:
				_touch_points.erase(event.index)
				_last_pinch_distance = 0.0

		if event is InputEventScreenDrag:
			if _touch_points.has(event.index):
				_touch_points[event.index] = event.position

			if _touch_points.size() == 2:
				var points = _touch_points.values()
				var p0: Vector2 = points[0]
				var p1: Vector2 = points[1]
				var current_distance: float = p0.distance_to(p1)
				var current_midpoint: Vector2 = (p0 + p1) / 2.0

				# --- Pinch Zoom ---
				if _last_pinch_distance > 0.0:
					var delta_dist: float = current_distance - _last_pinch_distance
					var main_camera = camera_pivot.get_node_or_null("Camera3D")
					if main_camera:
						if main_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
							main_camera.size = clamp(main_camera.size - delta_dist * 0.05, 2.0, 40.0)
						else:
							main_camera.position.z = clamp(main_camera.position.z - delta_dist * 0.05, 2.0, 40.0)

				# --- Two-finger Pan (only when fingers are within 120px of each other) ---
				var PAN_PROXIMITY_THRESHOLD: float = 120.0
				if _last_pan_midpoint != Vector2.ZERO and current_distance < PAN_PROXIMITY_THRESHOLD:
					var pan_delta: Vector2 = current_midpoint - _last_pan_midpoint
					var pan_sensitivity: float = 0.01
					camera_pivot.position.x -= pan_delta.x * pan_sensitivity
					camera_pivot.position.z += pan_delta.y * pan_sensitivity

				_last_pinch_distance = current_distance
				_last_pan_midpoint = current_midpoint
			else:
				_last_pinch_distance = 0.0
				_last_pan_midpoint = Vector2.ZERO


func _on_inventory_gui_input(event: InputEvent, item_node: Control) -> void:
	var is_touch = event is InputEventScreenTouch and event.pressed
	var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and OS.get_name() not in ["iOS", "Android"]

	if not (is_touch or is_click):
		return

	if current_tool == ToolMode.ROTATE:
		set_tool(ToolMode.SINGLE)

	item_node.accept_event()

	if block_scene == null:
		push_warning("Main: block_scene is not assigned in the Inspector.")
		return

	var new_block = block_scene.instantiate()
	new_block.current_y_offset = global_y_offset
	new_block.current_ghost_height = global_ghost_height
	add_child(new_block)
	new_block.set_block_color(item_node.modulate, item_node.name)

	var touch_index: int = event.index if is_touch else -1
	new_block._start_drag(touch_index, event.position)


func _process(delta: float) -> void:
	_elapsed += delta
	# Prepends the level number (1-indexed) to the timer format
	_timer_label.text = "LVL %d - %02d:%02d" % [current_level_index + 1, int(_elapsed) / 60, int(_elapsed) % 60]

	if ref_camera_pivot:
		ref_camera_pivot.rotation = camera_pivot.rotation


func _on_restart_pressed() -> void:
	_win_panel.visible = false
	var _ok := load_level(current_level_index + 1)


func _on_debug_pressed() -> void:
	_debug_panel.visible = not _debug_panel.visible
	if _debug_panel.visible:
		_debug_panel.move_to_front()
		_debug_btn.move_to_front()


func _on_jump_pressed() -> void:
	var target: int = int(_level_spinbox.value)
	current_level_index = target - 1
	var _ok := load_level(target)
	_debug_panel.visible = false


func _on_palette_selected(index: int) -> void:
	var dropdown: OptionButton = $HUD/Control/DebugPanel/VBoxContainer/PaletteDropdown
	current_palette_name = dropdown.get_item_text(index)
	_apply_palette()


func _apply_palette() -> void:
	var color_values = PALETTES[current_palette_name].values()
	current_color_map.clear()
	for i in range(color_values.size()):
		current_color_map["Color%d" % i] = color_values[i]

	if not current_build.is_empty() or not target_puzzle.is_empty():
		var _ok := load_level(current_level_index + 1)


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



func _reset_camera_look() -> void:
	var tween = create_tween()
	tween.tween_property(camera_pivot, "rotation", default_cam_rot, 0.3)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)


func _snap_camera(target_rot: Vector3, clicked_btn: Button) -> void:
	if active_cube_face == clicked_btn:
		_reset_camera_look()
		active_cube_face = null
		return

	active_cube_face = clicked_btn
	var tween = create_tween()
	tween.tween_property(camera_pivot, "rotation", target_rot, 0.3)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished
	if ref_camera_pivot:
		ref_camera_pivot.rotation = target_rot


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

	# --- Dynamic Camera Framing & Environment Scale ---
	# Find the largest dimension of the current puzzle (hoisted for scope safety)
	var max_dim = maxf(dim_x, maxf(dim_y, dim_z))

	var main_camera = camera_pivot.get_node_or_null("Camera3D")
	if main_camera:
		# Calculate a comfortable viewing distance/size
		var required_size = max_dim * 1.8 + 4.0

		if main_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			main_camera.size = required_size
		else:
			main_camera.position = Vector3(0.0, 0.0, required_size)

	# Scale up the background environment
	var bg_floor = get_node_or_null("Floor/BackgroundFloor")
	if bg_floor:
		# Ensure the floor is always vastly larger than the puzzle grid
		var floor_scale = maxf(20.0, max_dim * 4.0)
		bg_floor.scale = Vector3(floor_scale, 1.0, floor_scale)

	# --- Clear live blocks and reset state ---
	var tree = get_tree()
	if tree == null:
		return false

	for block in tree.get_nodes_in_group("draggable"):
		block.queue_free()
	current_build.clear()
	_inspect_target_rotation_y = 0.0
	_reset_camera_look()

	# --- Regenerate baseplate tiles for the new grid footprint ---
	for child in _baseplate_container.get_children():
		child.queue_free()
	for bx in range(int(-limit_x), int(limit_x) + 1):
		for bz in range(int(-limit_z), int(limit_z) + 1):
			var tile: Node3D = _BASEPLATE_SCENE.instantiate()
			tile.scale    = Vector3(1.005, 0.1, 1.005)
			tile.position = Vector3(bx, 0.05, bz)
			_baseplate_container.add_child(tile)

	# --- Parse "x,y,z" string keys into Vector3 and populate target_puzzle ---
	target_puzzle.clear()
	var raw_puzzle: Dictionary = level_data.get("target_puzzle", {})
	for coord_key: String in raw_puzzle:
		var parts := coord_key.split(",")
		var grid_vec := Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
		target_puzzle[grid_vec] = raw_puzzle[coord_key]

	_build_reference_model()

	# --- Rebuild inventory swatches for this level's allowed abstract colors ---
	for child in _block_list.get_children():
		child.queue_free()

	var allowed: Array = level_data.get("allowed_blocks", [])
	for abstract_color in allowed:
		if current_color_map.has(abstract_color):
			var tex_rect := TextureRect.new()
			tex_rect.name = abstract_color
			tex_rect.texture = block_icon_texture
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(80, 80)
			tex_rect.modulate = current_color_map[abstract_color]
			tex_rect.gui_input.connect(_on_inventory_gui_input.bind(tex_rect))
			_block_list.add_child(tex_rect)

	if not pending_saved_build.is_empty():
		for pos in pending_saved_build:
			var color_name = pending_saved_build[pos]
			var c := Color.MAGENTA
			if current_color_map.has(color_name):
				c = current_color_map[color_name]

			var new_block = block_scene.instantiate()
			add_child(new_block)
			new_block.set_block_color(c, color_name)
			# Offset the physical position by 0.5 on Y so the block center sits above the floor
			new_block.global_position = Vector3(pos.x, pos.y + 0.5, pos.z)
			new_block.is_placed = true
			new_block.current_grid_position = pos
			new_block.freeze = true
			new_block.gravity_scale = 0.0
			new_block.get_node("CollisionShape3D").disabled = false
			current_build[pos] = color_name
		pending_saved_build.clear()

	save_game()
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

		var block_color := Color.MAGENTA
		if current_color_map.has(color_name):
			block_color = current_color_map[color_name]

		var mat = StandardMaterial3D.new()
		mat.albedo_color = block_color
		mat.roughness = 0.5

		var box := BoxMesh.new()
		box.size = Vector3(1.0, 1.0, 1.0)

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = box
		mesh_instance.material_override = mat
		# Add 0.5 to the Y coordinate so the center of the block sits above the floor plane
		mesh_instance.position = Vector3(grid_pos.x, grid_pos.y + 0.5, grid_pos.z)

		target_container.add_child(mesh_instance)

	# 3. Frame the camera on the bounding box center.
	var bounds_size := Vector3((limit_x * 2.0) + 1.0, limit_y, (limit_z * 2.0) + 1.0)
	var bounds_center := Vector3(0.0, limit_y / 2.0, 0.0)
	var ref_camera = reference_world.get_node_or_null("Camera3D")
	var ref_light = reference_world.get_node_or_null("DirectionalLight3D")

	if ref_camera and ref_camera_pivot:
		# Calculate the true diagonal width of the puzzle base
		var diagonal: float = sqrt((bounds_size.x * bounds_size.x) + (bounds_size.z * bounds_size.z))
		var required_size: float = maxf(diagonal, bounds_size.y * 1.5)

		# Center the pivot exactly on the puzzle
		ref_camera_pivot.position = bounds_center

		# Push the camera straight back on the local Z axis with zero rotation
		ref_camera.position = Vector3(0.0, 0.0, required_size * 2.5)
		ref_camera.rotation = Vector3.ZERO

		if ref_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			ref_camera.size = required_size * 1.2

	if ref_light:
		ref_light.position = Vector3(2.0, 5.0, 3.0)
		ref_light.look_at(Vector3(0.0, 0.0, 0.0))


func save_game() -> void:
	var save_dict := {
		"level_index": current_level_index,
		"build": {}
	}
	# Convert Vector3 keys to strings for JSON serialization
	for pos in current_build:
		var pos_str = "%f,%f,%f" % [pos.x, pos.y, pos.z]
		save_dict["build"][pos_str] = current_build[pos]

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict))
		file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			current_level_index = int(data.get("level_index", 0))
			var raw_build = data.get("build", {})
			pending_saved_build.clear()

			# Convert string keys back to Vector3
			for pos_str in raw_build:
				var parts = pos_str.split(",")
				if parts.size() == 3:
					var vec = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
					pending_saved_build[vec] = raw_build[pos_str]
		file.close()


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
	# Convert physical world Y (e.g., 0.5) to logical grid Y (e.g., 0)
	var logical_pos = Vector3(grid_pos.x, round(grid_pos.y - 0.5), grid_pos.z)

	if current_build.has(logical_pos):
		return

	var new_block = block_scene.instantiate()
	add_child(new_block)
	new_block.set_block_color(color_val, color_name)
	new_block.global_position = grid_pos
	new_block.is_placed = true
	new_block.current_grid_position = logical_pos
	new_block.freeze = true
	new_block.gravity_scale = 0.0
	new_block.get_node("CollisionShape3D").disabled = false

	new_block._squish_on_land()
	Input.vibrate_handheld(50)
	if new_block.has_node("AudioStreamPlayer"):
		new_block.get_node("AudioStreamPlayer").play()

	# Save the logical integer position to the build dictionary
	current_build[logical_pos] = color_name
	check_win_condition()
	save_game()
