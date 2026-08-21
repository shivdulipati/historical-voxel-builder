extends Node3D
## diorama.gd — static environmental stage per structure: ground + props.
## Props are pure visuals: no physics, no collision, no group membership.
##
## Design rules (from playtest direction):
##  * AWE — the structure is the hero; props read small around it.
##  * GROUND — mastaba uses the mini-arena floor tiles (floor + floor-detail,
##    detail rotated randomly so no pattern reads) over a 5×5-phone area
##    (~40×70 units at mastaba zoom), rendered as MultiMeshes (2 draw calls).
##  * STORY — a half-built stairs+corner platform, brick piles and log stacks
##    give an under-construction vibe; stone_tall clusters dot the stage.
##  * CLEAR RING — 1-tile perimeter around the baseplate stays prop-free.
##  * TRUE COLORS — models keep their own materials (arena = textured,
##    nature = vertex colors; a warm filter tames neon-teal foliage).

const NATURE := "res://art/nature/"
const ARENA := "res://art/arena/"

## Scales vs the 1-unit voxel (measured via art/measure). Awe rule: palm ≈
## 4-5 blocks, cypress ≈ 4, boulder ≈ 2, standing stone ≈ 1.4.
const MODEL_SCALE := {
	"tree_palmTall": 3.4, "tree_palmShort": 3.4, "tree_palmDetailedTall": 3.4,
	"tree_palmBend": 3.4, "tree_oak": 2.8, "tree_pineTallA": 2.8,
	"rock_largeA": 3.6, "rock_largeB": 3.6, "rock_smallA": 3.8,
	"rock_smallFlatA": 4.0, "stone_smallA": 3.8, "stone_smallFlatA": 4.0,
	"stone_tallA": 1.4, "stone_tallB": 1.4, "stone_tallC": 1.6,
	"stone_tallD": 1.6, "stone_tallE": 1.8,
	"grass": 2.6, "grass_large": 2.6, "flower_redA": 2.8,
	"flower_yellowA": 2.8, "plant_bush": 3.2, "plant_bushSmall": 3.0,
	"log": 2.0, "log_stack": 2.0, "statue_obelisk": 3.2, "statue_column": 2.8,
	"mushroom_red": 2.2, "stump_round": 2.2, "tent_smallClosed": 2.2,
	"campfire_stones": 2.4, "cactus_short": 3.0, "lily_small": 2.0,
	# mini-arena
	"tree": 2.0, "bricks": 1.6, "stairs": 1.0, "stairs-corner": 1.0,
	"column": 2.6, "wall": 1.0,
}

## Warm khaki filter for Kenney's teal foliage (vertex-color multiply).
const FOLIAGE_TINT := Color(0.82, 0.78, 0.58)
## Shade filter for vertex-colored nature models (the hot light rig washes
## mid-grey albedos to white). Arena models are textured — left untouched.
const SHADE := 0.68
const FOLIAGE_MODELS := [
	"tree_palm", "tree_oak", "tree_pine", "grass", "plant_bush", "crops",
	"tree_default", "tree_small", "tree_tall", "tree_thin", "tree_fat",
	"tree_blocks", "tree_cone", "tree_plateau", "tree_detailed", "tree_simple",
]

