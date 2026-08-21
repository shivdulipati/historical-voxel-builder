extends Node3D
## diorama.gd — static environmental stage per structure: ground tint + props
## (Kenney CC0 packs). Props are pure visuals: no physics, no collision, no
## group membership — they can never interfere with placement or erasing.

const NATURE := "res://art/nature/"

## Kenney models are built small vs the 1-unit voxel (measured via art/measure):
## a palm is 1.36 units raw. These scales bring each model to its intended
## read: palm ~6 blocks tall, boulder ~1 block, obelisk ~3 blocks.
const MODEL_SCALE := {
	"tree_palmTall": 4.5, "tree_palmShort": 4.5, "tree_palmDetailedTall": 4.5,
	"tree_palmBend": 4.5, "tree_oak": 4.0, "tree_pineTallA": 4.0,
	"rock_largeA": 2.6, "rock_largeB": 2.6, "rock_smallA": 3.0,
	"rock_smallFlatA": 3.0, "stone_smallA": 3.0, "stone_smallFlatA": 3.0,
	"stone_tallA": 1.1, "grass": 1.5, "grass_large": 1.5, "flower_redA": 2.0,
	"plant_bush": 2.2, "log": 1.5, "statue_obelisk": 3.5, "statue_column": 3.0,
	"mushroom_red": 1.5, "stump_round": 1.6,
}

## Per-structure stage config. Props sit outside the build footprint (limits
## have a 1-cell margin; everything here is beyond it). y=0 always.
const DIORAMAS := {
	"mastaba": {
		"ground_color": Color("#D9C089"),
		"props": [
			# Camera rig: _default_cam_rot (-0.45, 0.8, 0) puts the camera NE of
			# the baseplate (~10, 6.5, 9.75) looking at the origin. Foreground =
			# toward NE (avoid); backdrop = far arc NW→S→SE (angles 120°-300°).
			# Visible ground rect has half-diagonal ~7.9 → palms at r 7.5-9 poke
			# into the frame edges; rocks at r 4-5 read as mid-ground scatter.
			{"m": "tree_palmTall",         "p": Vector3(-8.5, 0, -6.5), "r": 2.4},
			{"m": "tree_palmDetailedTall", "p": Vector3(-9.5, 0, -1.5), "r": 0.9},
			{"m": "tree_palmBend",         "p": Vector3(4.0, 0, -8.2),   "r": -0.5},
			{"m": "tree_palmShort",        "p": Vector3(-3.2, 0, -8.6),  "r": -1.8},
			{"m": "rock_largeB",           "p": Vector3(-4.6, 0, 4.4),   "r": 0.8},
			{"m": "rock_largeA",           "p": Vector3(4.4, 0, -4.6),   "r": 2.0},
			{"m": "rock_smallA",           "p": Vector3(4.6, 0, 3.4),    "r": 2.4},
			{"m": "stone_smallFlatA",      "p": Vector3(2.6, 0, 3.6),    "r": 1.1},
			{"m": "stone_smallA",          "p": Vector3(-3.4, 0, 4.8),   "r": 0.3},
			{"m": "rock_smallFlatA",       "p": Vector3(-4.4, 0, -4.4),  "r": 1.7},
			{"m": "plant_bush",            "p": Vector3(-2.8, 0, -4.4),  "r": 0.5},
		],
	},
}


## Build (or rebuild) the stage for a structure. floor_mesh is the shared sand
## floor; its tint becomes the per-level ground color.
func build(structure_id: String, floor_mesh: MeshInstance3D) -> void:
	for child in get_children():
		child.queue_free()
	var cfg: Dictionary = DIORAMAS.get(structure_id, {})
	if cfg.is_empty():
		return
	if floor_mesh != null and cfg.has("ground_color"):
		var mat: StandardMaterial3D = floor_mesh.material_override
		if mat != null:
			mat.albedo_color = cfg["ground_color"]
	for pr in cfg["props"]:
		var model_name: String = pr["m"]
		var path := NATURE + model_name + ".glb"
		if not ResourceLoader.exists(path):
			push_warning("diorama: missing model " + path)
			continue
		var inst: Node3D = (load(path) as PackedScene).instantiate()
		inst.position = pr["p"]
		inst.rotation = Vector3(0, float(pr.get("r", 0.0)), 0)
		inst.scale = Vector3.ONE * float(MODEL_SCALE.get(model_name, 1.0))
		add_child(inst)
