extends Node3D
## mastaba_slice.gd — Core-loop playtest slice: the four-beat biography arc
## (Raising → Restoration → Decay → Excavation) on the Mastaba of Ti.
## Validates the GDD v0.4 loop + scaffolding + blueprint presentation.

const SliceBlock = preload("res://slice/slice_block.gd")
const DATA = preload("res://slice/mastaba_data.gd")

enum Beat { RAISING, RESTORATION, DECAY, EXCAVATION }
enum Scaffold { GHOST, GHOST_PARTIAL, PLAN_ONLY }

const BEAT_TITLE := {
	Beat.RAISING: "BEAT 1 · THE RAISING",
	Beat.RESTORATION: "BEAT 2 · THE RESTORATION",
	Beat.DECAY: "THE FALL",
	Beat.EXCAVATION: "BEAT 4 · THE EXCAVATION",
}

const SITE_NAME := "Mastaba of Ti — Saqqara, Egypt · ~2400 BCE"

const EPILOGUE_LINES := [
	"The Moving Finger writes; and, having writ,",
	"Moves on: nor all thy Piety nor Wit",
	"Shall lure it back to cancel half a Line,",
	"Nor all thy Tears wash out a Word of it.",
	"— Omar Khayyam",
	"",
	"These are the works of man.",
	"This is the sum of our ambition.",
	"— Sting, \"Mad About You\"",
	"",
	"The mastaba of Ti stood for 4,500 years",
	"before the sand took it back.",
]

var current_beat: Beat = Beat.RAISING
var scaffold_mode: Scaffold = Scaffold.GHOST

## Target for the current build beat: {Vector3i: color_name}
var build_target: Dictionary = {}
## Correctly completed cells: {Vector3i: color_name}
var completed_cells: Dictionary = {}
## Live block nodes: cell -> SliceBlock
var live_blocks: Dictionary = {}
## Dust mounds waiting to be cleared (excavation beat).
var dust_mounds: Dictionary = {}

var _palette: Array[String] = []
var _current_swatch := ""
var _is_orchestrating := false   # beat transition in flight (input locked)
var _dust_total := 0
var _dust_cleared := 0

# --- Camera ---
var _pivot: Node3D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _touch_points := {}
var _last_pinch_distance := 0.0
var _last_pan_midpoint := Vector2.ZERO

# --- HUD ---
var _hud: CanvasLayer
var _top_label: Label
var _beat_label: Label
var _progress_bar: ProgressBar
var _swatch_box: HBoxContainer
var _scaffold_buttons: Array[Button] = []
var _message_card: PanelContainer
var _message_label: Label
var _epilogue_card: PanelContainer
var _epilogue_label: RichTextLabel
var _blueprint_sheet: Control
var _atlas_card: PanelContainer
var _skip_btn: Button

var _baseplate: Node3D
var _floor_body: StaticBody3D


func _ready() -> void:
	_build_world()
	_build_hud()
	_start_beat(Beat.RAISING)


# ============================================================================
# WORLD
# ============================================================================

func _build_world() -> void:
	# --- Camera pivot (isometric default) ---
	_pivot = Node3D.new()
	_pivot.name = "CameraPivot"
	add_child(_pivot)
	_pivot.rotation = Vector3(-0.45, 0.8, 0.0)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 14.0
	_camera.position = Vector3(0, 0, 14)
	_pivot.add_child(_camera)

	# --- Sun ---
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.position = Vector3(6, 10, 4)
	add_child(_sun)
	_sun.look_at(Vector3.ZERO)
	_sun.light_color = Color("#FFF2D0")
	_sun.light_energy = 1.4

	# --- Soft ambient fill ---
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.position = Vector3(-4, 6, -6)
	add_child(fill)
	fill.look_at(Vector3.ZERO)
	fill.light_color = Color("#C8D8F0")
	fill.light_energy = 0.5

	# --- Environment (warm sky) ---
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("#8FC1E8")
	sky.sky_horizon_color = Color("#F2DFB8")
	sky.ground_bottom_color = Color("#8A7A60")
	sky.ground_horizon_color = Color("#E8D5AC")
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.6
	env.environment = environment
	add_child(env)

	# --- Floor (raycast target + sand) ---
	_floor_body = StaticBody3D.new()
	_floor_body.name = "Floor"
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(60, 1, 60)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0, -0.5, 0)
	_floor_body.add_child(floor_shape)
	add_child(_floor_body)

	var floor_mesh := MeshInstance3D.new()
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#D9C089")
	floor_mat.roughness = 1.0
	var floor_box_mesh := BoxMesh.new()
	floor_box_mesh.size = Vector3(60, 1, 60)
	floor_mesh.mesh = floor_box_mesh
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(0, -0.5, 0)
	add_child(floor_mesh)

	# --- Baseplate tiles (build footprint marker) ---
	_baseplate = Node3D.new()
	_baseplate.name = "Baseplate"
	add_child(_baseplate)
	_build_baseplate()


