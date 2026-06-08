extends Node3D

@export var block_scene: PackedScene

var _elapsed: float = 0.0
var global_y_offset: float = 1.5
var global_ghost_height: float = 0.0

var target_puzzle: Dictionary = {}
var current_build: Dictionary = {}

var current_level_index: int = 0
var levels: Array[Dictionary] = [
	{ Vector3(0, 0, 0): "Red",   Vector3(0, 1, 0): "Blue" },
	{ Vector3(0, 0, 0): "Green", Vector3(1, 0, 0): "Green", Vector3(0, 1, 0): "Yellow" },
]

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
	load_level()


func _on_inventory_gui_input(event: InputEvent, item_node: Control) -> void:
	var is_touch = event is InputEventScreenTouch and event.pressed
	var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed

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
	var tree = get_tree()
	if tree == null:
		return
	tree.reload_current_scene()


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


func load_level() -> void:
	for block in get_tree().get_nodes_in_group("draggable"):
		block.queue_free()
	current_build.clear()
	_inspect_target_rotation_y = 0.0

	target_puzzle = levels[current_level_index].duplicate()
	_build_reference_model()


func _build_reference_model() -> void:
	# 1. Target ONLY the TargetBlocks folder for cleanup
	var target_container = reference_world.get_node("TargetBlocks")
	if target_container:
		for child in target_container.get_children():
			child.queue_free()
	else:
		push_warning("TargetBlocks node not found inside ReferenceWorld!")
		return

	# 2. Build the solid target blocks and track occupied coords.
	var max_x: float = 0.0
	var max_y: float = 0.0
	var max_z: float = 0.0

	for grid_pos: Vector3 in target_puzzle:
		max_x = maxf(max_x, grid_pos.x)
		max_y = maxf(max_y, grid_pos.y)
		max_z = maxf(max_z, grid_pos.z)

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
	var bounds_size := Vector3(max_x + 1.0, max_y + 1.0, max_z + 1.0)
	var bounds_center := Vector3(
		(max_x + 1.0) / 2.0 - 0.5,
		bounds_size.y / 2.0 - 0.5,
		(max_z + 1.0) / 2.0 - 0.5
	)

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
		var longest_side: float = maxf(bounds_size.x, maxf(bounds_size.y, bounds_size.z))
		ref_camera.position = bounds_center + Vector3(1.0, 1.0, 1.0).normalized() * (longest_side * 2.5)
		ref_camera.look_at(bounds_center)
		if ref_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			ref_camera.size = longest_side * 1.4

	if ref_light:
		ref_light.position = Vector3(2.0, 5.0, 3.0)
		ref_light.look_at(Vector3(0.0, 0.0, 0.0))


func check_win_condition() -> void:
	print("--- WIN CHECK ---")
	print("Target: ", target_puzzle)
	print("Current: ", current_build)
	if current_build.hash() == target_puzzle.hash():
		print("🏆 LEVEL COMPLETE! 🏆")
		_win_panel.visible = true
	else:
		print("❌ No match yet.")


func _on_next_level_pressed() -> void:
	_win_panel.visible = false
	current_level_index += 1
	if current_level_index < levels.size():
		load_level()
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
