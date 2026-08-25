extends Node3D
## BUILD 36 → v7: EXACT transcription of Mastaba_01.model (UPDATED 2026-08-25:
## 67 blocks, 9 model types). The earmarked area was enlarged (z 0..9.5) to
## hold the baseplate + structure; its center (-0.75, 4.75 in AF coords) is
## shifted onto the game origin, so the hedge L-brackets land at
## (±2.75, 0, ±4.75).
##
## Materials: AF material overrides are replicated — custom1 (Nature/sand.png)
## on the kit blocks (grass tiles, snow, hedges, debris) via a triplanar
## sand shader; the built-in exports (icosphere_half, stairs_half_corner,
## debris_stone) are the USER'S OWN exports from Asset Forge (exact geometry,
## flat MTL colors) — no more Blender stand-ins.
## Pure visuals — no physics, no collisions.

const Y_SHIFT := -2.0
# Earmark (L-bracket square) center in AF coords: x -3.5..2, z 0..9.5
# -> center (-0.75, 4.75). Shift so it lands on the game origin.
const CENTER_SHIFT := Vector2(0.75, -4.75)

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
	"rocks": "res://art/platformer/rocks.glb",
	"grass": "res://art/platformer/grass.glb",
	"hedge-corner": "res://art/platformer/hedge-corner.glb",
	"block-snow-low-large": "res://art/platformer/block-snow-low-large.glb",
	"block-snow-large": "res://art/platformer/block-snow-large.glb",
	"icosphere_half": "res://art/platformer/icosphere_half.glb",
	"stairs_half_corner": "res://art/platformer/stairs_half_corner.glb",
	"debris_stone": "res://art/platformer/debris_stone.glb",
}

# AF material overrides -> triplanar texture (the .model's custom1 = sand;
# the built-in exports carry their own flat MTL colors).
const MATERIAL_TEX := {
	"block-grass-large-tall": "res://art/textures/sand.png",
	"block-snow-low-large": "res://art/textures/sand.png",
	"block-snow-large": "res://art/textures/sand.png",
	"hedge-corner": "res://art/textures/sand.png",
	"debris_stone": "res://art/textures/sand.png",
	"icosphere_half": "res://art/textures/marble.png",
}

