extends Node3D
## mastaba_slice.gd — Core-loop playtest slice: the four-beat biography arc
## (Raising → Restoration → Decay → Excavation) across 9 historical structures.
## Structure-agnostic: loads from structures.gd by index. Next ▸ advances the
## chronological arc. Multi-cell pieces from pieces.gd. BUILD 6.

const SliceBlock = preload("res://slice/slice_block.gd")
const STRUCTS = preload("res://slice/structures.gd")
const PIECES = preload("res://slice/pieces.gd")
const DIORAMA = preload("res://art/blob_poc.gd")

## Build number shown in HUD + reflected in the export preset version.
const BUILD_NO := 44

enum Beat { RAISING, RESTORATION, DECAY, EXCAVATION }
enum Scaffold { GHOST, GHOST_PARTIAL, PLAN_ONLY }
enum Tool { SINGLE, PAINT, ERASER, ROTATE }

const BEAT_TITLE := {
	Beat.RAISING: "1 · THE RAISING",
	Beat.RESTORATION: "2 · THE RESTORATION",
	Beat.DECAY: "3 · THE FALL",
	Beat.EXCAVATION: "4 · THE EXCAVATION",
}

## iPhone notch safe-area: all top UI starts below this (design px, portrait 1080x1920).
const SAFE_TOP := 150.0
## Bottom tray sits clear of the home indicator / app-switcher gesture zone.
const TRAY_BOTTOM := -70.0
const TRAY_TOP := -340.0

var current_beat: Beat = Beat.RAISING
var scaffold_mode: Scaffold = Scaffold.GHOST
var current_tool: Tool = Tool.SINGLE

## Current structure data (from STRUCTS.structures()).
var _st: Dictionary = {}
var _structure_index := 0
## Atlas entries unlock only after the arc completes (excavation finished).
var _arc_completed := false

## Target for the current build beat: {Vector3i: color_name}
var build_target: Dictionary = {}
## Correctly completed cells: {Vector3i: color_name}
var completed_cells: Dictionary = {}
## Dust mounds waiting to be cleared (excavation beat).
var dust_mounds: Dictionary = {}

var _palette: Array[String] = []
var _current_swatch := ""
var _is_orchestrating := false   # beat transition in flight (input locked)
var _dust_total := 0
var _dust_cleared := 0
var _base_cam_dist := 24.0   # default orbit distance (perspective camera)
var _cam_dist := 24.0        # live distance — zoom = dolly along the view axis
const CAM_DIST_MIN := 8.0
const CAM_DIST_MAX := 64.0

# --- Camera ---
var _pivot: Node3D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _touch_points := {}
var _last_pinch_distance := 0.0
var _last_pan_midpoint := Vector2.ZERO
## Camera gesture latch: 0 = none, 1 = one-finger orbit, 2 = two-finger
## pan/zoom. Latched on press/release so a gesture never changes kind midway
## (two fingers down can NEVER rotate the camera).
var _gesture := 0
## Px of one-finger drag accumulated before orbit engages — a small slop so a
## second finger landing right after the first can still claim the gesture as
## a pan instead of an accidental rotation.
var _orbit_slop_accum := 0.0
const ORBIT_SLOP := 10.0
## Rotation captured when the first finger pressed; restored the moment a
## second finger lands (undoes any orbit that fired while it was landing).
var _rot_latch := Vector3.ZERO
## Touch indices that pressed inside the bottom tray: their drags must NEVER
## orbit the camera (a finger aiming for a swatch may land on tray margin).
var _tray_locked_touches := {}
var _tray: PanelContainer
var _default_cam_rot := Vector3(-0.45, 0.8, 0.0)
var _is_orbiting := false

# --- HUD ---
var _hud: CanvasLayer
var _top_label: Label
var _beat_label: Label
var _build_label: Label
var _progress_bar: ProgressBar
var _swatch_box: HBoxContainer
var _tool_buttons: Array[Button] = []
var _scaffold_buttons: Array[Button] = []
var _message_card: PanelContainer
var _message_label: Label
var _epilogue_card: PanelContainer
var _epilogue_label: RichTextLabel
var _blueprint_sheet: Control
var _atlas_card: PanelContainer
var _skip_btn: Button
var _atlas_btn: Button
var _debug_panel: Control
var _level_input: LineEdit

var _baseplate: Node3D
var _diorama: Node3D
var _sky_mat: ShaderMaterial
## Seconds since the last touch (any press/release/drag) — drives the idle
## bob: the floating earth slice sways gently when the player is hands-off.
var _last_touch_time := 0.0
const BOB_AMPLITUDE := 0.09
const BOB_PERIOD := 3.5
## View-center pan clamp: keeps the camera (24 units behind the pivot) from
## ever entering the 44-wide earth slab's volume.
const PAN_CLAMP := 18.0
var _hud_root: Control
var _debug_mode := false
var _escape_layer: CanvasLayer
## Desktop editor-driver controls (BUILD 40): mouse orbit/zoom/pan + hover
## inspection of diorama entries — lets the user judge/tweak visuals directly
## in Godot on the Mac instead of round-tripping builds.
var _mouse_orbit := false
var _mouse_pan := false
var _hover_label: Label

## JSON save path: structure index, beat, completed cells, dust state, camera.
const SAVE_PATH := "user://slice_save.json"
var _saved_data: Dictionary = {}
## True once _ready has finished; beat-start saves are gated on this so the
## boot path (which loads the file first) can never overwrite it early.
var _booted := false

## Saved atlas states for clickable entries: {label: {Vector3i: color_name}}
var _atlas_states: Dictionary = {}


func _ready() -> void:
	_last_touch_time = Time.get_ticks_msec() / 1000.0
	_build_world()
	_build_hud()
	_load_save()
	_load_structure(int(_saved_data.get("structure_index", 0)))
	if not _saved_data.is_empty():
		_apply_saved_state()
	else:
		_save_game()
	_booted = true


# ============================================================================
# STRUCTURE LOADING
# ============================================================================

func _load_structure(index: int) -> void:
	var all := STRUCTS.structures()
	_structure_index = posmod(index, all.size())
	_st = all[_structure_index]

	# Build limits + baseplate derive from the FULL structure footprint with a
	# one-cell margin (playtest rule) — placement bounds always cover the build.
	_st["limits"] = STRUCTS.build_limits(_st)

	# Camera framing per structure footprint.
	_base_cam_dist = maxf(_st["limits"].x, _st["limits"].z) * 2.6 + 6.0
	# Diorama stages: the island (~9+ units + chunks) needs wider framing than
	# the structure footprint alone dictates — floor the distance so the whole
	# island sits in a portrait frame.
	if _st.get("id", "") == "mastaba" or _st.get("id", "") == "diorama_debug":
		# BUILD 36: the enlarged Mastaba_01 island (~13.5 units long) needs
		# wider framing than the 24-unit floor — floor at 36.
		_base_cam_dist = maxf(_base_cam_dist, 36.0)
	_set_cam_dist(_base_cam_dist)

	_top_label.text = _st["site_era"]
	if _diorama != null:
		_diorama.build(_st["id"])
	_apply_debug_mode()
	_restart_arc()


## Stage-only debug level (10 · DIORAMA DEBUG): strip the world to just the
## diorama — no floor, no baseplate, no HUD — leaving only the debug panel
## and a lone escape button so the stage can be judged in isolation.
func _apply_debug_mode() -> void:
	var was_debug := _debug_mode
	_debug_mode = (_st.get("id", "") == "diorama_debug")
	if _debug_mode == was_debug:
		return
	if _debug_mode:
		if _diorama != null:
			_diorama.visible = false
		if _baseplate != null:
			_baseplate.visible = false
		for child in _hud_root.get_children():
			if child != _debug_panel:
				child.visible = false
		if _escape_layer != null:
			_escape_layer.visible = true
	else:
		if _diorama != null:
			_diorama.visible = true
		if _baseplate != null:
			_baseplate.visible = true
		for child in _hud_root.get_children():
			child.visible = true
		if _escape_layer != null:
			_escape_layer.visible = false


func _exit_debug_mode() -> void:
	_load_structure(0)  # back to Göbekli, the first real level


# ============================================================================
# WORLD
# ============================================================================

func _build_world() -> void:
	# --- Camera pivot (isometric default) ---
	_pivot = Node3D.new()
	_pivot.name = "CameraPivot"
	add_child(_pivot)
	_pivot.rotation = _default_cam_rot

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	# BUILD 29: perspective (3-point) — Asset Forge-style depth; zoom = dolly.
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 60.0
	# Camera 24 units out (beyond the island's edge) and 0.15 ABOVE the top
	# plane so level views keep the top face clear of the near plane.
	_camera.position = Vector3(0, 0.15, _cam_dist)
	_pivot.add_child(_camera)

	# --- Sun ---
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.position = Vector3(6, 10, 4)
	add_child(_sun)
	_sun.look_at(Vector3.ZERO)
	_sun.light_color = Color("#FFF2D0")
	_sun.light_energy = 1.15

	# --- Soft ambient fill ---
	_fill = DirectionalLight3D.new()
	_fill.name = "Fill"
	_fill.position = Vector3(-4, 6, -6)
	add_child(_fill)
	_fill.look_at(Vector3.ZERO)
	_fill.light_color = Color("#EADFC0")
	_fill.light_energy = 0.4

	# --- Environment: beat-driven sky (floating slice — pure sky, no ground
	# band) + sky-sampled ambient so night/dusk tint the whole scene.
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://art/sky_beat.gdshader")
	_sky_mat.set_shader_parameter("sky_tex", load("res://art/textures/sky_clouds.png"))
	environment.sky = Sky.new()
	environment.sky.sky_material = _sky_mat
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.5
	env.environment = environment
	add_child(env)
	_apply_beat_sky()

	# --- Floor (raycast target only — the VISIBLE ground is the earth slab).
	# Top surface at y=0 matches the slab top: block resting + support checks
	# are unchanged.
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(100, 0.1, 100)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0, -0.05, 0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	# --- Diorama (the organic blob island: grass floor + brown-only strata).
	_diorama = DIORAMA.new()
	_diorama.name = "Diorama"
	add_child(_diorama)

	# --- Baseplate tiles (build footprint marker) ---
	_baseplate = Node3D.new()
	_baseplate.name = "Baseplate"
	add_child(_baseplate)


