extends Node3D

var _elapsed: float = 0.0

@onready var _timer_label: Label   = $HUD/Control/TimerLabel
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

	_debug_panel.visible = false


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
	for node in get_tree().get_nodes_in_group("draggable"):
		if "current_y_offset" in node:
			node.current_y_offset = value


func _on_ghost_slider_changed(value: float) -> void:
	for node in get_tree().get_nodes_in_group("draggable"):
		if "current_ghost_height" in node:
			node.current_ghost_height = value