func _build_baseplate() -> void:
	for child in _baseplate.get_children():
		child.queue_free()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#BFA26B")
	mat.roughness = 1.0
	for bx in range(-int(DATA.LIMIT_X), int(DATA.LIMIT_X) + 1):
		for bz in range(-int(DATA.LIMIT_Z), int(DATA.LIMIT_Z) + 1):
			var tile := MeshInstance3D.new()
			var tile_mesh := BoxMesh.new()
			tile_mesh.size = Vector3(0.98, 0.05, 0.98)
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

	# --- Top bar ---
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 12
	top.offset_bottom = 96
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.12, 0.18, 0.85)))
	root.add_child(top)

	var top_box := VBoxContainer.new()
	top.add_child(top_box)

	_beat_label = Label.new()
	_beat_label.add_theme_font_size_override("font_size", 16)
	_beat_label.add_theme_color_override("font_color", Color("#F0C040"))
	top_box.add_child(_beat_label)

	_top_label = Label.new()
	_top_label.text = SITE_NAME
	_top_label.add_theme_font_size_override("font_size", 18)
	top_box.add_child(_top_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 14)
	_progress_bar.show_percentage = false
	top_box.add_child(_progress_bar)

	# --- Scaffold toggle row (top-right, under top bar) ---
	var scaffold_row := HBoxContainer.new()
	scaffold_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	scaffold_row.offset_left = 12
	scaffold_row.offset_right = -12
	scaffold_row.offset_top = 104
	scaffold_row.offset_bottom = 140
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
		btn.custom_minimum_size = Vector2(0, 40)
		btn.toggle_mode = true
		btn.pressed.connect(_on_scaffold_pressed.bind(def[1], btn))
		scaffold_row.add_child(btn)
		_scaffold_buttons.append(btn)

	# --- Blueprint button ---
	var plan_btn := Button.new()
	plan_btn.text = "📜  Excavation File"
	plan_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	plan_btn.offset_left = -190
	plan_btn.offset_right = -12
	plan_btn.offset_top = 150
	plan_btn.offset_bottom = 192
	plan_btn.pressed.connect(_open_blueprint)
	root.add_child(plan_btn)

	# --- Restart button ---
	var restart_btn := Button.new()
	restart_btn.text = "↺ Restart"
	restart_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	restart_btn.offset_left = 12
	restart_btn.offset_top = 150
	restart_btn.offset_bottom = 192
	restart_btn.pressed.connect(_restart_arc)
	root.add_child(restart_btn)

	# --- Palette tray (bottom) ---
	var tray := PanelContainer.new()
	tray.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tray.offset_left = 12
	tray.offset_right = -12
	tray.offset_top = -104
	tray.offset_bottom = -12
	tray.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.12, 0.18, 0.9)))
	root.add_child(tray)

	_swatch_box = HBoxContainer.new()
	_swatch_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_swatch_box.add_theme_constant_override("separation", 14)
	tray.add_child(_swatch_box)

	# --- Message card (beat banners, flourishes) ---
	_message_card = PanelContainer.new()
	_message_card.set_anchors_preset(Control.PRESET_CENTER)
	_message_card.offset_left = -320
	_message_card.offset_right = 320
	_message_card.offset_top = -180
	_message_card.offset_bottom = 180
	_message_card.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.08, 0.14, 0.88)))
	_message_card.visible = false
	_message_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_message_card)

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", 26)
	_message_label.custom_minimum_size = Vector2(560, 0)
	_message_card.add_child(_message_label)

	# --- Epilogue card (decay beat) ---
	_epilogue_card = PanelContainer.new()
	_epilogue_card.set_anchors_preset(Control.PRESET_CENTER)
	_epilogue_card.offset_left = -340
	_epilogue_card.offset_right = 340
	_epilogue_card.offset_top = -260
	_epilogue_card.offset_bottom = 260
	_epilogue_card.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.06, 0.1, 0.92)))
	_epilogue_card.visible = false
	_epilogue_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_epilogue_card)

	_epilogue_label = RichTextLabel.new()
	_epilogue_label.bbcode_enabled = true
	_epilogue_label.fit_content = true
	_epilogue_label.scroll_active = false
	_epilogue_label.add_theme_font_size_override("normal_font_size", 22)
	_epilogue_label.custom_minimum_size = Vector2(600, 0)
	_epilogue_card.add_child(_epilogue_label)

	# --- Skip button (decay only) ---
	_skip_btn = Button.new()
	_skip_btn.text = "Skip ▸"
	_skip_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_skip_btn.offset_left = -80
	_skip_btn.offset_right = 80
	_skip_btn.offset_top = -110
	_skip_btn.offset_bottom = -60
	_skip_btn.visible = false
	_skip_btn.pressed.connect(_skip_decay)
	root.add_child(_skip_btn)

	# --- Blueprint sheet (modal) ---
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
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.offset_left = -420
	sheet.offset_right = 420
	sheet.offset_top = -420
	sheet.offset_bottom = 420
	sheet.add_theme_stylebox_override("panel", _panel_style(Color(0.13, 0.13, 0.2, 0.96)))
	_blueprint_sheet.add_child(sheet)

	var sheet_box := VBoxContainer.new()
	sheet_box.add_theme_constant_override("separation", 10)
	sheet.add_child(sheet_box)

	var sheet_title := Label.new()
	sheet_title.text = "Excavation File — Mastaba of Ti"
	sheet_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet_title.add_theme_font_size_override("font_size", 22)
	sheet_box.add_child(sheet_title)

	var sheet_grid := GridContainer.new()
	sheet_grid.columns = 2
	sheet_grid.add_theme_constant_override("h_separation", 24)
	sheet_box.add_child(sheet_grid)

	sheet_grid.add_child(_make_view_label("PLAN (top-down)"))
	sheet_grid.add_child(_make_view_label("ELEVATION (east face)"))

	var plan_view := BlueprintView.new()
	plan_view.custom_minimum_size = Vector2(360, 300)
	plan_view.mode = BlueprintView.MODE_PLAN
	sheet_grid.add_child(plan_view)

	var elev_view := BlueprintView.new()
	elev_view.custom_minimum_size = Vector2(360, 300)
	elev_view.mode = BlueprintView.MODE_ELEVATION
	sheet_grid.add_child(elev_view)

	plan_view.set_data(DATA.plan_layers(), DATA.elevation_cells())
	elev_view.set_data(DATA.plan_layers(), DATA.elevation_cells())

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.pressed.connect(func(): _blueprint_sheet.visible = false)
	sheet_box.add_child(close_btn)

	# --- Memory Atlas card (end of arc) ---
	_atlas_card = PanelContainer.new()
	_atlas_card.set_anchors_preset(Control.PRESET_CENTER)
	_atlas_card.offset_left = -340
	_atlas_card.offset_right = 340
	_atlas_card.offset_top = -260
	_atlas_card.offset_bottom = 260
	_atlas_card.add_theme_stylebox_override("panel", _panel_style(Color(0.1, 0.12, 0.16, 0.95)))
	_atlas_card.visible = false
	root.add_child(_atlas_card)

	var atlas_box := VBoxContainer.new()
	atlas_box.add_theme_constant_override("separation", 14)
	_atlas_card.add_child(atlas_box)

	var atlas_title := Label.new()
	atlas_title.text = "MEMORY ATLAS"
	atlas_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atlas_title.add_theme_font_size_override("font_size", 30)
	atlas_box.add_child(atlas_title)

	var atlas_sub := Label.new()
	atlas_sub.text = "What the Builder remembers — saved."
	atlas_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atlas_sub.add_theme_color_override("font_color", Color("#C8D8F0"))
	atlas_sub.add_theme_font_size_override("font_size", 16)
	atlas_box.add_child(atlas_sub)

	var entry1 := Label.new()
	entry1.text = "◈ The Zenith — Mastaba of Ti, at its peak (limestone, cornice, offering table)"
	entry1.add_theme_font_size_override("font_size", 18)
	atlas_box.add_child(entry1)

	var entry2 := Label.new()
	entry2.text = "◈ Today — the excavated foundation, as the sand gave it back"
	entry2.add_theme_font_size_override("font_size", 18)
	atlas_box.add_child(entry2)

	var showcase_btn := Button.new()
	showcase_btn.text = "◉ Orbit Showcase"
	showcase_btn.custom_minimum_size = Vector2(0, 44)
	showcase_btn.pressed.connect(_orbit_showcase)
	atlas_box.add_child(showcase_btn)

	var replay_btn := Button.new()
	replay_btn.text = "↺ Replay the Arc"
	replay_btn.custom_minimum_size = Vector2(0, 44)
	replay_btn.pressed.connect(_restart_arc)
	atlas_box.add_child(replay_btn)

	var more_label := Label.new()
	more_label.text = "More structures coming in the full game."
	more_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	more_label.add_theme_color_override("font_color", Color("#8A8A9A"))
	more_label.add_theme_font_size_override("font_size", 14)
	atlas_box.add_child(more_label)