func _build_baseplate() -> void:
	for child in _baseplate.get_children():
		child.queue_free()
	var mat := ShaderMaterial.new()
	mat.resource_local_to_scene = true
	mat.shader = load("res://baseplate.gdshader")
	var lim: Vector3 = _st["limits"]
	for bx in range(-int(lim.x), int(lim.x) + 1):
		for bz in range(-int(lim.z), int(lim.z) + 1):
			var tile := MeshInstance3D.new()
			var tile_mesh := BoxMesh.new()
			tile_mesh.size = Vector3(1.0, 0.05, 1.0)
			tile.mesh = tile_mesh
			tile.material_override = mat
			tile.position = Vector3(bx, 0.025, bz)
			_baseplate.add_child(tile)


# ============================================================================
# HUD
# ============================================================================

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(root)
	_hud_root = root

	# Hover-inspect label (desktop driving): shows the diorama entry under the
	# cursor — index, type, rotation, position — so the user can say "entry 54
	# needs +90°" and the BLOCKS array line is unambiguous.
	_hover_label = Label.new()
	_hover_label.name = "HoverInfo"
	_hover_label.position = Vector2(14, SAFE_TOP + 160)
	_hover_label.add_theme_font_size_override("font_size", 28)
	_hover_label.add_theme_color_override("font_color", Color(0, 0, 0))
	var hover_bg := StyleBoxFlat.new()
	hover_bg.bg_color = Color(1, 1, 1, 0.88)
	hover_bg.corner_radius_top_left = 8
	hover_bg.corner_radius_top_right = 8
	hover_bg.corner_radius_bottom_left = 8
	hover_bg.corner_radius_bottom_right = 8
	hover_bg.content_margin_left = 12
	hover_bg.content_margin_right = 12
	hover_bg.content_margin_top = 8
	hover_bg.content_margin_bottom = 8
	_hover_label.add_theme_stylebox_override("normal", hover_bg)
	_hover_label.visible = false
	root.add_child(_hover_label)

	# --- Top bar (below notch) ---
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = SAFE_TOP
	top.offset_bottom = SAFE_TOP + 150
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.12, 0.18, 0.85)))
	root.add_child(top)

	var top_box := VBoxContainer.new()
	top.add_child(top_box)

	_beat_label = Label.new()
	_beat_label.add_theme_font_size_override("font_size", 32)
	_beat_label.add_theme_color_override("font_color", Color("#F0C040"))
	top_box.add_child(_beat_label)

	_top_label = Label.new()
	_top_label.text = ""
	_top_label.add_theme_font_size_override("font_size", 36)
	top_box.add_child(_top_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 26)
	_progress_bar.show_percentage = false
	top_box.add_child(_progress_bar)

	# --- Build badge (top-right, below notch) ---
	_build_label = Label.new()
	_build_label.text = "BUILD %d" % BUILD_NO
	_build_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_build_label.offset_left = -220
	_build_label.offset_right = -14
	_build_label.offset_top = SAFE_TOP + 4
	_build_label.offset_bottom = SAFE_TOP + 48
	_build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_build_label.add_theme_font_size_override("font_size", 26)
	_build_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	root.add_child(_build_label)

	# --- View buttons (CubeUI: Top / Front / Side) ---
	var view_row := HBoxContainer.new()
	view_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	view_row.offset_left = 12
	view_row.offset_right = -12
	view_row.offset_top = SAFE_TOP + 162
	view_row.offset_bottom = SAFE_TOP + 222
	view_row.alignment = BoxContainer.ALIGNMENT_CENTER
	view_row.add_theme_constant_override("separation", 8)
	root.add_child(view_row)

	var view_defs := [
		["Top", Vector3(-PI / 2.0, 0.0, 0.0)],
		["Front", Vector3(0.0, 0.0, 0.0)],
		["Side", Vector3(0.0, -PI / 2.0, 0.0)],
	]
	for def in view_defs:
		var btn := Button.new()
		btn.text = def[0]
		btn.custom_minimum_size = Vector2(0, 56)
		btn.add_theme_font_size_override("font_size", 26)
		btn.pressed.connect(_snap_camera.bind(def[1]))
		view_row.add_child(btn)

	# --- Reset view button (back to the puzzle-start isometric view) ---
	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.custom_minimum_size = Vector2(0, 56)
	reset_btn.add_theme_font_size_override("font_size", 26)
	reset_btn.pressed.connect(func(): _snap_camera(_default_cam_rot))
	view_row.add_child(reset_btn)

	# --- Scaffold toggle row ---
	var scaffold_row := HBoxContainer.new()
	scaffold_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	scaffold_row.offset_left = 12
	scaffold_row.offset_right = -12
	scaffold_row.offset_top = SAFE_TOP + 230
	scaffold_row.offset_bottom = SAFE_TOP + 290
	scaffold_row.alignment = BoxContainer.ALIGNMENT_CENTER
	scaffold_row.add_theme_constant_override("separation", 8)
	root.add_child(scaffold_row)

	var scaffold_defs := [
		["Ghost", Scaffold.GHOST],
		["Ghost+Plan", Scaffold.GHOST_PARTIAL],
		["Plan only", Scaffold.PLAN_ONLY],
	]
	for def in scaffold_defs:
		var btn := Button.new()
		btn.text = def[0]
		btn.custom_minimum_size = Vector2(0, 56)
		btn.add_theme_font_size_override("font_size", 24)
		btn.toggle_mode = true
		btn.pressed.connect(_on_scaffold_pressed.bind(def[1], btn))
		scaffold_row.add_child(btn)
		_scaffold_buttons.append(btn)

	# --- Memory Atlas button (next to scaffold row) ---
	_atlas_btn = Button.new()
	_atlas_btn.text = "📖  Memory Atlas"
	_atlas_btn.custom_minimum_size = Vector2(0, 56)
	_atlas_btn.add_theme_font_size_override("font_size", 24)
	_atlas_btn.pressed.connect(_open_atlas)
	scaffold_row.add_child(_atlas_btn)

	# --- Tool row (Single / Paint / Erase / Rotate) ---
	var tool_row := HBoxContainer.new()
	tool_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tool_row.offset_left = 12
	tool_row.offset_right = -12
	tool_row.offset_top = SAFE_TOP + 298
	tool_row.offset_bottom = SAFE_TOP + 358
	tool_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tool_row.add_theme_constant_override("separation", 10)
	root.add_child(tool_row)

	var tool_defs := [
		["Single", Tool.SINGLE],
		["Paint", Tool.PAINT],
		["Erase", Tool.ERASER],
	]
	for def in tool_defs:
		var btn := Button.new()
		btn.text = def[0]
		btn.custom_minimum_size = Vector2(0, 60)
		btn.add_theme_font_size_override("font_size", 26)
		btn.toggle_mode = true
		btn.pressed.connect(_on_tool_pressed.bind(def[1], btn))
		tool_row.add_child(btn)
		_tool_buttons.append(btn)

	# --- Blueprint button ---
	var plan_btn := Button.new()
	plan_btn.text = "📜  Excavation File"
	plan_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	plan_btn.offset_left = -320
	plan_btn.offset_right = -12
	plan_btn.offset_top = SAFE_TOP + 298
	plan_btn.offset_bottom = SAFE_TOP + 358
	plan_btn.add_theme_font_size_override("font_size", 24)
	plan_btn.pressed.connect(_open_blueprint)
	root.add_child(plan_btn)

	# --- Debug button (level jump; sits where Restart was, Restart moved into
	#     the debug panel). Big button + big panel controls for easy tapping. ---
	var debug_btn := Button.new()
	debug_btn.text = "🔧 Debug"
	debug_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	debug_btn.offset_left = 12
	debug_btn.offset_top = SAFE_TOP + 298
	debug_btn.offset_bottom = SAFE_TOP + 358
	debug_btn.add_theme_font_size_override("font_size", 26)
	root.add_child(debug_btn)

	_debug_panel = Control.new()
	_debug_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_debug_panel.visible = false
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_debug_panel)

	var debug_dim := ColorRect.new()
	debug_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_dim.color = Color(0, 0, 0, 0.72)
	_debug_panel.add_child(debug_dim)
	# Tapping the dim (outside the card) dismisses the number pad only.
	debug_dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			DisplayServer.virtual_keyboard_hide())

	# Centered card, high enough that the iOS number pad never covers it.
	var debug_card := PanelContainer.new()
	debug_card.set_anchors_preset(Control.PRESET_CENTER)
	debug_card.offset_left = -340
	debug_card.offset_right = 340
	debug_card.offset_top = -330
	debug_card.offset_bottom = 330
	debug_card.add_theme_stylebox_override("panel", _panel_style(Color(0.13, 0.13, 0.2, 0.97)))
	_debug_panel.add_child(debug_card)

	var debug_box := VBoxContainer.new()
	debug_box.add_theme_constant_override("separation", 16)
	debug_card.add_child(debug_box)

	var debug_title := Label.new()
	debug_title.text = "DEBUG"
	debug_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_title.add_theme_font_size_override("font_size", 44)
	debug_box.add_child(debug_title)

	var debug_hint := Label.new()
	debug_hint.text = "Jump to any structure (1–%d):" % STRUCTS.structures().size()
	debug_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_hint.add_theme_font_size_override("font_size", 28)
	debug_box.add_child(debug_hint)

	_level_input = LineEdit.new()
	_level_input.text = str(_structure_index + 1)
	_level_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_level_input.custom_minimum_size = Vector2(0, 96)
	_level_input.add_theme_font_size_override("font_size", 42)
	_level_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_box.add_child(_level_input)

	var jump_btn := Button.new()
	jump_btn.text = "Go ▸"
	jump_btn.custom_minimum_size = Vector2(0, 88)
	jump_btn.add_theme_font_size_override("font_size", 32)
	jump_btn.pressed.connect(_on_debug_jump)
	debug_box.add_child(jump_btn)
	# Enter on a full keyboard also jumps.
	_level_input.text_submitted.connect(func(_t: String): _on_debug_jump())

	var debug_restart := Button.new()
	debug_restart.text = "↺ Restart current structure"
	debug_restart.custom_minimum_size = Vector2(0, 84)
	debug_restart.add_theme_font_size_override("font_size", 32)
	debug_restart.pressed.connect(func():
		DisplayServer.virtual_keyboard_hide()
		_clear_save()
		_restart_arc())
	debug_box.add_child(debug_restart)

	var done_btn := Button.new()
	done_btn.text = "✓ Done"
	done_btn.custom_minimum_size = Vector2(0, 84)
	done_btn.add_theme_font_size_override("font_size", 32)
	done_btn.pressed.connect(func():
		DisplayServer.virtual_keyboard_hide()
		_debug_panel.visible = false)
	debug_box.add_child(done_btn)

	var debug_close := Button.new()
	debug_close.text = "✕ Close"
	debug_close.custom_minimum_size = Vector2(0, 84)
	debug_close.add_theme_font_size_override("font_size", 32)
	debug_close.pressed.connect(func():
		DisplayServer.virtual_keyboard_hide()
		_debug_panel.visible = false)
	debug_box.add_child(debug_close)

	debug_btn.pressed.connect(func():
		_level_input.text = str(_structure_index + 1)
		# Transient beat UI (banners, decay epilogue, skip) must not bleed through.
		_message_card.visible = false
		_epilogue_card.visible = false
		_skip_btn.visible = false
		_debug_panel.visible = true
		_level_input.grab_focus())

	# --- Palette tray (bottom, raised above home indicator) ---
	var tray := PanelContainer.new()
	tray.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tray.offset_left = 12
	tray.offset_right = -12
	tray.offset_top = TRAY_TOP
	tray.offset_bottom = TRAY_BOTTOM
	var tray_sb := _panel_style(Color(0.12, 0.12, 0.18, 0.92))
	tray_sb.content_margin_top = 36
	tray_sb.content_margin_bottom = 36
	tray_sb.content_margin_left = 20
	tray_sb.content_margin_right = 20
	tray.add_theme_stylebox_override("panel", tray_sb)
	root.add_child(tray)
	_tray = tray

	_swatch_box = HBoxContainer.new()
	_swatch_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_swatch_box.add_theme_constant_override("separation", 16)
	tray.add_child(_swatch_box)

	# --- Message card (beat banners; bottom-anchored, clear of baseplate) ---
	_message_card = PanelContainer.new()
	_message_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_message_card.offset_left = 60
	_message_card.offset_right = -60
	_message_card.offset_top = TRAY_TOP - 300
	_message_card.offset_bottom = TRAY_TOP - 60
	_message_card.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.08, 0.14, 0.9)))
	_message_card.visible = false
	_message_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_message_card)

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", 44)
	_message_label.add_theme_color_override("font_color", Color("#FFF6E0"))
	_message_card.add_child(_message_label)

	# --- Epilogue card (decay beat; bottom-anchored so decay is visible) ---
	_epilogue_card = PanelContainer.new()
	_epilogue_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_epilogue_card.offset_left = 60
	_epilogue_card.offset_right = -60
	_epilogue_card.offset_top = TRAY_TOP - 380
	_epilogue_card.offset_bottom = TRAY_TOP - 40
	_epilogue_card.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.06, 0.1, 0.94)))
	_epilogue_card.visible = false
	_epilogue_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_epilogue_card)

	_epilogue_label = RichTextLabel.new()
	_epilogue_label.bbcode_enabled = true
	_epilogue_label.fit_content = true
	_epilogue_label.scroll_active = false
	_epilogue_label.add_theme_font_size_override("normal_font_size", 36)
	_epilogue_card.add_child(_epilogue_label)

	# --- Skip button (decay only) ---
	_skip_btn = Button.new()
	_skip_btn.text = "Skip ▸"
	_skip_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_skip_btn.offset_left = -100
	_skip_btn.offset_right = 100
	_skip_btn.offset_top = TRAY_TOP - 90
	_skip_btn.offset_bottom = TRAY_TOP - 30
	_skip_btn.visible = false
	_skip_btn.add_theme_font_size_override("font_size", 24)
	_skip_btn.pressed.connect(_skip_decay)
	root.add_child(_skip_btn)

	# --- Blueprint sheet (modal; bottom-anchored, no baseplate overlap) ---
	_blueprint_sheet = Control.new()
	_blueprint_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blueprint_sheet.visible = false
	_blueprint_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_blueprint_sheet)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	_blueprint_sheet.add_child(dim)

	var sheet := PanelContainer.new()
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.offset_left = 30
	sheet.offset_right = -30
	sheet.offset_top = TRAY_TOP - 560
	sheet.offset_bottom = TRAY_TOP - 20
	sheet.add_theme_stylebox_override("panel", _panel_style(Color(0.13, 0.13, 0.2, 0.97)))
	_blueprint_sheet.add_child(sheet)

	var sheet_box := VBoxContainer.new()
	sheet_box.add_theme_constant_override("separation", 10)
	sheet.add_child(sheet_box)

	var sheet_title := Label.new()
	sheet_title.text = "Excavation File"
	sheet_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet_title.add_theme_font_size_override("font_size", 34)
	sheet_box.add_child(sheet_title)

	var sheet_grid := GridContainer.new()
	sheet_grid.columns = 2
	sheet_grid.add_theme_constant_override("h_separation", 24)
	sheet_box.add_child(sheet_grid)

	sheet_grid.add_child(_make_view_label("TOP DOWN (plan)"))
	sheet_grid.add_child(_make_view_label("EAST FACE (elevation)"))

	_plan_view = BlueprintView.new()
	_plan_view.custom_minimum_size = Vector2(470, 340)
	_plan_view.mode = BlueprintView.MODE_PLAN
	sheet_grid.add_child(_plan_view)

	_elev_view = BlueprintView.new()
	_elev_view.custom_minimum_size = Vector2(470, 340)
	_elev_view.mode = BlueprintView.MODE_ELEVATION
	sheet_grid.add_child(_elev_view)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 64)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.pressed.connect(func(): _blueprint_sheet.visible = false)
	sheet_box.add_child(close_btn)

	# --- Memory Atlas card (bottom-anchored, interactive entries) ---
	_atlas_card = PanelContainer.new()
	_atlas_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_atlas_card.offset_left = 60
	_atlas_card.offset_right = -60
	_atlas_card.offset_top = TRAY_TOP - 420
	_atlas_card.offset_bottom = TRAY_TOP - 20
	_atlas_card.add_theme_stylebox_override("panel", _panel_style(Color(0.1, 0.12, 0.16, 0.96)))
	_atlas_card.visible = false
	root.add_child(_atlas_card)

	# --- Escape hatch for stage-only debug mode (layer above the HUD) ---
	_escape_layer = CanvasLayer.new()
	_escape_layer.layer = 11
	_escape_layer.visible = false
	add_child(_escape_layer)
	var esc_root := Control.new()
	esc_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	esc_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_escape_layer.add_child(esc_root)
	var esc_btn := Button.new()
	esc_btn.text = "✕ Exit diorama"
	esc_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	esc_btn.offset_left = 24
	esc_btn.offset_top = SAFE_TOP + 8
	esc_btn.offset_right = 320
	esc_btn.offset_bottom = SAFE_TOP + 76
	esc_btn.add_theme_font_size_override("font_size", 30)
	esc_btn.pressed.connect(_exit_debug_mode)
	esc_root.add_child(esc_btn)

	var atlas_box := VBoxContainer.new()
	atlas_box.add_theme_constant_override("separation", 12)
	_atlas_card.add_child(atlas_box)

	var atlas_title := Label.new()
	atlas_title.text = "MEMORY ATLAS"
	atlas_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atlas_title.add_theme_font_size_override("font_size", 44)
	atlas_box.add_child(atlas_title)

	var atlas_sub := Label.new()
	atlas_sub.text = "Tap an entry to view a structure at its height —\nor as the earth gave it back."
	atlas_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atlas_sub.add_theme_color_override("font_color", Color("#C8D8F0"))
	atlas_sub.add_theme_font_size_override("font_size", 24)
	atlas_box.add_child(atlas_sub)

	var zenith_btn := Button.new()
	zenith_btn.text = "◈ The Zenith — at its peak (tap to view)"
	zenith_btn.custom_minimum_size = Vector2(0, 64)
	zenith_btn.add_theme_font_size_override("font_size", 26)
	zenith_btn.pressed.connect(func(): _view_atlas_state("zenith"))
	atlas_box.add_child(zenith_btn)

	var today_btn := Button.new()
	today_btn.text = "◈ Today — as the sand gave it back (tap to view)"
	today_btn.custom_minimum_size = Vector2(0, 64)
	today_btn.add_theme_font_size_override("font_size", 26)
	today_btn.pressed.connect(func(): _view_atlas_state("today"))
	atlas_box.add_child(today_btn)

	var orbit_btn := Button.new()
	orbit_btn.text = "◉ Free Rotate — orbit the structure"
	orbit_btn.custom_minimum_size = Vector2(0, 64)
	orbit_btn.add_theme_font_size_override("font_size", 26)
	orbit_btn.pressed.connect(_enable_free_rotate)
	atlas_box.add_child(orbit_btn)

	var next_btn := Button.new()
	next_btn.text = "Next ▸"
	next_btn.custom_minimum_size = Vector2(0, 64)
	next_btn.add_theme_font_size_override("font_size", 28)
	next_btn.pressed.connect(_on_next_pressed)
	atlas_box.add_child(next_btn)

	var close_atlas_btn := Button.new()
	close_atlas_btn.text = "✕ Close"
	close_atlas_btn.custom_minimum_size = Vector2(0, 64)
	close_atlas_btn.add_theme_font_size_override("font_size", 26)
	close_atlas_btn.pressed.connect(func():
		_atlas_card.visible = false
		_restore_build_view())
	atlas_box.add_child(close_atlas_btn)

	var more_label := Label.new()
	more_label.text = "%d structures in the arc — more coming." % STRUCTS.structures().size()
	more_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	more_label.add_theme_color_override("font_color", Color("#8A8A9A"))
	more_label.add_theme_font_size_override("font_size", 20)
	atlas_box.add_child(more_label)

	# The debug panel must draw above every later sibling (beat banners,
	# epilogue, blueprint sheet, atlas) no matter how it is opened.
	_debug_panel.move_to_front()


