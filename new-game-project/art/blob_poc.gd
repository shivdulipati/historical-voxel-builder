extends Node3D
## BUILD 39 → v8: EXACT transcription of Mastaba_01.model (UPDATED 2026-08-25:
## 66 blocks, 8 model types). The user removed the hedge L-brackets and added
## a 4-stair ring ("practice mastaba") + debris near the platform — the
## diorama now reads as a construction site. Earmark center (-0.75, 4.75 in
## AF coords) is shifted onto the game origin.
##
## Materials: AF material overrides replicated — custom1 (Nature/sand.png)
## on the sand blocks via a shader sampling the BAKED per-face UV1 (uniform
## 1-tile-per-unit, identical sand on floor/stairs/debris); the marble domes
## use their own UVs; the built-in exports (icosphere_half, stairs_half_corner,
## debris_stone) are the USER'S OWN exports from Asset Forge (exact geometry).
## Pure visuals — no physics, no collisions.

const Y_SHIFT := -2.0
# Earmark (L-bracket rectangle) center in AF coords: x -3.5..2, z 0..9.5
# -> center (-0.75, 4.75). Asset Forge is LEFT-handed; Godot is RIGHT-handed,
# so the x axis is mirrored in build() (game_x = -AF_x). The mirrored earmark
# center (0.75, 4.75) is shifted onto the game origin: hedge L-brackets land
# at (±2.75, 0, ±4.75). Rotations pass through UNCHANGED (the left-handed
# rotation direction cancels the mirror — verified on all 4 hedge corners).
const CENTER_SHIFT := Vector2(-0.75, -4.75)

const M := {
	"block-grass": "res://art/platformer/block-grass.glb",
	"block-grass-large-tall": "res://art/platformer/block-grass-large-tall_sand.glb",
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
	"hedge-corner": "res://art/platformer/hedge-corner_sand.glb",
	"block-snow-low-large": "res://art/platformer/block-snow-low-large.glb",
	"block-snow-large": "res://art/platformer/block-snow-large.glb",
	"icosphere_half": "res://art/platformer/icosphere_half.glb",
	"stairs_half_corner": "res://art/platformer/stairs_half_corner.glb",
	"debris_stone": "res://art/platformer/debris_stone_sand.glb",
}

# AF material overrides -> texture. The sand blocks now CARRY the sand baked
# into their GLBs (proper per-face UVs — no override needed). Only the marble
# domes use the override shader (their own UVs).
const MATERIAL_TEX := {
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
	["block-grass-large-tall", Vector3(5.25, 0.00, -5.25), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(4.50, 0.00, -3.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(4.50, 0.00, -4.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(4.50, 0.00, -1.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(3.00, 0.00, -3.00), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(3.00, 0.00, -4.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["block-grass-large-tall", Vector3(3.00, 0.00, -1.50), 0.0, Vector3(1.00, 1.00, 1.00)],
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
	["block-grass-large-tall", Vector3(-1.50, 0.00, -4.50), 0.0, Vector3(1.00, 1.00, 1.00)],
	["icosphere_half", Vector3(-1.03, 2.50, -4.33), 240.0, Vector3(0.30, 0.30, 0.30)],
	["icosphere_half", Vector3(-1.33, 2.50, -4.23), 240.0, Vector3(0.30, 0.30, 0.30)],
	["icosphere_half", Vector3(-1.17, 2.50, -4.07), 270.0, Vector3(0.25, 0.25, 0.25)],
	["icosphere_half", Vector3(-1.78, 2.50, -4.12), 315.0, Vector3(0.50, 0.50, 0.50)],
	["stairs_half_corner", Vector3(3.30, 2.00, -2.20), 270.0, Vector3(1.00, 1.00, 1.00)],
	["stairs_half_corner", Vector3(4.20, 2.00, -2.20), 180.0, Vector3(1.00, 1.00, 1.00)],
	["stairs_half_corner", Vector3(3.30, 2.00, -3.20), 0.0, Vector3(1.00, 1.00, 1.00)],
	["stairs_half_corner", Vector3(4.20, 2.00, -3.20), 90.0, Vector3(1.00, 1.00, 1.00)],
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
]

# The structure earmark: the L-bracket rectangle (after CENTER_SHIFT) spans
# x -2.75..2.75, z -4.75..4.75. Only hedge-corner brackets may sit on its
# rim; only grass platform tiles may sit inside (they are the floor).
const MARKER_X := 2.75
const MARKER_Z := 4.75

# Sand-tune override (BUILD 46): the sand blocks carry AF's dune texture at
# per-face UVs; the override shader makes the density live-adjustable so the
# user can match AF's look in the editor ([ / ] keys) before the value is
# locked in. The stairs keep their dark-stone treads (light material only).
const SAND_TUNE := ["block-grass-large-tall", "stairs_half_corner", "debris_stone"]

var _mat_cache := {}
var _sand_mat: ShaderMaterial = null


func set_sand_scale(v: float) -> void:
	var m := _get_sand_mat()
	m.set_shader_parameter("scale", v)


func _get_sand_mat() -> ShaderMaterial:
	if _sand_mat == null:
		_sand_mat = ShaderMaterial.new()
		_sand_mat.shader = load("res://art/sand_tune.gdshader")
		_sand_mat.set_shader_parameter("tex", load("res://art/textures/sand_dune.png"))
		_sand_mat.set_shader_parameter("scale", 0.25)
	return _sand_mat


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
		inst.position = Vector3(-b[1].x + CENTER_SHIFT.x, b[1].y + Y_SHIFT, b[1].z + CENTER_SHIFT.y)
		# AF material override replication (marble) + sand-tune override.
		if MATERIAL_TEX.has(b[0]):
			var m := _get_override_mat(b[0])
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = m
		if b[0] in SAND_TUNE:
			var sm := _get_sand_mat()
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				var mmi := mi as MeshInstance3D
				if b[0] == "stairs_half_corner":
					var am := mmi.get_active_material(0)
					if am == null or not String(am.resource_name).contains("Light"):
						continue
				mmi.material_override = sm
		add_child(inst)
		i += 1


func _get_override_mat(block_type: String) -> Material:
	if _mat_cache.has(block_type):
		return _mat_cache[block_type]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://art/sand_override.gdshader")
	mat.set_shader_parameter("tex", load(MATERIAL_TEX[block_type]))
	mat.set_shader_parameter("use_uv2", not MATERIAL_TEX[block_type].ends_with("marble.png"))
	_mat_cache[block_type] = mat
	return mat


func _clear() -> void:
	for child in get_children():
		child.free()