func _make_view_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("#F0C040"))
	l.add_theme_font_size_override("font_size", 15)
	return l


func _panel_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.45, 0.6, 0.9, 0.6)
	return sb


# ============================================================================
# BEAT MACHINE
# ============================================================================

func _start_beat(beat: Beat) -> void:
	current_beat = beat
	_beat_label.text = BEAT_TITLE[beat]
	_is_orchestrating = false
	_skip_btn.visible = false
	_epilogue_card.visible = false
	_epilogue_label.text = ""

	# Determine build target + palette.
	match beat:
		Beat.RAISING:
			build_target = DATA.CORE_CELLS.duplicate()
			_palette = ["mudbrick"]
			_show_message("Raise the mastaba.\nThe tomb must rise from the sand.", 2.2)
		Beat.RESTORATION:
			build_target = DATA.ZENITH_CELLS.duplicate()
			_palette = ["mudbrick", "limestone", "redband"]
			_show_message("The tomb stands. Now restore it to its zenith —\nlimestone, cornice, offering table.", 2.6)
		Beat.DECAY:
			_run_decay()
			return
		Beat.EXCAVATION:
			build_target = {}
			_palette = []
			_show_message("The sand has done its work.\nNow the earth gives it back.", 2.4)
			_spawn_dust()

	_rebuild_palette()
	_refresh_ghosts()
	_update_progress()