func _make_view_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("#F0C040"))
	l.add_theme_font_size_override("font_size", 22)
	return l


func _panel_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.45, 0.6, 0.9, 0.6)
	return sb


# ============================================================================
# BEAT MACHINE
# ============================================================================

## Four palettes, one per beat: RAISING = dawn, RESTORATION = noon,
## DECAY = dusk, EXCAVATION = night. The sky shader carries the whole
## background, so a beat change repaints the entire sky.
func _apply_beat_sky() -> void:
	if _sky_mat == null:
		return
	match current_beat:
		Beat.RAISING:
			# Dawn: the morning skybox (peach clouds, low sun) + warm wash.
			_sky_mat.set_shader_parameter("sky_tex", load("res://art/textures/sky_morning.png"))
			_sky_mat.set_shader_parameter("tint", Color("#FFF3E0"))
		Beat.RESTORATION:
			# Noon: the day skybox (blue, clouds, high sun) at full color.
			_sky_mat.set_shader_parameter("sky_tex", load("res://art/textures/sky_day.png"))
			_sky_mat.set_shader_parameter("tint", Color("#FFFFFF"))
		Beat.DECAY:
			# Dusk: the morning skybox again, pushed orange.
			_sky_mat.set_shader_parameter("sky_tex", load("res://art/textures/sky_morning.png"))
			_sky_mat.set_shader_parameter("tint", Color("#FFD9B0"))
		Beat.EXCAVATION:
			# Night: the night skybox (moon, stars) + cool wash.
			_sky_mat.set_shader_parameter("sky_tex", load("res://art/textures/sky_night.png"))
			_sky_mat.set_shader_parameter("tint", Color("#E8ECFF"))


