extends CanvasLayer

## Elapsed seconds since the scene started.
var _elapsed: float = 0.0

@onready var timer_label: Label       = $TimerLabel
@onready var restart_button: Button   = $RestartButton
@onready var debug_button: Button     = $DebugButton
@onready var debug_panel: Control     = $DebugPanel
@onready var offset_slider: HSlider   = $DebugPanel/OffsetSlider


func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	debug_button.pressed.connect(_on_debug_pressed)
	offset_slider.value_changed.connect(_on_offset_slider_changed)

	# Keep the debug panel hidden on launch.
	debug_panel.visible = false


func _process(delta: float) -> void:
	_elapsed += delta
	timer_label.text = _format_time(_elapsed)


func _format_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%02d:%02d" % [mins, secs]


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_debug_pressed() -> void:
	debug_panel.visible = not debug_panel.visible


func _on_offset_slider_changed(value: float) -> void:
	for node in get_tree().get_nodes_in_group("draggable"):
		if node.has_method("set") and "current_y_offset" in node:
			node.current_y_offset = value
