extends Node3D
## BUILD 27 → v5: the diorama is now an EXACT transcription of the user's
## Asset Forge level (Test_01.model — 29 blocks, 12 model types). The .model
## file is human-readable, so every block's type/position/rotation/scale was
## parsed 1:1. Asset Forge's top surface sits at y=2; the game's resting plane
## is y=0, so everything shifts by Y_SHIFT (-2). Blocks embed/overlap exactly
## as authored (the "overlap to look aesthetic" language).
## Pure visuals — no physics, no collisions.

const Y_SHIFT := -2.0
# The 3x4 marker (structure spot) centers at (-0.1, 4.5) in Asset Forge coords;
# shift the whole composition so that point lands on the game origin, where
# the structure + baseplate spawn.
const CENTER_SHIFT := Vector2(0.1, -2.5)

const M := {
	"block-grass": "res://art/platformer/block-grass.glb",
	"block-grass-large-tall": "res://art/platformer/block-grass-large-tall.glb",
	"block-grass-overhang-long": "res://art/platformer/block-grass-overhang-long.glb",
	"block-grass-overhang-large-tall": "res://art/platformer/block-grass-overhang-large-tall.glb",
	"block-grass-overhang-corner": "res://art/platformer/block-grass-overhang-corner.glb",
	"block-moving": "res://art/platformer/block-moving.glb",
	"tree": "res://art/platformer/tree.glb",
	"tree-pine": "res://art/platformer/tree-pine.glb",
	"tree-pine-small": "res://art/platformer/tree-pine-small.glb",
	"plant": "res://art/platformer/plant.glb",
	"stones": "res://art/platformer/stones.glb",
	"flowers": "res://art/platformer/flowers.glb",
}

# [type, pos (Asset Forge), rot_y deg, scale] — verbatim from Test_01.model.
const BLOCKS := [
	["block-grass-overhang-large-tall", Vector3(-0.76, -0.20, 4.54), 0.0, Vector3(4.50, 1.10, 4.50)],
	["block-grass-large-tall", Vector3(3.90, 0.00, 0.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["block-grass", Vector3(3.90, 1.00, 1.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["block-grass-overhang-long", Vector3(3.25, 1.00, 8.89), 270.0, Vector3(2.00, 1.00, 2.66)],
	["block-grass-overhang-large-tall", Vector3(-4.90, 1.00, 8.60), 0.0, Vector3(1.0, 1.0, 1.0)],
	["block-grass-overhang-corner", Vector3(-5.10, 2.60, 10.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	# The 3x4 marker (structure + baseplate area): 12 block-moving in 3x4.
	["block-moving", Vector3(0.90, 2.00, 3.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["block-moving", Vector3(0.90, 2.00, 4.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["block-moving", Vector3(0.90, 2.00, 5.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["block-moving", Vector3(0.90, 2.00, 6.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["block-moving", Vector3(-0.10, 2.00, 3.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["block-moving", Vector3(-0.10, 2.00, 4.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["block-moving", Vector3(-0.10, 2.00, 5.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["block-moving", Vector3(-0.10, 2.00, 6.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["block-moving", Vector3(-1.10, 2.00, 3.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["block-moving", Vector3(-1.10, 2.00, 4.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["block-moving", Vector3(-1.10, 2.00, 5.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["block-moving", Vector3(-1.10, 2.00, 6.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	# Props (all on the lawn / chunks at y=2 → 0).
	["tree-pine", Vector3(3.90, 2.00, 0.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["tree-pine-small", Vector3(3.90, 2.00, 8.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["tree-pine-small", Vector3(3.90, 2.00, 9.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["tree-pine-small", Vector3(2.90, 2.00, 9.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["tree-pine-small", Vector3(2.90, 2.00, 10.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["plant", Vector3(3.90, 2.00, 10.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["plant", Vector3(2.90, 2.00, 11.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["stones", Vector3(2.90, 2.00, 4.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["stones", Vector3(-0.10, 2.00, 8.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["flowers", Vector3(-3.10, 2.00, 8.00), 0.0, Vector3(1.0, 1.0, 1.0)],
	["tree", Vector3(-4.10, 2.00, 2.00), 0.0, Vector3(1.0, 1.0, 1.0)],
]

# The 3x4 marker box (structure + baseplate live here) — only block-moving
# blocks are allowed inside it.
const MARKER_X := 1.5
const MARKER_Z := 1.5


func build(structure_id: String) -> void:
	_clear()
	if structure_id != "mastaba" and structure_id != "diorama_debug":
		return
	var i := 0
	for b in BLOCKS:
		var scene := load(M[b[0]]) as PackedScene
		var inst := scene.instantiate()
		inst.name = "%s_%02d" % [b[0], i]
		inst.scale = b[3]
		inst.rotation.y = deg_to_rad(b[2])
		inst.position = Vector3(b[1].x + CENTER_SHIFT.x, b[1].y + Y_SHIFT, b[1].z + CENTER_SHIFT.y)
		add_child(inst)
		i += 1


func _clear() -> void:
	for child in get_children():
		child.free()