## The floating earth slice sways gently while the player is hands-off.
## The whole stage (root) bobs; the camera pivot counter-bobs so the view
## stays still while the world breathes. Ramps in ~1s after the last touch
## so placement math (raycasts, stacking) only ever runs at y=0.
func _process(_delta: float) -> void:
	if _pivot == null:
		return
	var idle := Time.get_ticks_msec() / 1000.0 - _last_touch_time
	var ramp := clampf((idle - 1.0) / 2.0, 0.0, 1.0)
	var bob := sin(Time.get_ticks_msec() / 1000.0 * TAU / BOB_PERIOD) * BOB_AMPLITUDE * ramp
	position.y = bob
	_pivot.position.y = -bob


func _start_beat(beat: Beat) -> void:
	current_beat = beat
	_beat_label.text = BEAT_TITLE[beat]
	_apply_beat_sky()
	_is_orchestrating = false
	_skip_btn.visible = false
	_epilogue_card.visible = false
	_epilogue_label.text = ""

	match beat:
		Beat.RAISING:
			build_target = _st["core"].duplicate()
			_palette = _level_materials()
			_show_message(_st["beat1_msg"], 2.2)
		Beat.RESTORATION:
			build_target = _st["zenith"].duplicate()
			_palette = _level_materials()
			_show_message(_st["beat2_msg"], 2.6)
		Beat.DECAY:
			_run_decay()
			return
		Beat.EXCAVATION:
			build_target = {}
			_palette.clear()
			_show_message(_st["excavation_msg"], 2.6)
			_spawn_dust()

	_rebuild_palette()
	_refresh_ghosts()
	_update_progress()
	if _booted:
		_save_game()


## Unique material names used by a cell dict, in first-appearance order.
func _unique_materials(cells: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for pos in cells:
		var mat: String = cells[pos]
		if not out.has(mat):
			out.append(mat)
	return out


## Every material the level uses across BOTH build beats (core ∪ zenith), in
## first-appearance order. The tray always offers all of them: a block that
## can be deleted in any phase can always be re-placed — no deadlocks.
func _level_materials() -> Array[String]:
	var all: Dictionary = _st["core"].duplicate()
	all.merge(_st["zenith"])
	return _unique_materials(all)


func _on_block_placed(pos: Vector3i, color_name: String) -> void:
	if _is_orchestrating:
		return
	# A block landed on a target cell with the right material → count it.
	if build_target.has(pos) and build_target[pos] == color_name and not completed_cells.has(pos):
		completed_cells[pos] = color_name
		_refresh_ghosts()
		_update_progress()
		_check_beat_complete()
		_save_game()
		_update_erase_highlights()
	else:
		# Wrong cell/material: flash red and remove.
		var block := _find_block_at(pos)
		if block:
			var tween := create_tween()
			tween.tween_method(
				func(a: float): block.set_block_color(Color(0.9, 0.25, 0.2).lerp(block.block_color, a), color_name),
				0.0, 1.0, 0.35)
			tween.tween_callback(block.queue_free)


func _on_paint_requested(pos: Vector3i, color_name: String) -> void:
	if _is_orchestrating:
		return
	if not build_target.has(pos) or build_target[pos] != color_name or completed_cells.has(pos):
		return
	# Spawn a parked block at the painted cell. It must STAY physics-solid so
	# later layers stack on top of it (the stack-height ray depends on it),
	# and it stays in slice_blocks so Erase sees it (highlight + removal).
	# is_parked locks out pickup/drag — repaint to change a painted cell.
	var block := SliceBlock.new()
	add_child(block)
	block.limit_x = _st["limits"].x
	block.limit_z = _st["limits"].z
	block.limit_y = _st["limits"].y
	block.current_tool = current_tool
	block.place_at(pos, _st["colors"][color_name], color_name)
	block.is_parked = true
	# Erase must reach the controller: removal clears the completed cell.
	block.removed.connect(_on_block_removed)
	completed_cells[pos] = color_name
	Input.vibrate_handheld(20)
	_refresh_ghosts()
	_update_progress()
	_check_beat_complete()
	_save_game()
	_update_erase_highlights()


func _find_block_at(pos: Vector3i) -> SliceBlock:
	for block in get_tree().get_nodes_in_group("slice_blocks"):
		var b := block as SliceBlock
		if is_instance_valid(b) and b.is_placed and b.occupies(pos):
			return b
	return null


func _on_block_removed(pos: Vector3i) -> void:
	completed_cells.erase(pos)
	_refresh_ghosts()
	_update_progress()
	_save_game()
	_update_erase_highlights()


func _check_beat_complete() -> void:
	var all_done := true
	for pos in build_target:
		if not completed_cells.has(pos):
			all_done = false
			break
	if not all_done:
		return

	_is_orchestrating = true
	Input.vibrate_handheld(120)
	_flourish()
	# Reset to the isometric view FIRST, then speak — the player always sees
	# the next phase open from the canonical angle, never from a dead end.
	_snap_camera(_default_cam_rot)
	await get_tree().create_timer(0.45).timeout
	match current_beat:
		Beat.RAISING:
			_show_message("The %s is raised." % _st["id"].replace("_", " "), 2.4)
			await get_tree().create_timer(2.6).timeout
			_start_beat(Beat.RESTORATION)
		Beat.RESTORATION:
			_show_message("It shines at its zenith.\nTime now does its work.", 2.6)
			await get_tree().create_timer(2.8).timeout
			_start_beat(Beat.DECAY)


## Flourish: sun brightens + camera breathes out + progress hits 100%.
func _flourish() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sun, "light_energy", 1.55, 1.0)
	tween.tween_property(_camera, "position:z", _cam_dist + 2.0, 1.2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(_camera, "position:z", _base_cam_dist, 1.0)


# ============================================================================
# SAVE / RESTORE (progress persists at every stage; survives kill + background)
# ============================================================================

func _save_game() -> void:
	if _debug_mode:
		return  # never persist the stage-only debug level
	if _st != null and _st.get("id", "") == "diorama_debug":
		return  # belt + suspenders: the id guard catches saves fired from
		# _start_beat during _load_structure(9), before the debug flag is set
	var data := {
		"structure_index": _structure_index,
		"beat": current_beat,
		"arc_completed": _arc_completed,
		"scaffold_mode": scaffold_mode,
		"completed": {},
		"dust_remaining": [],
		"cam_rot": [_pivot.rotation.x, _pivot.rotation.y, _pivot.rotation.z],
		"cam_pos": [_pivot.position.x, _pivot.position.y, _pivot.position.z],
		"cam_size": _cam_dist,
	}
	for pos in completed_cells:
		data["completed"]["%d,%d,%d" % [pos.x, pos.y, pos.z]] = completed_cells[pos]
	for pos in dust_mounds:
		data["dust_remaining"].append([pos.x, pos.y, pos.z])
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _load_save() -> void:
	_saved_data = {}
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_saved_data = json.data
	file.close()


## Restore a saved run. The structure is already loaded; this applies the
## beat, the completed build, dust state, and the saved camera.
func _apply_saved_state() -> void:
	if _saved_data.is_empty():
		return
	_arc_completed = bool(_saved_data.get("arc_completed", false))
	scaffold_mode = int(_saved_data.get("scaffold_mode", Scaffold.GHOST))
	for i in range(_scaffold_buttons.size()):
		_scaffold_buttons[i].button_pressed = (i == scaffold_mode)

	var cam_rot: Array = _saved_data.get("cam_rot", [])
	if cam_rot.size() == 3:
		_pivot.rotation = Vector3(float(cam_rot[0]), float(cam_rot[1]), float(cam_rot[2]))
	var cam_pos: Array = _saved_data.get("cam_pos", [])
	if cam_pos.size() == 3:
		_pivot.position = Vector3(
			clampf(float(cam_pos[0]), -PAN_CLAMP, PAN_CLAMP),
			float(cam_pos[1]),
			clampf(float(cam_pos[2]), -PAN_CLAMP, PAN_CLAMP))
	_set_cam_dist(clampf(float(_saved_data.get("cam_size", _base_cam_dist)), CAM_DIST_MIN, CAM_DIST_MAX))

	completed_cells.clear()
	var raw_completed: Dictionary = _saved_data.get("completed", {})
	for key in raw_completed:
		var parts := String(key).split(",")
		if parts.size() == 3:
			completed_cells[Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))] = raw_completed[key]

	# Prune completed cells that no longer belong to this structure (e.g. a
	# banner target moved by a data fix) so stale blocks never restore as
	# floating geometry and old stuck saves self-heal.
	var valid_cells := STRUCTS.combined_cells(_st)
	for pos in completed_cells.keys():
		if not valid_cells.has(pos):
			completed_cells.erase(pos)

	# Rebuild the build as placed blocks (cells restored individually — a
	# placed multi-cell piece reads identically once its cells are filled).
	for pos in completed_cells:
		var color_name: String = completed_cells[pos]
		var block := SliceBlock.new()
		add_child(block)
		block.limit_x = _st["limits"].x
		block.limit_z = _st["limits"].z
		block.limit_y = _st["limits"].y
		block.place_at(pos, _st["colors"][color_name], color_name)

	var saved_beat := int(_saved_data.get("beat", Beat.RAISING))
	if saved_beat == Beat.EXCAVATION or saved_beat == Beat.DECAY:
		_dust_total = STRUCTS.dust_cells(_st).size()
		var remaining: Array = _saved_data.get("dust_remaining", [])
		if remaining.is_empty() and saved_beat == Beat.DECAY:
			# Saved mid-cinematic decay: the mound field never spawned, so
			# spawn the full field — excavation resumes from the start.
			for pos in STRUCTS.dust_cells(_st):
				_spawn_dust_at(pos)
		else:
			for entry in remaining:
				var m: Array = entry
				_spawn_dust_at(Vector3i(int(m[0]), int(m[1]), int(m[2])))
		_dust_cleared = _dust_total - dust_mounds.size()

	_restore_beat(saved_beat)

	if _arc_completed and dust_mounds.is_empty():
		_open_atlas()
	_save_game()