# [type, pos (Asset Forge), rot_y deg, scale] — verbatim from Mastaba_01.model.
const BLOCKS := [
	["block-grass-large-tall", Vector3(0.00, 0.00, -1.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(1.50, 0.00, -1.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(1.50, 0.00, -3.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(0.00, 0.00, -3.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(4.50, 0.00, 0.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-1.50, 0.00, 1.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-1.50, 0.00, -1.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-3.00, 0.00, 3.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-3.00, 0.00, 1.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-3.00, 0.00, 0.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-1.50, 0.00, 0.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-1.50, 0.00, 3.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(0.00, 0.00, 3.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(0.00, 0.00, 1.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(0.00, 0.00, 0.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(6.00, 0.00, -1.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-snow-low-large", Vector3(5.25, 1.50, -5.25), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(4.50, 0.00, -3.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(4.50, 0.00, -4.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(4.50, 0.00, -1.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(3.00, 0.00, -3.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(3.00, 0.00, -4.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(3.00, 0.00, -1.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["hedge-corner", Vector3(2.00, 2.00, 0.00), 90.0, Vector3(1.00, 1.00, 1.00)],
	["hedge-corner", Vector3(-3.50, 2.00, 0.00), 180.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(6.00, 0.00, 0.00), 0.0, Vector3(1.25, 1.25, 1.25)],
	["rocks", Vector3(6.44, 2.50, -0.05), 180.0, Vector3(1.00, 1.00, 1.00)],
	["rocks", Vector3(6.63, 2.50, 0.28), 45.0, Vector3(1.00, 1.00, 1.00)],
	["rocks", Vector3(6.62, 2.50, -0.52), 270.0, Vector3(1.00, 1.00, 1.00)],
	["rocks", Vector3(5.87, 2.50, -0.85), 0.0, Vector3(1.00, 1.00, 1.00)],
	["rocks", Vector3(5.38, 2.50, 0.41), 90.0, Vector3(1.50, 1.50, 1.50)],
	["stones", Vector3(5.40, 2.50, -0.40), 0.0, Vector3(1.00, 1.00, 1.00)],
	["rocks", Vector3(5.43, 2.00, -5.18), 270.0, Vector3(2.00, 2.00, 2.00)],
	["stones", Vector3(-1.80, 2.00, -1.40), 0.0, Vector3(1.00, 1.00, 1.00)],
	["stones", Vector3(-1.52, 2.00, -1.78), 45.0, Vector3(1.00, 1.00, 1.00)],
	["stones", Vector3(-1.30, 2.00, -1.36), 72.0, Vector3(1.00, 1.00, 1.00)],
	["stones", Vector3(-1.01, 2.00, -1.74), 114.0, Vector3(1.00, 1.00, 1.00)],
	["icosphere_half", Vector3(-1.60, 2.50, -4.89), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-snow-large", Vector3(-1.50, 1.50, -4.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["icosphere_half", Vector3(-1.03, 2.50, -4.33), 240.0, Vector3(0.30, 0.30, 0.30)],
	["icosphere_half", Vector3(-1.33, 2.50, -4.23), 240.0, Vector3(0.30, 0.30, 0.30)],
	["icosphere_half", Vector3(-1.17, 2.50, -4.07), 270.0, Vector3(0.25, 0.25, 0.25)],
	["icosphere_half", Vector3(-1.78, 2.50, -4.12), 315.0, Vector3(0.50, 0.50, 0.50)],
	["stairs_half_corner", Vector3(3.30, 2.00, -2.20), 270.0, Vector3(1.00, 1.00, 1.00)],
	["debris_stone", Vector3(1.90, 2.00, -2.90), 270.0, Vector3(1.00, 1.00, 1.00)],
	["debris_stone", Vector3(1.40, 2.00, -2.50), 180.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-1.50, 0.00, 4.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(1.50, 0.00, 0.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(1.50, 0.00, 1.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(1.50, 0.00, 3.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(1.50, 0.00, 4.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(1.50, 0.00, 6.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(1.50, 0.00, 7.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(1.50, 0.00, 9.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-3.00, 0.00, 4.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-3.00, 0.00, 6.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-3.00, 0.00, 7.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-3.00, 0.00, 9.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(0.00, 0.00, 4.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(0.00, 0.00, 6.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(0.00, 0.00, 7.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(0.00, 0.00, 9.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-1.50, 0.00, 9.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-1.50, 0.00, 7.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(-1.50, 0.00, 6.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["hedge-corner", Vector3(2.00, 2.00, 9.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["hedge-corner", Vector3(-3.50, 2.00, 9.50), 270.0, Vector3(1.00, 1.00, 1.00)],
]

# The structure earmark: the L-bracket rectangle (after CENTER_SHIFT) spans
# x -2.75..2.75, z -4.75..4.75. Only hedge-corner brackets may sit on its
# rim; only grass platform tiles may sit inside (they are the floor).
const MARKER_X := 2.75
const MARKER_Z := 4.75

var _mat_cache := {}


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
		# AF material override replication (triplanar texture on every mesh).
		if MATERIAL_TEX.has(b[0]):
			var m := _get_override_mat(b[0])
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = m
		add_child(inst)
		i += 1


func _get_override_mat(block_type: String) -> Material:
	if _mat_cache.has(block_type):
		return _mat_cache[block_type]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://art/sand_override.gdshader")
	mat.set_shader_parameter("tex", load(MATERIAL_TEX[block_type]))
	_mat_cache[block_type] = mat
	return mat


func _clear() -> void:
	for child in get_children():
		child.free()