func _on_block_placed(pos: Vector3i, color_name: String) -> void:
	if _is_orchestrating:
		return
	# A block landed on a target cell with the right material → count it.
	if build_target.has(pos) and build_target[pos] == color_name and not completed_cells.has(pos):
		completed_cells[pos] = color_name
		_refresh_ghosts()
		_update_progress()
		_check_beat_complete()
	else:
		# Wrong cell/material: flash red and remove.
		var block := _find_block_at(pos)
		if block:
			var tween := create_tween()
			tween.tween_method(
				func(a: float): block.set_block_color(Color(0.9, 0.25, 0.2).lerp(block.block_color, a), color_name),
				0.0, 1.0, 0.35)
			tween.tween_callback(block.queue_free)


func _find_block_at(pos: Vector3i) -> SliceBlock:
	for block in get_tree().get_nodes_in_group("slice_blocks"):
		var b := block as SliceBlock
		if is_instance_valid(b) and b.current_grid_position == pos and b.is_placed:
			return b
	return null


func _on_block_removed(pos: Vector3i) -> void:
	completed_cells.erase(pos)
	live_blocks.erase(pos)
	_refresh_ghosts()
	_update_progress()


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
	match current_beat:
		Beat.RAISING:
			_show_message("The mastaba is raised.\nThe house of eternity stands.", 2.4)
			await get_tree().create_timer(2.6).timeout
			_start_beat(Beat.RESTORATION)
		Beat.RESTORATION:
			_show_message("The tomb shines at its zenith.\nTime now does its work.", 2.6)
			await get_tree().create_timer(2.8).timeout
			_start_beat(Beat.DECAY)