## Restore a beat's build state on launch: no banners, no cinematics.
func _restore_beat(beat: Beat) -> void:
	current_beat = beat
	_beat_label.text = BEAT_TITLE[beat]
	_is_orchestrating = false
	_skip_btn.visible = false
	_epilogue_card.visible = false
	_message_card.visible = false
	# A save taken mid-decay resumes at excavation: the cinematic is not
	# resumable and its end state is the mound field anyway.
	if beat == Beat.DECAY:
		beat = Beat.EXCAVATION
		current_beat = Beat.EXCAVATION
		_beat_label.text = BEAT_TITLE[Beat.EXCAVATION]
	match beat:
		Beat.RAISING:
			build_target = _st["core"].duplicate()
		Beat.RESTORATION:
			build_target = _st["zenith"].duplicate()
		Beat.EXCAVATION:
			build_target = {}
	if build_target.is_empty():
		_palette.clear()
	else:
		_palette = _level_materials()
	_rebuild_palette()
	_refresh_ghosts()
	_update_progress()
	# A build beat that was already complete auto-advances, like the live flow.
	var all_done := true
	for pos in build_target:
		if not completed_cells.has(pos):
			all_done = false
			break
	if all_done and not build_target.is_empty():
		if beat == Beat.RAISING:
			_start_beat(Beat.RESTORATION)
		elif beat == Beat.RESTORATION:
			_run_decay()


func _notification(what: int) -> void:
	# iOS backgrounding can suspend/kill the app at any moment — persist then.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()


# ============================================================================
# DECAY (Beat 3 — cinematic, non-interactive)
# ============================================================================

func _run_decay() -> void:
	_is_orchestrating = true
	_palette.clear()
	_rebuild_palette()
	_clear_ghosts()

	_beat_label.text = BEAT_TITLE[Beat.DECAY]
	_epilogue_card.visible = true
	_skip_btn.visible = true
	var lines := _st["epilogue"] as Array
	_epilogue_label.text = "[center]" + "\n".join(lines) + "[/center]"

	var fade := create_tween()
	_epilogue_card.modulate.a = 0.0
	fade.tween_property(_epilogue_card, "modulate:a", 1.0, 1.5)

	var sun_tween := create_tween()
	sun_tween.set_parallel(true)
	sun_tween.tween_property(_sun, "rotation_degrees", Vector3(-70, 210, 0), 9.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sun_tween.tween_property(_sun, "light_color", Color("#E8A06A"), 9.0)

	var blocks := get_tree().get_nodes_in_group("world_blocks") as Array
	for block in blocks:
		var b := block as SliceBlock
		if not is_instance_valid(b):
			continue
		var tier_delay := 0.0
		if b.current_grid_position.y >= 2:
			tier_delay = 2.0
		elif b.current_grid_position.y == 1:
			tier_delay = 4.5
		else:
			tier_delay = 7.0
		var jitter := float(abs(b.current_grid_position.x + b.current_grid_position.z) % 3) * 0.4
		b.decay_sink(tier_delay + jitter, 1.4)

	await get_tree().create_timer(10.0).timeout

	_spawn_mound()

	await get_tree().create_timer(2.0).timeout
	_start_beat(Beat.EXCAVATION)


func _skip_decay() -> void:
	_epilogue_card.visible = false
	_skip_btn.visible = false
	for block in get_tree().get_nodes_in_group("world_blocks"):
		if is_instance_valid(block):
			block.decay_sink(0.0, 0.4)
	_spawn_mound()
	await get_tree().create_timer(0.8).timeout
	_start_beat(Beat.EXCAVATION)


func _spawn_mound() -> void:
	var lim: Vector3 = _st["limits"]
	var rubble_positions := [
		Vector3i(-1, 0, -1), Vector3i(1, 0, 1), Vector3i(0, 0, 0),
		Vector3i(int(lim.x - 1), 0, 0), Vector3i(-int(lim.x) + 1, 0, 1),
	]
	for pos in rubble_positions:
		var block := SliceBlock.new()
		block.name = "Rubble"
		add_child(block)
		block.limit_x = lim.x
		block.limit_z = lim.z
		block.limit_y = lim.y
		block.freeze = true
		block.gravity_scale = 0.0
		block.set_block_color(_st["colors"]["rubble"], "rubble")
		block.position = Vector3(pos.x, 0.25, pos.z)
		block.scale = Vector3(0.7, 0.4, 0.7)
		block.rotation = Vector3(0, (pos.x * 0.7) + pos.z, 0)
		for child in block.get_children():
			if child is CollisionShape3D:
				child.disabled = true
		block.remove_from_group("slice_blocks")
		var tween := create_tween()
		tween.tween_interval(0.2)
		tween.tween_property(block, "scale", Vector3.ONE, 0.8)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# ============================================================================
# EXCAVATION (Beat 4 — light actions)
# ============================================================================

func _spawn_dust() -> void:
	dust_mounds.clear()
	_dust_cleared = 0
	_dust_total = STRUCTS.dust_cells(_st).size()
	for pos in STRUCTS.dust_cells(_st):
		_spawn_dust_at(pos)
	_update_progress()


## Spawns one dust mound at a cell (shared by _spawn_dust and save-restore).
func _spawn_dust_at(pos: Vector3i) -> void:
	var mound := StaticBody3D.new()
	mound.name = "Dust"
	mound.position = Vector3(pos.x, 0.25, pos.z)
	mound.input_ray_pickable = true
	add_child(mound)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.0, 0.5, 1.0)
	shape.shape = box_shape
	mound.add_child(shape)

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.05, 0.5, 1.05)
	mesh.mesh = box_mesh
	mesh.material_override = dust_mat_alpha(0.55)
	mound.add_child(mesh)

	mound.input_event.connect(_on_dust_tapped.bind(pos))
	dust_mounds[pos] = mound