## Per-structure stage config.
const DIORAMAS := {
	"mastaba": {
		"hide_sand_floor": true,
		# Arena floor tiles over the whole lowermost layer, 5 phone widths ×
		# 5 phone lengths (~40×70 units at mastaba zoom). floor-detail tiles
		# get random 90° rotations so no pattern reads.
		"ground": {
			"extent": Vector2(40.0, 72.0),
			"cell": 2.0,
			"detail_weight": 0.45,
		},
		# Deliberate placements: the half-built platform + brick piles.
		"fixed_props": [
			{"m": "stairs",        "p": Vector3(-9.0, 0, 2.0), "r": 0.0},
			{"m": "stairs",        "p": Vector3(-8.0, 0, 2.0), "r": 0.0},
			{"m": "stairs",        "p": Vector3(-7.0, 0, 2.0), "r": 0.0},
			{"m": "stairs-corner", "p": Vector3(-6.0, 0, 2.0), "r": PI},
			{"m": "bricks",        "p": Vector3(-9.6, 0, 3.4), "r": 0.6},
			{"m": "bricks",        "p": Vector3(-5.9, 0, 3.5), "r": 2.2},
		],
		# Standing-stone clusters (some areas, deliberately grouped).
		"clusters": [
			{"center": Vector3(-13.0, 0, -7.0), "n": 4, "radius": 2.4,
			 "models": ["stone_tallA", "stone_tallB", "stone_tallC", "stone_tallE"]},
			{"center": Vector3(11.5, 0, 10.0), "n": 4, "radius": 2.2,
			 "models": ["stone_tallB", "stone_tallD", "stone_tallA", "stone_tallC"]},
			{"center": Vector3(-4.0, 0, -17.0), "n": 3, "radius": 1.8,
			 "models": ["stone_tallE", "stone_tallC", "stone_tallD"]},
		],
		# RNG scatter (user's mastaba set only). Palms/cypress keep out of the
		# camera-ward quadrant (0-90°, projects behind the bottom UI band).
		"props": [
			{"m": "tree_palmTall",  "n": 5, "rmin": 9.0, "rmax": 28.0, "avoid": Vector2(-10, 100)},
			{"m": "tree_palmBend",  "n": 3, "rmin": 9.0, "rmax": 22.0, "avoid": Vector2(-10, 100)},
			{"m": "tree_palmShort", "n": 3, "rmin": 6.8, "rmax": 10.0, "avoid": Vector2(-10, 100)},
			{"m": "tree",           "n": 6, "rmin": 10.0, "rmax": 26.0, "avoid": Vector2(-10, 100)},
			{"m": "bricks",         "n": 6, "rmin": 8.0, "rmax": 22.0},
			{"m": "stone_tallA",    "n": 4, "rmin": 8.0, "rmax": 22.0},
			{"m": "stone_tallB",    "n": 3, "rmin": 8.0, "rmax": 20.0},
			{"m": "stone_tallC",    "n": 2, "rmin": 9.0, "rmax": 18.0},
			{"m": "stone_tallD",    "n": 2, "rmin": 9.0, "rmax": 18.0},
			{"m": "stone_tallE",    "n": 2, "rmin": 9.0, "rmax": 18.0},
		],
	},
}


## Build (or rebuild) the stage. clear_rect = no-prop zone in x/z. floor_mesh
## is the slice's sand slab — hidden when the arena tiles are the ground.
func build(structure_id: String, floor_mesh: MeshInstance3D, clear_rect: Rect2) -> void:
	for child in get_children():
		child.queue_free()
	var cfg: Dictionary = DIORAMAS.get(structure_id, DIORAMAS.get("mastaba", {}))
	if cfg.is_empty():
		return
	if floor_mesh != null:
		floor_mesh.visible = not bool(cfg.get("hide_sand_floor", false))
		if cfg.has("ground_color"):
			var mat: StandardMaterial3D = floor_mesh.material_override
			if mat != null:
				mat.albedo_color = cfg["ground_color"]

	var rng := RandomNumberGenerator.new()
	rng.seed = structure_id.hash()

	if cfg.has("ground"):
		_build_arena_ground(cfg["ground"], rng)
	for pr in cfg.get("fixed_props", []):
		var inst: Node3D = _spawn(pr["m"], rng, float(pr.get("s", 1.0)))
		inst.position = pr["p"]
		inst.rotation = Vector3(0, float(pr["r"]), 0)
		add_child(inst)
	for cl in cfg.get("clusters", []):
		_place_cluster(cl, rng, clear_rect)
	if cfg.has("tiles") and cfg.has("tile_count"):
		var limits_rect := Rect2(
			clear_rect.position + Vector2.ONE,
			clear_rect.size - Vector2(2, 2))
		_place_tiles(cfg, rng, limits_rect)
	_place_props(cfg, rng, clear_rect)


