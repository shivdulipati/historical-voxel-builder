extends Node3D

@export var block_scene: PackedScene

var _elapsed: float = 0.0
var global_y_offset: float = 1.5
var global_ghost_height: float = 0.0

@onready var _timer_label: Label   = $HUD/Control/TimerLabel
@onready var _block_list           = $HUD/Control/InventoryTray/ScrollContainer/BlockList
@onready var _restart_btn: Button  = $HUD/Control/RestartButton
@onready var _debug_btn: Button    = $HUD/Control/DebugButton
@onready var _debug_panel: Control = $HUD/Control/DebugPanel
@onready var _offset_slider: HSlider = $HUD/Control/DebugPanel/VBoxContainer/OffsetSlider
@onready var _ghost_slider: HSlider  = $HUD/Control/DebugPanel/VBoxContainer/GhostSlider


func _ready() -> void:
	_restart_btn.pressed.connect(_on_restart_pressed)
	_debug_btn.pressed.connect(_on_debug_pressed)
	_offset_slider.value_changed.connect(_on_offset_slider_changed)
	_ghost_slider.value_changed.connect(_on_ghost_slider_changed)

	for child in _block_list.get_children():
		child.gui_input.connect(_on_inventory_gui_input.bind(child))

	_debug_panel.visible = false


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
		new_block.set_block_color(item_node.color)

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