func _on_dust_tapped(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, pos: Vector3i) -> void:
	var is_touch: bool = event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var is_click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).pressed
	if not (is_touch or is_click):
		return
	if _is_orchestrating:
		return
	if not dust_mounds.has(pos):
		return

	var mound = dust_mounds[pos]
	dust_mounds.erase(pos)
	_dust_cleared += 1

	var color_name: String = _st["survivor"][pos]
	var reveal := SliceBlock.new()
	reveal.name = "Survivor"
	add_child(reveal)
	reveal.limit_x = _st["limits"].x
	reveal.limit_z = _st["limits"].z
	reveal.limit_y = _st["limits"].y
	reveal.place_at(pos, _st["colors"][color_name], color_name)
	reveal.remove_from_group("slice_blocks")
	for child in reveal.get_children():
		if child is CollisionShape3D:
			child.disabled = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		func(a: float):
			if is_instance_valid(mound):
				(mound.get_child(1) as MeshInstance3D).material_override = dust_mat_alpha(a),
		0.55, 0.0, 0.35)
	tween.tween_property(mound, "scale", Vector3(0.05, 0.05, 0.05), 0.35)
	tween.tween_callback(mound.queue_free)

	var pop := create_tween()
	reveal.scale = Vector3(0.2, 0.2, 0.2)
	pop.tween_property(reveal, "scale", Vector3.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	Input.vibrate_handheld(30)
	_update_progress()
	_save_game()

	if dust_mounds.is_empty():
		_arc_completed = true
		await get_tree().create_timer(0.8).timeout
		_open_atlas()


func dust_mat_alpha(a: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.resource_local_to_scene = true
	m.shader = load("res://block.gdshader")
	m.set_shader_parameter("albedo_color", _st["colors"]["dust"])
	m.set_shader_parameter("alpha", a)
	return m


# ============================================================================
# MEMORY ATLAS (interactive)
# ============================================================================

func _open_atlas() -> void:
	if not _arc_completed:
		_show_message("The atlas opens to a structure once it has been built —\nand once the earth has given it back.", 2.6)
		return
	# Rebuild the saved states from the data.
	_atlas_states.clear()
	_atlas_states["zenith"] = STRUCTS.combined_cells(_st)
	_atlas_states["today"] = _st["survivor"].duplicate()
	_atlas_card.visible = true
	_atlas_card.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_atlas_card, "modulate:a", 1.0, 0.4)


## Build a structure state (zenith or today) in the world for inspection.
## Clears any previously-viewed atlas state first — only the last request shows.
func _view_atlas_state(state: String) -> void:
	_atlas_card.visible = false
	_is_orchestrating = true

	# Clear ALL world blocks: live build blocks, atlas states, decay rubble,
	# excavation survivors — everything, so no debris leaks into atlas views.
	for block in get_tree().get_nodes_in_group("world_blocks"):
		block.queue_free()
	for mound in dust_mounds.values():
		if is_instance_valid(mound):
			mound.queue_free()
	dust_mounds.clear()
	_clear_ghosts()
	_palette = []
	_rebuild_palette()

	completed_cells.clear()
	var cells: Dictionary = _atlas_states[state]
	for pos in cells:
		var color_name: String = cells[pos]
		var block := SliceBlock.new()
		block.name = "AtlasBlock"
		add_child(block)
		block.limit_x = _st["limits"].x
		block.limit_z = _st["limits"].z
		block.limit_y = _st["limits"].y
		block.place_at(pos, _st["colors"][color_name], color_name)
		block.add_to_group("atlas_blocks")
		block.remove_from_group("slice_blocks")
		for child in block.get_children():
			if child is CollisionShape3D:
				child.disabled = true
		completed_cells[pos] = color_name

	# Restore light + camera, then auto-orbit.
	_sun.light_energy = 1.3
	_sun.light_color = Color("#FFF2D0")
	_pivot.rotation = _default_cam_rot
	_beat_label.text = "MEMORY ATLAS — %s" % ("ZENITH" if state == "zenith" else "TODAY")
	_orbit_showcase(0.0)


## Returning from an atlas view restores the last build beat's blocks.
func _restore_build_view() -> void:
	# Only atlas blocks exist here (everything else was cleared on entry).
	for block in get_tree().get_nodes_in_group("world_blocks"):
		block.queue_free()
	# If we are mid-arc (not completed), reload the current beat's build state.
	if not _arc_completed and current_beat in [Beat.RAISING, Beat.RESTORATION]:
		_start_beat(current_beat)
	else:
		# Arc finished: nothing left to restore — show the mound/site state.
		_pivot.rotation = _default_cam_rot
		_sun.light_energy = 1.15
		_sun.light_color = Color("#FFF2D0")
		_beat_label.text = BEAT_TITLE[current_beat]


func _enable_free_rotate() -> void:
	_atlas_card.visible = false
	set_tool(Tool.ROTATE)


func _orbit_showcase(duration: float = 10.0) -> void:
	if _is_orbiting:
		return
	_is_orbiting = true
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:y", _pivot.rotation.y + TAU, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): _is_orbiting = false)


func _on_next_pressed() -> void:
	# Chronological next structure in the arc; wraps around at the end.
	_load_structure(_structure_index + 1)


func _on_debug_jump() -> void:
	var target := int(_level_input.text)
	var count := STRUCTS.structures().size()
	if target < 1 or target > count:
		_level_input.text = str(_structure_index + 1)
		return
	DisplayServer.virtual_keyboard_hide()
	_debug_panel.visible = false
	_load_structure(target - 1)


# ============================================================================
# TOOLS
# ============================================================================

func set_tool(tool: Tool) -> void:
	current_tool = tool
	var active_color := Color(1.0, 0.85, 0.0)
	for i in range(_tool_buttons.size()):
		var btn := _tool_buttons[i]
		btn.button_pressed = (i == int(tool))
		btn.modulate = active_color if i == int(tool) else Color.WHITE
	# Propagate to live blocks so gestures are gated correctly.
	for block in get_tree().get_nodes_in_group("slice_blocks"):
		(block as SliceBlock).current_tool = current_tool
	_update_erase_highlights()


## Erase mode: pulse an outline on every currently-deletable block.
func _update_erase_highlights() -> void:
	for block in get_tree().get_nodes_in_group("slice_blocks"):
		(block as SliceBlock).set_deletable_highlight(
			current_tool == Tool.ERASER and block._is_deletable())


func _on_tool_pressed(tool: Tool, _btn: Button) -> void:
	set_tool(tool)


# ============================================================================
# PALETTE + SCAFFOLDING + GHOSTS
# ============================================================================

func _rebuild_palette() -> void:
	for child in _swatch_box.get_children():
		child.queue_free()
	_current_swatch = ""
	if _palette.is_empty():
		return
	_current_swatch = _palette[0]
	for color_name in _palette:
		var btn := Button.new()
		# Smaller than the tray on purpose: the block must read as a piece
		# INSIDE the tray, not as the tray itself — the eye grabs the block,
		# the locked tray margin catches the miss.
		btn.custom_minimum_size = Vector2(160, 96)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.text = color_name.replace("_", " ")
		btn.add_theme_font_size_override("font_size", 20)
		var sb := StyleBoxFlat.new()
		sb.bg_color = _st["colors"][color_name]
		sb.corner_radius_top_left = 12
		sb.corner_radius_top_right = 12
		sb.corner_radius_bottom_left = 12
		sb.corner_radius_bottom_right = 12
		sb.border_width_left = 4
		sb.border_width_right = 4
		sb.border_width_top = 4
		sb.border_width_bottom = 4
		sb.border_color = Color(1, 0.85, 0.2) if color_name == _current_swatch else Color(0, 0, 0, 0.4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		# Drag-from-tray: press on the swatch spawns a block in hand at that point.
		btn.gui_input.connect(_on_swatch_gui_input.bind(color_name, btn))
		_swatch_box.add_child(btn)

	# Multi-cell pieces used ANYWHERE in the level — offered in every phase,
	# same rule as materials: a piece removed in any beat can be re-placed.
	var all_pieces: Array = []
	for b in _st.get("beat_pieces", {}):
		all_pieces.append_array(_st["beat_pieces"][b])
	for pd in all_pieces:
		var pbtn := Button.new()
		pbtn.custom_minimum_size = Vector2(160, 96)
		pbtn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pbtn.text = PIECES.pieces()[pd["id"]]["name"]
		pbtn.add_theme_font_size_override("font_size", 20)
		var sb := StyleBoxFlat.new()
		sb.bg_color = _st["colors"][pd["color"]]
		sb.corner_radius_top_left = 12
		sb.corner_radius_top_right = 12
		sb.corner_radius_bottom_left = 12
		sb.corner_radius_bottom_right = 12
		sb.border_width_left = 4
		sb.border_width_right = 4
		sb.border_width_top = 4
		sb.border_width_bottom = 4
		sb.border_color = Color(1, 0.85, 0.2)
		pbtn.add_theme_stylebox_override("normal", sb)
		pbtn.add_theme_stylebox_override("hover", sb)
		pbtn.add_theme_stylebox_override("pressed", sb)
		pbtn.gui_input.connect(_on_piece_gui_input.bind(pd["id"], pbtn))
		_swatch_box.add_child(pbtn)


func _on_swatch_gui_input(event: InputEvent, color_name: String, btn: Button) -> void:
	var is_touch: bool = event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var is_click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).pressed
	if not (is_touch or is_click):
		return
	# iOS/Android: ignore the emulated mouse event for the same finger —
	# otherwise one tap spawns TWO blocks.
	if is_click and OS.get_name() in ["iOS", "Android"]:
		return
	if _is_orchestrating or _palette.is_empty():
		return
	# ROTATE tool: picking a block switches back to SINGLE (reloc-proto behavior).
	if current_tool == Tool.ROTATE:
		set_tool(Tool.SINGLE)
	_current_swatch = color_name
	btn.accept_event()
	var screen_pos: Vector2 = (event as InputEventScreenTouch).position if is_touch else (event as InputEventMouseButton).position
	_spawn_block_in_hand(color_name, screen_pos, -1 if is_click else (event as InputEventScreenTouch).index)


## Spawns a block in hand, positioned prominently between tray and baseplate.
## It HOVERS with a pulse — the player then touches it to drag into position.
func _spawn_block_in_hand(color_name: String, screen_pos: Vector2, touch_index: int) -> void:
	var block := SliceBlock.new()
	add_child(block)
	block.limit_x = _st["limits"].x
	block.limit_z = _st["limits"].z
	block.limit_y = _st["limits"].y
	block.current_tool = current_tool
	block.set_block_color(_st["colors"][color_name], color_name)
	block.placed.connect(_on_block_placed)
	block.removed.connect(_on_block_removed)
	block.paint_requested.connect(_on_paint_requested)

	# Park it visually above the tray, between tray and baseplate, in screen space:
	# project a point ~55% up the screen onto the drag plane, then lift by offset.
	var viewport := get_viewport()
	var vp_size := viewport.get_visible_rect().size
	var anchor_screen := Vector2(vp_size.x * 0.5, vp_size.y * 0.55)
	var anchor_world: Variant = _project_to_plane(anchor_screen)
	if anchor_world != null:
		block.global_position = anchor_world + Vector3(0, block.current_y_offset, 0)
	else:
		block.global_position = Vector3(0, 6, 0)
	# Float in place (no auto-drop) until grabbed — the hover-brick contract.
	block.gravity_scale = 0.0
	block.start_hover_pulse()
	# Direct drag-from-tray: the pressing finger (if any) is armed to this
	# block — moving past the slop promotes to a real drag; a plain tap
	# leaves the hovering brick. Mouse (index -1) keeps hover-only.
	if touch_index >= 0:
		block._arm_drag(touch_index, screen_pos)


## Multi-cell piece tray button: same gesture contract as a swatch, but spawns
## a compound piece (e.g. T-Cap, Roof Slab) from the pieces registry.
func _on_piece_gui_input(event: InputEvent, piece_id: String, btn: Button) -> void:
	var is_touch: bool = event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var is_click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).pressed
	if not (is_touch or is_click):
		return
	if is_click and OS.get_name() in ["iOS", "Android"]:
		return
	if _is_orchestrating or _palette.is_empty():
		return
	if current_tool == Tool.ROTATE:
		set_tool(Tool.SINGLE)
	btn.accept_event()
	var screen_pos: Vector2 = (event as InputEventScreenTouch).position if is_touch else (event as InputEventMouseButton).position
	_spawn_piece_in_hand(piece_id, screen_pos, -1 if is_click else (event as InputEventScreenTouch).index)