## Arena floor tiles as two MultiMeshes (floor + floor-detail) — the whole
## lowermost layer, detail tiles randomly rotated so no pattern reads.
func _build_arena_ground(g: Dictionary, rng: RandomNumberGenerator) -> void:
	var extent: Vector2 = g["extent"]
	var cell := float(g.get("cell", 2.0))
	var detail_w := float(g.get("detail_weight", 0.35))
	var cols := int(ceil(extent.x / cell))
	var rows := int(ceil(extent.y / cell))
	var floor_t: Array[Transform3D] = []
	var detail_t: Array[Transform3D] = []
	for gx in range(-cols / 2, cols / 2):
		for gz in range(-rows / 2, rows / 2):
			# Grid-locked positions — no jitter, so tiles interlock with no
			# gaps (the earlier ±0.3 jitter opened seams to the sky behind).
			var pos := Vector3((gx + 0.5) * cell, 0.002, (gz + 0.5) * cell)
			if rng.randf() < detail_w:
				var rot := rng.randi_range(0, 3) * PI / 2.0
				detail_t.append(_tile_xform(pos, rot, cell))
			else:
				floor_t.append(_tile_xform(pos, rng.randi_range(0, 1) * PI / 2.0, cell))
	_make_multimesh(_shade_mesh(_extract_mesh(ARENA + "floor.glb")), floor_t)
	_make_multimesh(_shade_mesh(_extract_mesh(ARENA + "floor-detail.glb")), detail_t)


## Textured arena materials skip the vertex-color tint path — apply the shade
## filter directly to the mesh's surface materials (albedo multiplies the
## colormap texture, taming the hot light rig's white-out on the floor).
func _shade_mesh(mesh: Mesh) -> Mesh:
	if mesh == null:
		return mesh
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s)
		if m is StandardMaterial3D:
			(m as StandardMaterial3D).albedo_color = Color(SHADE, SHADE, SHADE)
	return mesh


func _tile_xform(pos: Vector3, rot: float, cell: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(cell, 1.0, cell)), pos)


func _make_multimesh(mesh: Mesh, transforms: Array[Transform3D]) -> void:
	if mesh == null or transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


## First MeshInstance3D mesh from a GLB scene (keeps its surface materials).
func _extract_mesh(path: String) -> Mesh:
	var ps: PackedScene = load(path)
	var inst := ps.instantiate()
	var mesh: Mesh = null
	var stack: Array[Node] = [inst]
	while not stack.is_empty() and mesh == null:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			mesh = (n as MeshInstance3D).mesh
		for child in n.get_children():
			stack.push_back(child)
	inst.free()
	return mesh


## Standing-stone cluster: n stones jittered around the center.
func _place_cluster(cl: Dictionary, rng: RandomNumberGenerator, clear_rect: Rect2) -> void:
	var center: Vector3 = cl["center"]
	var n := int(cl["n"])
	var radius := float(cl["radius"])
	var models: Array = cl["models"]
	for i in n:
		var ang: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(0.0, radius)
		var pos := center + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		if clear_rect.has_point(Vector2(pos.x, pos.z)):
			continue
		var model_name: String = models[rng.randi_range(0, models.size() - 1)]
		var inst: Node3D = _spawn(model_name, rng, 1.0)
		inst.position = pos
		add_child(inst)


func _place_tiles(cfg: Dictionary, rng: RandomNumberGenerator, limits_rect: Rect2) -> void:
	var tiles: Array = cfg["tiles"]
	var total_w := 0
	for t in tiles:
		total_w += int(t["w"])
	var count := int(cfg["tile_count"])
	for i in count:
		var roll := rng.randi_range(1, total_w)
		var acc := 0
		var pick: Dictionary = tiles[0]
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
		var per_prop_scale := float(entry.get("s", 1.0))
		var avoid: Vector2 = entry.get("avoid", Vector2(-999, -999))
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


## Instantiate with global scale (× per-prop override) + warm foliage filter.
func _spawn(model_name: String, rng: RandomNumberGenerator, per_prop_scale: float) -> Node3D:
	var path := NATURE + model_name + ".glb"
	if not ResourceLoader.exists(path):
		path = ARENA + model_name + ".glb"
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
