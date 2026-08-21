extends Node3D
## diorama.gd — static environmental stage per structure: ground tint + floor
## texture tiles + dense prop scatter. Props are pure visuals: no physics, no
## collision, no group membership — they can never interfere with placement.
##
## Design rules (from playtest direction):
##  * AWE — the structure is the hero. Props read SMALL around it (real-world
##    relative scale vs the stylized builds). Per-prop "s" overrides tune one
##    object without touching the global table.
##  * BUSY — the floor carries texture (Kenney 1×1 ground tiles, grid-aligned
##    to the voxel cells) and the area is densely scattered out to ~3 phone
##    widths of view at normal zoom, so future large structures fit.
##  * CLEAR RING — a 1-tile perimeter around the baseplate stays free of props
##    (floor texture continues); the build stays readable.
##  * TRUE COLORS — models import with their own vertex colors. A warm filter
##    tames Kenney's neon-teal foliage (fronds read olive in desert light);
##    remove FOLIAGE_TINT for the pure pack palette.

const NATURE := "res://art/nature/"

## Kenney models are built small vs the 1-unit voxel (measured via art/measure).
## Awe rule: structures dominate — palm ≈ 3 blocks, boulder ≈ 1 block.
const MODEL_SCALE := {
	"tree_palmTall": 3.4, "tree_palmShort": 3.4, "tree_palmDetailedTall": 3.4,
	"tree_palmBend": 3.4, "tree_oak": 2.8, "tree_pineTallA": 2.8,
	"rock_largeA": 2.4, "rock_largeB": 2.4, "rock_smallA": 2.6,
	"rock_smallFlatA": 2.8, "stone_smallA": 2.6, "stone_smallFlatA": 2.8,
	"stone_tallA": 1.1, "grass": 1.6, "grass_large": 1.6, "flower_redA": 1.8,
	"flower_yellowA": 1.8, "plant_bush": 2.0, "plant_bushSmall": 2.0,
	"log": 1.5, "log_stack": 1.5, "statue_obelisk": 3.2, "statue_column": 2.8,
	"mushroom_red": 1.6, "stump_round": 1.6, "tent_smallClosed": 1.7,
	"campfire_stones": 1.8, "cactus_short": 2.2, "lily_small": 1.6,
}

## Warm khaki filter for Kenney's teal foliage (vertex-color multiply).
const FOLIAGE_TINT := Color(0.82, 0.78, 0.58)
## Shade filter for ALL diorama materials: the game light rig is hot (sun +
## fill + sky ambient ≈ 2×), which blows mid-grey albedos to white. Scaling
## down keeps floor tiles + props in readable contrast against the sand.
const SHADE := 0.68
const FOLIAGE_MODELS := [
	"tree_palm", "tree_oak", "tree_pine", "grass", "plant_bush", "crops",
	"tree_default", "tree_small", "tree_tall", "tree_thin", "tree_fat",
	"tree_blocks", "tree_cone", "tree_plateau", "tree_detailed", "tree_simple",
]

## Per-structure stage config.
##  * tiles: floor-texture mosaic from 1×1 ground tiles (grid-aligned).
##    w = relative weight, smin/smax = tile scale range (tile covers 2-3 cells).
##  * props: {m model, n count, rmin/rmax ring band, s optional per-prop
##    scale multiplier, avoid optional angle arc (deg, camera-ward) for tall props}.
const DIORAMAS := {
	"mastaba": {
		"ground_color": Color("#D9C089"),
		"tiles": [
			{"m": "ground_pathRocks",    "w": 5, "smin": 2.0, "smax": 3.5},
			{"m": "ground_pathStraight", "w": 3, "smin": 2.0, "smax": 3.0},
			{"m": "ground_grass",        "w": 1, "smin": 2.0, "smax": 3.0},
		],
		"tile_count": 150,
		"props": [
			# Tall silhouettes on the far arc only (camera sits NE ≈ 44°).
			{"m": "tree_palmTall",         "n": 4, "rmin": 9.0, "rmax": 21.0, "avoid": Vector2(15, 75)},
			{"m": "tree_palmBend",         "n": 3, "rmin": 9.0, "rmax": 17.0, "avoid": Vector2(15, 75)},
			{"m": "tree_palmShort",        "n": 3, "rmin": 6.8, "rmax": 8.8,  "avoid": Vector2(15, 75)},
			{"m": "tree_palmTall",         "n": 2, "rmin": 7.0, "rmax": 8.8,  "avoid": Vector2(15, 75), "s": 0.7},
			# Mid-ground scatter just outside the clear ring — visible framing.
			{"m": "rock_largeB",           "n": 12, "rmin": 4.5, "rmax": 13.0},
			{"m": "rock_smallA",           "n": 18, "rmin": 4.5, "rmax": 11.0},
			{"m": "stone_smallFlatA",      "n": 15, "rmin": 4.5, "rmax": 10.0},
			{"m": "stone_smallA",          "n": 9, "rmin": 4.5, "rmax": 10.0},
			{"m": "plant_bush",            "n": 14, "rmin": 4.5, "rmax": 12.0},
			{"m": "plant_bushSmall",       "n": 8, "rmin": 4.5, "rmax": 11.0},
			{"m": "grass",                 "n": 28, "rmin": 4.5, "rmax": 16.0},
			{"m": "flower_yellowA",        "n": 12, "rmin": 4.5, "rmax": 12.0},
			{"m": "flower_redA",           "n": 5, "rmin": 5.0, "rmax": 11.0},
			{"m": "cactus_short",          "n": 5, "rmin": 5.0, "rmax": 11.0},
			{"m": "stump_round",           "n": 4, "rmin": 5.0, "rmax": 11.0},
			{"m": "log",                   "n": 3, "rmin": 5.0, "rmax": 11.0},
			# Workmen's camp — a small human story at the tomb site.
			{"m": "tent_smallClosed",      "n": 1, "rmin": 7.0, "rmax": 9.0, "avoid": Vector2(15, 75)},
			{"m": "campfire_stones",       "n": 1, "rmin": 7.0, "rmax": 9.0, "avoid": Vector2(15, 75)},
		],
	},
}