func _spawn_piece_in_hand(piece_id: String, screen_pos: Vector2, touch_index: int) -> void:
	var pd: Dictionary = PIECES.pieces()[piece_id]
	var color_name := ""
	for entry in _st.get("beat_pieces", {}).get(current_beat + 1, []):
		if entry["id"] == piece_id:
			color_name = entry["color"]
			break
	if color_name.is_empty():
		color_name = _palette[0]

	var block := SliceBlock.new()
	# Piece data must be set BEFORE add_child — _ready() builds the compound
	# body from piece_cells (one mesh + one collision per cell).
	block.limit_x = _st["limits"].x
	block.limit_z = _st["limits"].z
	block.limit_y = _st["limits"].y
	block.current_tool = current_tool
	block.piece_cells = pd["cells"]
	block.piece_anchors = pd["anchors"]
	block.piece_min_anchors = int(pd.get("min_anchors", 1))
	block.set_block_color(_st["colors"][color_name], color_name)
	block.piece_placed.connect(_on_piece_placed)
	block.piece_removed.connect(_on_piece_removed)
	add_child(block)

	var viewport := get_viewport()
	var vp_size := viewport.get_visible_rect().size
	var anchor_screen := Vector2(vp_size.x * 0.5, vp_size.y * 0.55)
	var anchor_world: Variant = _project_to_plane(anchor_screen)
	if anchor_world != null:
		block.global_position = anchor_world + Vector3(0, block.current_y_offset, 0)
	else:
		block.global_position = Vector3(0, 6, 0)
	block.gravity_scale = 0.0
	block.start_hover_pulse()
	if touch_index >= 0:
		block._arm_drag(touch_index, screen_pos)


## Piece landed: all its cells must be correct target cells — atomic.
func _on_piece_placed(origin: Vector3i, cells: Array, color_name: String) -> void:
	if _is_orchestrating:
		return
	var all_ok := true
	for pos in cells:
		if not (build_target.has(pos) and build_target[pos] == color_name):
			all_ok = false
			break
	if all_ok:
		for pos in cells:
			completed_cells[pos] = color_name
		Input.vibrate_handheld(60)
		_refresh_ghosts()
		_update_progress()
		_check_beat_complete()
		_save_game()
		_update_erase_highlights()
	else:
		var block := _find_block_at(origin)
		if block:
			var tween := create_tween()
			tween.tween_method(
				func(a: float): block.set_block_color(Color(0.9, 0.25, 0.2).lerp(block.block_color, a), color_name),
				0.0, 1.0, 0.35)
			tween.tween_callback(block.queue_free)


## Piece removed (eraser / long-press pickup): every cell leaves the target.
func _on_piece_removed(cells: Array) -> void:
	for pos in cells:
		completed_cells.erase(pos)
	_refresh_ghosts()
	_update_progress()
	_save_game()
	_update_erase_highlights()


## Projects a screen point onto the camera-facing drag plane (same plane the
## blocks drag on, so the hovered brick lands exactly where it appears).
func _project_to_plane(screen_pos: Vector2) -> Variant:
	var cam := _camera
	var ray_origin := cam.project_ray_origin(screen_pos)
	var ray_normal := cam.project_ray_normal(screen_pos)
	var cam_forward: Vector3 = -cam.global_transform.basis.z
	return Plane(cam_forward.normalized(), Vector3(0.0, 1.5, 0.0)).intersects_ray(ray_origin, ray_normal)


func _on_scaffold_pressed(mode: Scaffold, btn: Button) -> void:
	scaffold_mode = mode
	for b in _scaffold_buttons:
		b.button_pressed = (b == btn)
	_refresh_ghosts()


## Ghost overlay: translucent boxes on every unfilled target cell.
func _refresh_ghosts() -> void:
	_clear_ghosts()
	if _is_orchestrating:
		return

	var cells: Dictionary = {}
	match scaffold_mode:
		Scaffold.GHOST:
			cells = build_target.duplicate()
		Scaffold.GHOST_PARTIAL:
			for pos in build_target:
				if pos.y <= 1:
					cells[pos] = build_target[pos]
		Scaffold.PLAN_ONLY:
			cells = {}

	for pos in cells:
		if completed_cells.has(pos):
			continue
		var ghost := MeshInstance3D.new()
		ghost.name = "Ghost"
		ghost.add_to_group("slice_ghosts")
		var mat := ShaderMaterial.new()
		mat.resource_local_to_scene = true
		mat.shader = load("res://ghost.gdshader")
		# Slightly brightened fill at moderate alpha + dark UV outline band —
		# one mesh per cell, so placed cells vanish cleanly (no rim meshes to
		# leak) and the fill stays visibly translucent (not sun-blown white).
		var ghost_color: Color = _st["colors"][cells[pos]].lightened(0.2)
		mat.set_shader_parameter("fill_color", ghost_color)
		mat.set_shader_parameter("alpha", 0.45)
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 1.0, 1.0)
		ghost.mesh = box
		ghost.material_override = mat
		ghost.position = Vector3(pos.x, pos.y + 0.5, pos.z)
		add_child(ghost)


func _clear_ghosts() -> void:
	for ghost in get_tree().get_nodes_in_group("slice_ghosts"):
		ghost.queue_free()


func _update_progress() -> void:
	if current_beat == Beat.EXCAVATION:
		if _dust_total > 0:
			_progress_bar.max_value = _dust_total
			_progress_bar.value = _dust_cleared
		return
	if build_target.is_empty():
		_progress_bar.value = 0
		return
	var done := 0
	for pos in build_target:
		if completed_cells.has(pos):
			done += 1
	_progress_bar.max_value = build_target.size()
	_progress_bar.value = done


# ============================================================================
# CAMERA
# ============================================================================