## Flourish: sun brightens + camera breathes out + progress hits 100%.
func _flourish() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sun, "light_energy", 1.9, 1.0)
	tween.tween_property(_camera, "size", _camera.size + 1.5, 1.2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(_camera, "size", 14.0, 1.0)


# ============================================================================
# DECAY (Beat 3 — cinematic, non-interactive)
# ============================================================================

func _run_decay() -> void:
	_is_orchestrating = true
	_palette = []
	_rebuild_palette()
	_clear_ghosts()

	_beat_label.text = BEAT_TITLE[Beat.DECAY]
	_epilogue_card.visible = true
	_skip_btn.visible = true
	_epilogue_label.text = "[center]" + "\n".join(EPILOGUE_LINES) + "[/center]"

	# Epilogue fades in.
	var fade := create_tween()
	_epilogue_card.modulate.a = 0.0
	fade.tween_property(_epilogue_card, "modulate:a", 1.0, 1.5)

	# Sun sets: rotate + cool toward dusk over the whole decay.
	var sun_tween := create_tween()
	sun_tween.set_parallel(true)
	sun_tween.tween_property(_sun, "rotation_degrees", Vector3(-70, 210, 0), 9.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sun_tween.tween_property(_sun, "light_color", Color("#E8A06A"), 9.0)

	# Blocks crumble tier by tier: zenith first, then upper core, then base.
	var blocks := get_tree().get_nodes_in_group("slice_blocks") as Array
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
		# Deterministic jitter so the fall feels organic, not simultaneous.
		var jitter := float(abs(b.current_grid_position.x + b.current_grid_position.z) % 3) * 0.4
		b.decay_sink(tier_delay + jitter, 1.4)

	await get_tree().create_timer(10.0).timeout

	# Mound: a few low weathered rubble blocks where the structure stood.
	_spawn_mound()

	await get_tree().create_timer(2.0).timeout
	_start_beat(Beat.EXCAVATION)


func _skip_decay() -> void:
	_epilogue_card.visible = false
	_skip_btn.visible = false
	# Kill remaining blocks fast (tween to ground + fade).
	for block in get_tree().get_nodes_in_group("slice_blocks"):
		if is_instance_valid(block):
			block.decay_sink(0.0, 0.4)
	_spawn_mound()
	await get_tree().create_timer(0.8).timeout
	_start_beat(Beat.EXCAVATION)


func _spawn_mound() -> void:
	var rubble_positions := [
		Vector3i(-1, 0, -1), Vector3i(1, 0, 1), Vector3i(0, 0, 0),
		Vector3i(2, 0, 0), Vector3i(-2, 0, 1),
	]
	for pos in rubble_positions:
		var block := SliceBlock.new()
		block.name = "Rubble"
		add_child(block)
		block.limit_x = DATA.LIMIT_X
		block.limit_z = DATA.LIMIT_Z
		block.limit_y = DATA.LIMIT_Y
		block.freeze = true
		block.gravity_scale = 0.0
		block.set_block_color(Color("#8A7A5E"), "rubble")
		block.position = Vector3(pos.x, 0.25, pos.z)
		block.scale = Vector3(0.7, 0.4, 0.7)
		block.rotation = Vector3(0, (pos.x * 0.7) + pos.z, 0)
		for child in block.get_children():
			if child is CollisionShape3D:
				child.disabled = true
		block.remove_from_group("slice_blocks")  # never draggable
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
	var dust_cells := DATA.dust_cells()
	_dust_total = dust_cells.size()
	var dust_mat := ShaderMaterial.new()
	dust_mat.resource_local_to_scene = true
	dust_mat.shader = load("res://block.gdshader")
	dust_mat.set_shader_parameter("albedo_color", DATA.COLORS["dust"])
	dust_mat.set_shader_parameter("alpha", 0.55)

	for pos in dust_cells:
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
		mesh.material_override = dust_mat
		mound.add_child(mesh)

		mound.input_event.connect(_on_dust_tapped.bind(pos))
		dust_mounds[pos] = mound

	_update_progress()


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

	# Reveal the survivor beneath.
	var color_name: String = DATA.SURVIVOR_CELLS[pos]
	var reveal := SliceBlock.new()
	reveal.name = "Survivor"
	add_child(reveal)
	reveal.limit_x = DATA.LIMIT_X
	reveal.limit_z = DATA.LIMIT_Z
	reveal.limit_y = DATA.LIMIT_Y
	reveal.place_at(pos, DATA.COLORS[color_name], color_name)
	reveal.remove_from_group("slice_blocks")
	for child in reveal.get_children():
		if child is CollisionShape3D:
			child.disabled = true

	# Dust mound fades and shrinks away.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		func(a: float):
			if is_instance_valid(mound):
				(mound.get_child(1) as MeshInstance3D).material_override = dust_mat_alpha(a),
		0.55, 0.0, 0.35)
	tween.tween_property(mound, "scale", Vector3(0.05, 0.05, 0.05), 0.35)
	tween.tween_callback(mound.queue_free)

	# Reveal pop.
	var pop := create_tween()
	reveal.scale = Vector3(0.2, 0.2, 0.2)
	pop.tween_property(reveal, "scale", Vector3.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	Input.vibrate_handheld(30)
	_update_progress()

	if dust_mounds.is_empty():
		await get_tree().create_timer(0.8).timeout
		_show_atlas_card()


func dust_mat_alpha(a: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.resource_local_to_scene = true
	m.shader = load("res://block.gdshader")
	m.set_shader_parameter("albedo_color", DATA.COLORS["dust"])
	m.set_shader_parameter("alpha", a)
	return m


func _show_atlas_card() -> void:
	_is_orchestrating = true
	_beat_label.text = "SAVED TO MEMORY"
	_atlas_card.visible = true
	_atlas_card.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_atlas_card, "modulate:a", 1.0, 0.6)


func _orbit_showcase() -> void:
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:y", _pivot.rotation.y + TAU, 8.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _restart_arc() -> void:
	_atlas_card.visible = false
	_message_card.visible = false
	_epilogue_card.visible = false
	for block in get_tree().get_nodes_in_group("slice_blocks"):
		block.queue_free()
	for mound in dust_mounds.values():
		if is_instance_valid(mound):
			mound.queue_free()
	dust_mounds.clear()
	completed_cells.clear()
	live_blocks.clear()
	_pivot.rotation = Vector3(-0.45, 0.8, 0.0)
	_sun.light_energy = 1.4
	_sun.light_color = Color("#FFF2D0")
	_camera.size = 14.0
	_build_baseplate()
	_start_beat(Beat.RAISING)


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
		btn.custom_minimum_size = Vector2(96, 64)
		btn.text = color_name.replace("_", " ")
		btn.add_theme_font_size_override("font_size", 13)
		var sb := StyleBoxFlat.new()
		sb.bg_color = DATA.COLORS[color_name]
		sb.corner_radius_top_left = 10
		sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_left = 10
		sb.corner_radius_bottom_right = 10
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
		sb.border_color = Color(1, 0.85, 0.2) if color_name == _current_swatch else Color(0, 0, 0, 0.4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.pressed.connect(_on_swatch_pressed.bind(color_name, btn))
		_swatch_box.add_child(btn)


func _on_swatch_pressed(color_name: String, btn: Button) -> void:
	_current_swatch = color_name
	for child in _swatch_box.get_children():
		var style := (child as Button).get_theme_stylebox("normal")
		if style is StyleBoxFlat:
			style.border_color = Color(1, 0.85, 0.2) if child.name == btn.name else Color(0, 0, 0, 0.4)
	# Spawn a fresh block in hand from the palette.
	_spawn_block_in_hand(color_name)


## Tap the palette → a block appears at the tap point, held for dragging.
func _spawn_block_in_hand(color_name: String) -> void:
	if _is_orchestrating or _palette.is_empty():
		return
	var block := SliceBlock.new()
	add_child(block)
	block.limit_x = DATA.LIMIT_X
	block.limit_z = DATA.LIMIT_Z
	block.limit_y = DATA.LIMIT_Y
	block.set_block_color(DATA.COLORS[color_name], color_name)
	block.global_position = Vector3(0, 3, 0)
	block.placed.connect(_on_block_placed)
	block.removed.connect(_on_block_removed)
	var viewport := get_viewport()
	var center := viewport.get_visible_rect().size / 2.0
	block._start_drag(-1, center)


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
			# Partial: ghost only the bottom two layers.
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
		mat.shader = load("res://block.gdshader")
		mat.set_shader_parameter("albedo_color", DATA.COLORS[cells[pos]])
		mat.set_shader_parameter("alpha", 0.22)
		var box := BoxMesh.new()
		box.size = Vector3(0.94, 0.94, 0.94)
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
# MESSAGE CARDS + INPUT (orbit/pinch)
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
	_blueprint_sheet.visible = true


func _input(event: InputEvent) -> void:
	# Two-finger orbit + pinch zoom (always available, like the old ROTATE tool).
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
			_last_pinch_distance = 0.0
			_last_pan_midpoint = Vector2.ZERO

	if event is InputEventScreenDrag and _touch_points.has(event.index):
		_touch_points[event.index] = event.position
		if _touch_points.size() == 2:
			var points := _touch_points.values()
			var p0: Vector2 = points[0]
			var p1: Vector2 = points[1]
			var distance := p0.distance_to(p1)
			var midpoint := (p0 + p1) / 2.0

			if _last_pinch_distance > 0.0:
				var delta_dist := distance - _last_pinch_distance
				_camera.size = clampf(_camera.size - delta_dist * 0.05, 5.0, 30.0)

				if _last_pan_midpoint != Vector2.ZERO and distance < 140.0:
					var pan_delta := midpoint - _last_pan_midpoint
					_pivot.rotation.y -= pan_delta.x * 0.004
					_pivot.rotation.x = clampf(_pivot.rotation.x - pan_delta.y * 0.004, -1.2, -0.1)

			_last_pinch_distance = distance
			_last_pan_midpoint = midpoint
		else:
			_last_pinch_distance = 0.0
			_last_pan_midpoint = Vector2.ZERO


# ============================================================================
# BLUEPRINT VIEW (pure data → drawing, no eyeballing)
# ============================================================================

class BlueprintView:
	extends Control

	const MODE_PLAN := 0
	const MODE_ELEVATION := 1

	var mode := MODE_PLAN
	var plan: Dictionary = {}   # {y: {Vector2i: color_name}}
	var elevation: Dictionary = {}  # {Vector2i(z,y): color_name}

	func set_data(p: Dictionary, e: Dictionary) -> void:
		plan = p
		elevation = e
		queue_redraw()

	func _draw() -> void:
		var cell := 28.0
		if mode == MODE_PLAN:
			# Stack layers top-down: draw each y layer as a shaded grid.
			var layers := plan.keys()
			layers.sort()
			var origin := Vector2(30, 30)
			for y in layers:
				var cells: Dictionary = plan[y]
				var shade := 0.85 - (0.25 * float(y))
				for cell_pos in cells:
					var color: Color = DATA.COLORS[cells[cell_pos]]
					color = Color(color.r * shade, color.g * shade, color.b * shade)
					var rect := Rect2(origin + Vector2(cell_pos.x * cell, cell_pos.z * cell), Vector2(cell, cell))
					draw_rect(rect, color, true)
					draw_rect(rect, Color(0, 0, 0, 0.35), false, 1.5)
				origin.x += 10.0  # layer offset for a slight exploded look
				origin.y += 10.0
		else:
			# Elevation: (z, y) cells → column grid.
			var origin := Vector2(40, 260)
			for cell_pos in elevation:
				var color: Color = DATA.COLORS[elevation[cell_pos]]
				var rect := Rect2(origin + Vector2(cell_pos.x * cell, -cell_pos.y * cell), Vector2(cell, cell))
				draw_rect(rect, color, true)
				draw_rect(rect, Color(0, 0, 0, 0.35), false, 1.5)
			# Ground line
			draw_line(origin + Vector2(-20, 0), origin + Vector2(5 * cell + 20, 0), Color(0.7, 0.6, 0.4, 0.9), 3.0)