## Build (or rebuild) the stage. clear_rect = no-prop zone in x/z (baseplate
## limits + 1-tile perimeter, from the slice). floor_mesh tint = ground color.
func build(structure_id: String, floor_mesh: MeshInstance3D, clear_rect: Rect2) -> void:
	for child in get_children():
		child.queue_free()
	var cfg: Dictionary = DIORAMAS.get(structure_id, {})
	if cfg.is_empty():
		return
	if floor_mesh != null and cfg.has("ground_color"):
		var mat: StandardMaterial3D = floor_mesh.material_override
		if mat != null:
			mat.albedo_color = cfg["ground_color"]

	var rng := RandomNumberGenerator.new()
	rng.seed = structure_id.hash()

	# Floor texture mosaic: 1×1 ground tiles scaled to cover 2-3 cells each,
	# anywhere except directly under the baseplate grid (limits rect).
	if cfg.has("tiles") and cfg.has("tile_count"):
		var limits_rect := Rect2(
			clear_rect.position + Vector2.ONE,
			clear_rect.size - Vector2(2, 2))
		_place_tiles(cfg, rng, limits_rect)
	_place_props(cfg, rng, clear_rect)


func _place_tiles(cfg: Dictionary, rng: RandomNumberGenerator, limits_rect: Rect2) -> void:
	var tiles: Array = cfg["tiles"]
	var total_w := 0
	for t in tiles:
		total_w += int(t["w"])
	var count := int(cfg["tile_count"])
	for i in count:
		var pick: Dictionary = tiles[rng.randi_range(0, tiles.size() - 1)]
		# Weighted pick.
		var roll := rng.randi_range(1, total_w)
		var acc := 0
		for t in tiles:
			acc += int(t["w"])
			if roll <= acc:
				pick = t
				break
		var ang: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(3.0, 24.0)
		var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		if limits_rect.has_point(Vector2(pos.x, pos.z)):
			continue
		var inst: Node3D = _spawn(pick["m"], rng, 1.0)
		# Flush with the surface: tops at y≈0.001, bodies sunk into the floor
		# (path tiles extend 0.05 below their pivot) — no floating slivers.
		inst.position = pos + Vector3(0, 0.001 + rng.randf_range(0, 0.0005), 0)
		inst.rotation = Vector3(0, rng.randi_range(0, 1) * PI / 2.0, 0)
		var s: float = rng.randf_range(float(pick["smin"]), float(pick["smax"]))
		inst.scale = Vector3.ONE * s
		add_child(inst)


func _place_props(cfg: Dictionary, rng: RandomNumberGenerator, clear_rect: Rect2) -> void:
	for entry in cfg["props"]:
		var n := int(entry["n"])
		var rmin := float(entry["rmin"])
		var rmax := float(entry["rmax"])
		var per_prop_scale := float(entry.get("s", 0.0))
		var avoid: Vector2 = entry.get("avoid", Vector2(-999, -999))
		# Keep mid-ground scatter just outside the clear ring; scales with the
		# structure footprint so big levels get proportionally more room.
		var rmin_eff := maxf(rmin, clear_rect.size.length() * 0.5 + 0.6)
		for i in n:
			for attempt in 24:
				var ang: float = rng.randf_range(0.0, TAU)
				var deg := rad_to_deg(ang)
				if deg >= avoid.x and deg <= avoid.y:
					continue
				var r: float = rng.randf_range(rmin_eff, rmax)
				var pos := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
				if clear_rect.has_point(Vector2(pos.x, pos.z)):
					continue
				var inst: Node3D = _spawn(entry["m"], rng, per_prop_scale)
				inst.position = pos
				add_child(inst)
				break


## Instantiate a model with global scale (× per-prop override) and the warm
## foliage filter when the model name matches a foliage family.
func _spawn(model_name: String, rng: RandomNumberGenerator, per_prop_scale: float) -> Node3D:
	var path := NATURE + model_name + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("diorama: missing model " + path)
		return Node3D.new()
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	inst.scale = Vector3.ONE * float(MODEL_SCALE.get(model_name, 1.0)) * per_prop_scale
	inst.rotation = Vector3(0, rng.randf_range(0.0, TAU), 0)
	_apply_tint(inst, model_name)
	return inst


func _apply_tint(inst: Node3D, model_name: String) -> void:
	var is_foliage := false
	for fam in FOLIAGE_MODELS:
		if model_name.begins_with(fam):
			is_foliage = true
			break
	var filter: Color = Color(SHADE, SHADE, SHADE)
	if is_foliage:
		filter = Color(
			FOLIAGE_TINT.r * SHADE, FOLIAGE_TINT.g * SHADE, FOLIAGE_TINT.b * SHADE)
	var stack: Array[Node3D] = [inst]
	while not stack.is_empty():
		var n: Node3D = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var mats: Array[Material] = []
			if mi.material_override != null:
				mats.append(mi.material_override)
			if mi.mesh != null:
				for s in mi.mesh.get_surface_count():
					var m := mi.mesh.surface_get_material(s)
					if m != null:
						mats.append(m)
			for m in mats:
				if m is StandardMaterial3D and (m as StandardMaterial3D).vertex_color_use_as_albedo:
					(m as StandardMaterial3D).albedo_color = filter
		for child in n.get_children():
			if child is Node3D:
				stack.push_back(child)