func _snap_camera(target_rot: Vector3) -> void:
	if _is_orbiting:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_pivot, "rotation", target_rot, 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Snapped views re-center the structure (a pan offset would fight the
	# framing).
	tween.tween_property(_pivot, "position", Vector3.ZERO, 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## True while any live block owns a finger (dragging, long-press pending, or
## armed from a tray press). The free-orbit gesture yields to block gestures.
func _any_block_grabbing() -> bool:
	for block in get_tree().get_nodes_in_group("slice_blocks"):
		if block.is_grabbing():
			return true
	return false


func _input(event: InputEvent) -> void:
	# --- Desktop editor-driver: mouse orbit (left-drag), pan (right-drag),
	# zoom (wheel), hover-inspect diorama entries. Mobile ignores these. ---
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		# iOS/Android: Godot synthesizes mouse events from touches
		# (emulate_mouse_from_touch) — ignoring them here keeps two-finger
		# pan/pinch on the touch path instead of leaking into mouse-orbit
		# (BUILD 41 regression: two-finger pan rotated the camera).
		if OS.get_name() in ["iOS", "Android"]:
			return
		_last_touch_time = Time.get_ticks_msec() / 1000.0
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_cam_dist(_cam_dist - 3.0)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_cam_dist(_cam_dist + 3.0)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_orbit = event.pressed
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_pan = event.pressed
			return
	if event is InputEventMouseMotion:
		_last_touch_time = Time.get_ticks_msec() / 1000.0
		if _mouse_orbit:
			_apply_orbit(event.relative)
		elif _mouse_pan:
			_pan_camera(event.relative)
		else:
			_update_hover(event.position)
		return

	if event is InputEventScreenTouch:
		_last_touch_time = Time.get_ticks_msec() / 1000.0
		if event.pressed:
			_touch_points[event.index] = event.position
			# A press inside the bottom tray never becomes a camera-orbit
			# drag, even if it misses every swatch (margin touches happen).
			if _tray and _tray.visible and _tray.get_global_rect().has_point(event.position):
				_tray_locked_touches[event.index] = true
		else:
			_touch_points.erase(event.index)
			_tray_locked_touches.erase(event.index)
			_last_pinch_distance = 0.0
			_last_pan_midpoint = Vector2.ZERO
		# Re-latch on every press/release so a lift mid-gesture (two fingers →
		# one) hands control back to the orbit cleanly, and a second finger
		# landing claims the gesture as a pan before any more rotation applies.
		_latch_gesture()
		return

	if event is InputEventScreenDrag and _touch_points.has(event.index):
		_last_touch_time = Time.get_ticks_msec() / 1000.0
		_touch_points[event.index] = event.position
		if _gesture == 1:
			# One-finger orbit — engages only after a small drag slop so a
			# second finger landing right after can still claim the gesture
			# as a pan. Magnetic snap into perfect Top / Front / Side views
			# (~5° margin) stays.
			var drag := event as InputEventScreenDrag
			_orbit_slop_accum += drag.relative.length()
			if _orbit_slop_accum >= ORBIT_SLOP and not _any_block_grabbing() \
					and not _tray_locked_touches.has(event.index):
				_apply_orbit(drag.relative)
		elif _gesture == 2:
			var points := _touch_points.values()
			var p0: Vector2 = points[0]
			var p1: Vector2 = points[1]
			var distance := p0.distance_to(p1)
			var midpoint := (p0 + p1) / 2.0

			if _last_pinch_distance > 0.0:
				var delta_dist := distance - _last_pinch_distance
				_set_cam_dist(_cam_dist - delta_dist * 0.08)
				# Two-finger drag pans ALONG THE GROUND (both fingers move
				# together): the scene follows the fingers.
				if _last_pan_midpoint != Vector2.ZERO:
					_pan_camera(midpoint - _last_pan_midpoint)

			_last_pinch_distance = distance
			_last_pan_midpoint = midpoint
		else:
			_last_pinch_distance = 0.0
			_last_pan_midpoint = Vector2.ZERO


## Latch the camera gesture from the current touch set. Two fingers down =
## pan/zoom — and any orbit that fired while the second finger was landing is
## undone (the rotation is restored to where it was when the first finger
## pressed): a two-finger gesture must never rotate. One finger = orbit.
func _latch_gesture() -> void:
	var n := _touch_points.size()
	if n >= 2 and not _any_block_grabbing():
		_pivot.rotation = _rot_latch
		_gesture = 2
		_last_pinch_distance = 0.0
		_last_pan_midpoint = Vector2.ZERO
	elif n == 1 and not _any_block_grabbing() \
			and not _tray_locked_touches.has(_touch_points.keys()[0]):
		_gesture = 1
		_orbit_slop_accum = 0.0
		_rot_latch = _pivot.rotation
	else:
		_gesture = 0
		_orbit_slop_accum = 0.0


func _apply_orbit(relative: Vector2) -> void:
	_pivot.rotation.y -= relative.x * 0.005
	# Pitch never goes above level (0.0): a positive pitch drops the camera
	# BELOW the earth slab's top plane, where the near plane slices the slab
	# and the hollow interior shows sky (BUILD 23 camera-clip bug).
	_pivot.rotation.x = clampf(_pivot.rotation.x - relative.y * 0.005, -PI / 2.0, 0.0)

	# Magnetic snap to 90° increments.
	var snap_margin := 0.087  # ~5 degrees
	var snap_step := PI / 2.0
	var target_x: float = round(_pivot.rotation.x / snap_step) * snap_step
	if absf(_pivot.rotation.x - target_x) < snap_margin:
		_pivot.rotation.x = target_x
	var target_y: float = round(_pivot.rotation.y / snap_step) * snap_step
	if absf(_pivot.rotation.y - target_y) < snap_margin:
		_pivot.rotation.y = target_y


## Perspective dolly: set the orbit distance (clamped) and move the camera
## along its view axis (local +Z — the camera looks down its -Z at the pivot).
func _set_cam_dist(d: float) -> void:
	_cam_dist = clampf(d, CAM_DIST_MIN, CAM_DIST_MAX)
	_camera.position.z = _cam_dist


## Pan the camera rig along the ground plane: screen delta → world units via
## the ortho size, directions from the pivot basis (Y-flattened). The ground
## follows the fingers: drag right → ground moves right (camera translates
## -right). Screen Y grows DOWNWARD while the ground's "up" is +up, so the Y
## term is NEGATED: drag up → ground moves up, drag down → ground moves down.
func _pan_camera(pan_delta: Vector2) -> void:
	var basis := _pivot.global_transform.basis
	var right := Vector3(basis.x.x, 0.0, basis.x.z)
	if right.length() > 0.01:
		right = right.normalized()
	var up := Vector3(basis.y.x, 0.0, basis.y.z)
	if up.length() > 0.01:
		up = up.normalized()
	var vp_h := float(get_viewport().get_visible_rect().size.y)
	# Perspective: world height at the pivot plane = 2 * dist * tan(fov/2).
	var world_per_px := 2.0 * _cam_dist * tan(deg_to_rad(_camera.fov) * 0.5) / vp_h
	_pivot.position += (-pan_delta.x * right + pan_delta.y * up) * world_per_px
	# Keep the view center on the slab: the camera rides 24 units behind it,
	# so an unclamped pan can push the camera INTO the slab volume (near-plane
	# slices + backface-culled interior — the BUILD 23 camera-clip bug).
	_pivot.position.x = clampf(_pivot.position.x, -PAN_CLAMP, PAN_CLAMP)
	_pivot.position.z = clampf(_pivot.position.z, -PAN_CLAMP, PAN_CLAMP)


## Hover inspection (desktop driving): raycast from the cursor against each
## diorama block's mesh AABB (the GLBs have no colliders — pure visuals) and
## show the BLOCKS entry: index, type, rotation, position.
func _update_hover(screen_pos: Vector2) -> void:
	var n := _hover_pick(screen_pos)
	if n == null or _hover_label == null:
		if _hover_label != null:
			_hover_label.visible = false
		return
	var nm := String(n.name)
	var idx := -1
	var us := nm.rfind("_")
	if us >= 0 and us < nm.length() - 1:
		idx = nm.substr(us + 1).to_int()
	var typ := nm.substr(0, us) if us >= 0 else nm
	_hover_label.text = "idx %d · %s\nrot %s°   pos (%.2f, %.2f, %.2f)" % [
		idx, typ,
		snapped(rad_to_deg(n.rotation.y), 1.0),
		n.position.x, n.position.y, n.position.z]
	_hover_label.visible = true


func _hover_pick(screen_pos: Vector2) -> Node3D:
	if _diorama == null or _camera == null:
		return null
	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var best: Node3D = null
	var best_t := INF
	for c in _diorama.get_children():
		var n := c as Node3D
		if n == null:
			continue
		var mis := n.find_children("*", "MeshInstance3D", true, false)
		if mis.is_empty():
			continue
		var mi := mis[0] as MeshInstance3D
		var mesh := mi.mesh
		if mesh == null:
			continue
		var aabb := mesh.get_aabb()
		var inv := (n.global_transform * mi.transform).affine_inverse()
		var t := _ray_aabb_t(inv * from, inv.basis * dir, aabb)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = n
	return best


func _ray_aabb_t(origin: Vector3, dir: Vector3, aabb: AABB) -> float:
	var tmin := 0.0
	var tmax := INF
	for axis in 3:
		var o := origin[axis]
		var d := dir[axis]
		var lo := aabb.position[axis]
		var hi := aabb.position[axis] + aabb.size[axis]
		if absf(d) < 1e-8:
			if o < lo or o > hi:
				return -1.0
		else:
			var t1 := (lo - o) / d
			var t2 := (hi - o) / d
			if t1 > t2:
				var tmp := t1
				t1 = t2
				t2 = tmp
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax:
				return -1.0
	return tmin


# ============================================================================
# MESSAGE CARDS + RESTART
# ============================================================================

func _show_message(text: String, duration: float) -> void:
	_message_label.text = text
	_message_card.visible = true
	_message_card.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_message_card, "modulate:a", 1.0, 0.3)
	tween.tween_interval(duration)
	tween.tween_property(_message_card, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): _message_card.visible = false)


func _open_blueprint() -> void:
	# Rebuild the views from the current structure's data.
	_plan_view.set_data(STRUCTS.plan_layers(_st), STRUCTS.elevation_cells(_st), _st["colors"])
	_elev_view.set_data(STRUCTS.plan_layers(_st), STRUCTS.elevation_cells(_st), _st["colors"])
	_blueprint_sheet.visible = true


func _restart_arc() -> void:
	_atlas_card.visible = false
	_message_card.visible = false
	_epilogue_card.visible = false
	for block in get_tree().get_nodes_in_group("world_blocks"):
		block.queue_free()
	for mound in dust_mounds.values():
		if is_instance_valid(mound):
			mound.queue_free()
	dust_mounds.clear()
	completed_cells.clear()
	_arc_completed = false
	_pivot.rotation = _default_cam_rot
	_pivot.position = Vector3.ZERO
	_sun.light_energy = 1.4
	_sun.light_color = Color("#FFF2D0")
	_set_cam_dist(_base_cam_dist)
	set_tool(Tool.SINGLE)
	_build_baseplate()
	_start_beat(Beat.RAISING)


# ============================================================================
# BLUEPRINT VIEW (pure data → drawing, no eyeballing)
# ============================================================================

var _plan_view: BlueprintView
var _elev_view: BlueprintView

class BlueprintView:
	extends Control

	const MODE_PLAN := 0
	const MODE_ELEVATION := 1

	var mode := MODE_PLAN
	var plan: Dictionary = {}   # {y: {Vector2i: color_name}}
	var elevation: Dictionary = {}  # {Vector2i(z,y): color_name}
	var colors: Dictionary = {}

	func set_data(p: Dictionary, e: Dictionary, c: Dictionary) -> void:
		plan = p
		elevation = e
		colors = c
		queue_redraw()

	func _draw() -> void:
		var cell := 40.0
		# Determine footprint extents from the plan layers for centering.
		var min_x := 0
		var max_x := 0
		var min_z := 0
		var max_z := 0
		var first := true
		for y in plan:
			for cp in plan[y]:
				if first:
					min_x = cp.x; max_x = cp.x; min_z = cp.y; max_z = cp.y
					first = false
				else:
					min_x = mini(min_x, cp.x); max_x = maxi(max_x, cp.x)
					min_z = mini(min_z, cp.y); max_z = maxi(max_z, cp.y)
		var span_x := maxi(max_x - min_x + 1, 1)
		var span_z := maxi(max_z - min_z + 1, 1)

		if mode == MODE_PLAN:
			# Stack layers top-down; center the footprint in the view.
			var layers := plan.keys()
			layers.sort()
			var origin := Vector2(
				(size.x - span_x * cell) / 2.0,
				(size.y - span_z * cell) / 2.0 - 20.0
			)
			for y in layers:
				var cells: Dictionary = plan[y]
				var shade := 0.85 - (0.25 * float(y))
				for cell_pos in cells:
					# NOTE: plan keys are Vector2i(pos.x, pos.z) — cell_pos.y is the z coord.
					var color: Color = colors[cells[cell_pos]]
					color = Color(color.r * shade, color.g * shade, color.b * shade)
					var rect := Rect2(origin + Vector2((cell_pos.x - min_x) * cell, (cell_pos.y - min_z) * cell), Vector2(cell, cell))
					draw_rect(rect, color, true)
					draw_rect(rect, Color(0, 0, 0, 0.35), false, 2.0)
				origin.x += 10.0  # layer offset for a slight exploded look
				origin.y += 10.0
		else:
			# Elevation: (z, y) cells → column grid, east face.
			var origin := Vector2(
				(size.x - span_z * cell) / 2.0,
				size.y - 40.0
			)
			for cell_pos in elevation:
				var color: Color = colors[elevation[cell_pos]]
				var rect := Rect2(origin + Vector2((cell_pos.x - min_z) * cell, -cell_pos.y * cell), Vector2(cell, cell))
				draw_rect(rect, color, true)
				draw_rect(rect, Color(0, 0, 0, 0.35), false, 2.0)
			# Ground line
			draw_line(origin + Vector2(-30, 0), origin + Vector2(span_z * cell + 30, 0), Color(0.7, 0.6, 0.4, 0.9), 4.0)
