extends Node3D
## BUILD 26 → v4: the composed-platform diorama. Per user direction
## ("too many models... fewer models and scaling them will look better...
## overlap some models to make it look aesthetic") the island is no longer a
## mosaic of ~480 tiles — it is ONE thick grass slab (the block's own brown
## body = the strata, 4 units tall) with a few overlapping scaled blocks for
## character: a lower side ledge, a raised back platform, a corner lip piece.
## Trees/rocks/grass tufts/flowers are placed around the rim — the centre
## ~6.4x4.4 area is kept clear for the structure + baseplate (the reference's
## "3x4" marker). ~15 nodes total. No 2D tiles, no strip shader.
## Pure visuals — no physics, no collisions.

const CELL := 1.0

# --- Composition ------------------------------------------------------------
# Each slab: [model, pos, top_y, scale, rot_y]. top_y = the world y of the
# piece's top surface (top-pinned placement); scale = per-axis stretch.
const MAIN_MODEL := "res://art/platformer/block-grass-large-tall.glb"  # 2x2x2 native
const LARGE_MODEL := "res://art/platformer/block-grass-large.glb"      # 2x2x1
const LONG_MODEL := "res://art/platformer/block-grass-long.glb"        # 2x1x1
const LIP_MODEL := "res://art/platformer/block-grass-overhang-large.glb"
const TREE_MODEL := "res://art/platformer/tree.glb"
const ROCKS_MODEL := "res://art/platformer/rocks.glb"
const TUFT_MODEL := "res://art/platformer/grass.glb"
const FLOWER_MODEL := "res://art/platformer/flowers.glb"

const SLABS := [
	["Main", MAIN_MODEL, Vector3(0, 0, 0), 0.0, Vector3(6.0, 2.0, 5.0), 0.0],
	# Lower side ledge, overlapping the main wall.
	["LedgeL", LARGE_MODEL, Vector3(-6.2, 0, -2.2), -2.0, Vector3(1.5, 1.5, 1.8), 0.0],
	# Right extension flush with the top, overlapping the right wall.
	["ExtR", LONG_MODEL, Vector3(6.3, 0, 1.8), 0.0, Vector3(1.1, 2.5, 2.4), 0.0],
	# Raised back platform (top at +2) with a tree, sunk slightly into the lawn.
	["PlatBack", LARGE_MODEL, Vector3(-3.5, 0, 4.8), 2.0, Vector3(1.3, 2.0, 1.1), 0.0],
	# Corner lip piece at the front-right, rotated to hug the corner diagonal.
	["CornerFR", LIP_MODEL, Vector3(5.5, 0, -4.3), 0.0, Vector3(1.3, 1.3, 1.3), atan2(0.79, -0.62)],
]

# [model, pos (x, y, z), scale, rot_y] — y = the surface it stands on.
const PROPS := [
	[TREE_MODEL, Vector3(-3.5, 2.0, 4.8), 2.2, 0.4],     # on the back platform
	[TREE_MODEL, Vector3(-7.2, -2.0, -2.8), 1.8, 2.1],   # on the side ledge
	[TREE_MODEL, Vector3(-6.1, -2.0, -1.1), 1.6, 4.5],   # on the side ledge
	[TREE_MODEL, Vector3(4.6, 0.0, 3.4), 2.4, 1.2],      # back-right lawn
	[ROCKS_MODEL, Vector3(-4.6, 0.0, -3.6), 1.1, 0.0],
	[ROCKS_MODEL, Vector3(7.0, 0.0, 1.6), 0.9, 2.6],     # on the right extension
	[TUFT_MODEL, Vector3(-1.8, 0.0, 3.6), 0.7, 0.0],
	[TUFT_MODEL, Vector3(3.2, 0.0, -4.4), 0.8, 1.9],
	[TUFT_MODEL, Vector3(5.2, 0.0, 2.6), 0.6, 3.7],
	[TUFT_MODEL, Vector3(-5.9, -2.0, -3.3), 0.6, 5.2],   # on the ledge
	[TUFT_MODEL, Vector3(4.7, 2.0, 4.6), 0.7, 2.8],      # on the back platform
	[FLOWER_MODEL, Vector3(-2.6, 0.0, -4.6), 0.9, 0.0],
	[FLOWER_MODEL, Vector3(5.9, 0.0, -2.9), 0.8, 2.2],
]

# The build area stays clear of props (structure + baseplate live here).
const CLEAR_X := 3.5
const CLEAR_Z := 3.0

var _grass_mesh: Mesh = null


func build(structure_id: String) -> void:
	_clear()
	if structure_id != "mastaba" and structure_id != "diorama_debug":
		return
	for s in SLABS:
		_place_slab(s)
	for p in PROPS:
		_place_prop(p)


func _clear() -> void:
	for child in get_children():
		child.free()


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null


## Place one slab, top-pinned at top_y with the given scale/rotation.
## spec = [name, model, pos, top_y, scale, rot]
func _place_slab(spec: Array) -> void:
	var scene := load(spec[1]) as PackedScene
	var inst := scene.instantiate()
	var m: MeshInstance3D = _first_mesh(inst)
	var aabb := m.mesh.get_aabb() if m != null and m.mesh != null else AABB(Vector3.ZERO, Vector3.ONE)
	var top_mesh: float = aabb.position.y + aabb.size.y
	var scale_v: Vector3 = spec[4]
	inst.name = spec[0]
	inst.scale = scale_v
	inst.rotation.y = spec[5]
	# Top-pinned: world top sits at top_y (sunk 0.02 into whatever is beneath
	# when it rests on another piece, to avoid z-fighting).
	var sink := 0.02 if spec[3] > 0.0 else 0.0
	inst.position = Vector3(spec[2].x, spec[3] - top_mesh * scale_v.y - sink, spec[2].z)
	add_child(inst)


func _place_prop(spec: Array) -> void:
	var scene := load(spec[0]) as PackedScene
	var inst := scene.instantiate()
	var m: MeshInstance3D = _first_mesh(inst)
	var aabb := m.mesh.get_aabb() if m != null and m.mesh != null else AABB(Vector3.ZERO, Vector3.ONE)
	var s: float = spec[2] / maxf(aabb.size.y, 0.001)
	inst.scale = Vector3.ONE * s
	inst.position = spec[1]
	inst.rotation.y = spec[3]
	add_child(inst)
