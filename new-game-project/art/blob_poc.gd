extends Node3D
## BUILD 24 POC: the organic "mini-map" earth slice. A blob-shaped island
## (noise-perturbed radius, like a Kenney miniature-map outline) built from
## 2x8x2 columns in ONE MultiMesh, platformer-kit grass-overhang blocks along
## the rim, platformer trees + rocks on top, fossils on the exposed edge
## faces, and the new-platformer-pack strata strip on the sides.
## Pure visuals — no physics, no collisions. If the look is approved this
## becomes the core of earth_slice.gd.

const CELL := 2.0          # column footprint (also the mask cell size)
const GRID := 22           # cells per half-extent → ±22 units
const DEPTH := 8.0
const BLOB_SEED := 1337

const STRATA_TEX := "res://art/textures/strata_platformer.png"
const TOP_TEX := "res://art/2d_src/platformer/terrain_sand_block_center.png"
const RIM_MODEL := "res://art/platformer/block-grass-overhang-low-long.glb"
const CORNER_MODEL := "res://art/platformer/block-grass-corner-overhang.glb"
const TREE_MODEL := "res://art/platformer/tree.glb"
const ROCKS_MODEL := "res://art/platformer/rocks.glb"

## [texture path, depth-band y, size]
const FOSSILS: Array = [
	["res://art/2d_src/ore_gold.png", -5.2, 0.9],
	["res://art/2d_src/coin_gold.png", -1.2, 0.6],
	["res://art/2d_src/gem_green.png", -6.3, 0.55],
	["res://art/2d_src/gem_red.png", -5.5, 0.5],
	["res://art/2d_src/coin_gold.png", -0.9, 0.6],
]

var _rng := RandomNumberGenerator.new()
var _mask := {}          # Vector2i -> true
var _edge_cells: Array = []


func build(structure_id: String) -> void:
	_clear()
	if structure_id != "mastaba" and structure_id != "diorama_debug":
		return
	_rng.seed = BLOB_SEED
	_gen_mask()
	_build_columns()
	_build_rim()
	_build_props()
	_build_fossils()


func _clear() -> void:
	for child in get_children():
		child.free()
	_mask.clear()
	_edge_cells.clear()


# --- Mask -------------------------------------------------------------------

func _hash(ix: int, iz: int) -> float:
	var h := (ix * 374761393 + iz * 668265263) % 2147483647
	return float(h & 0xFFFFFF) / float(0xFFFFFF)


func _noise(x: float, z: float) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var fx := x - ix
	var fz := z - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := _hash(ix, iz)
	var b := _hash(ix + 1, iz)
	var c := _hash(ix, iz + 1)
	var d := _hash(ix + 1, iz + 1)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


func _gen_mask() -> void:
	for gx in range(-GRID, GRID + 1):
		for gz in range(-GRID, GRID + 1):
			var d := sqrt(float(gx * gx + gz * gz))
			# Two noise octaves perturb a ~17.5-unit radius → organic outline.
			var r := 17.5 + (_noise(gx * 0.17, gz * 0.17) - 0.5) * 14.0 \
					+ (_noise(gx * 0.53 + 31.7, gz * 0.53 - 7.1) - 0.5) * 4.0
			var solid := d < r
			# The build area (±5 cells around the mastaba) is always solid.
			if absf(gx) <= 5 and absf(gz) <= 5:
				solid = true
			if solid:
				_mask[Vector2i(gx, gz)] = true
	for gx in range(-GRID, GRID + 1):
		for gz in range(-GRID, GRID + 1):
			if not _mask.has(Vector2i(gx, gz)):
				continue
			if not _mask.has(Vector2i(gx + 1, gz)) or not _mask.has(Vector2i(gx - 1, gz)) \
					or not _mask.has(Vector2i(gx, gz + 1)) or not _mask.has(Vector2i(gx, gz - 1)):
				_edge_cells.append(Vector2i(gx, gz))


# --- Slab -------------------------------------------------------------------

func _slab_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://art/strata_face.gdshader")
	mat.set_shader_parameter("strata_tex", load(STRATA_TEX))
	mat.set_shader_parameter("top_tex", load(TOP_TEX))
	mat.set_shader_parameter("depth", DEPTH)
	mat.set_shader_parameter("tile", 2.0)  # 64px tiles, 32px/unit
	return mat


func _build_columns() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(CELL, DEPTH, CELL)
	mm.mesh = box
	mm.instance_count = _mask.size()
	var i := 0
	for cell in _mask:
		var t := Transform3D(Basis.IDENTITY,
				Vector3(cell.x * CELL, -DEPTH / 2.0, cell.y * CELL))
		mm.set_instance_transform(i, t)
		i += 1
	var mi := MultiMeshInstance3D.new()
	mi.name = "BlobColumns"
	mi.multimesh = mm
	mi.material_override = _slab_material()
	add_child(mi)


# --- Rim overhang (platformer-kit grass blocks) -----------------------------

func _build_rim() -> void:
	var long := load(RIM_MODEL) as PackedScene
	var corner := load(CORNER_MODEL) as PackedScene
	for cell in _edge_cells:
		var dirs := _outward_dirs(cell)
		if dirs.size() == 0:
			continue
		var inst: Node3D
		if dirs.size() >= 2 and (dirs[0] + dirs[1]).x != 0 and (dirs[0] + dirs[1]).y != 0:
			inst = corner.instantiate()
		else:
			inst = long.instantiate()
		# Fit the block to the 2-unit cell, long axis along the rim edge.
		var aabb := _aabb_of(inst)
		var s := CELL / maxf(aabb.size.x, 0.001)
		inst.scale = Vector3(s, s, s)
		var dir: Vector2i = dirs[0]
		inst.position = Vector3(cell.x * CELL, 0.0, cell.y * CELL)
		# Align the block's +X (long axis) with the rim's tangent, +Z outward.
		var tangent := Vector2i(-dir.y, dir.x)
		inst.rotation.y = atan2(float(tangent.x), float(tangent.y)) - PI / 2.0
		add_child(inst)


func _outward_dirs(cell: Vector2i) -> Array:
	var out: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _mask.has(cell + d):
			out.append(d)
	return out


func _aabb_of(node: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	for child in node.get_children():
		if child is MeshInstance3D:
			var m := child as MeshInstance3D
			if m.mesh == null:
				continue
			var b := m.get_aabb()
			if first:
				aabb = b
				first = false
			else:
				aabb = aabb.merge(b)
	if first:
		aabb = AABB(Vector3.ZERO, Vector3.ONE)
	return aabb


# --- Props ------------------------------------------------------------------

func _build_props() -> void:
	var tree := load(TREE_MODEL) as PackedScene
	var rocks := load(ROCKS_MODEL) as PackedScene
	var placed := 0
	while placed < 8:
		var gx := _rng.randi_range(-GRID, GRID)
		var gz := _rng.randi_range(-GRID, GRID)
		var cell := Vector2i(gx, gz)
		if not _mask.has(cell):
			continue
		if absf(gx) <= 6 and absf(gz) <= 6:
			continue  # keep the build area clear
		var inst: Node3D = (tree if placed % 2 == 0 else rocks).instantiate()
		var aabb := _aabb_of(inst)
		var target := 2.6 if placed % 2 == 0 else 1.4
		var s := target / maxf(aabb.size.y, 0.001)
		inst.scale = Vector3.ONE * s
		inst.position = Vector3(cell.x * CELL + _rng.randf_range(-0.5, 0.5),
				0.0, cell.y * CELL + _rng.randf_range(-0.5, 0.5))
		inst.rotation.y = _rng.randf_range(0.0, TAU)
		add_child(inst)
		placed += 1


# --- Fossils (on the exposed edge faces) ------------------------------------

func _build_fossils() -> void:
	var used: Array = []
	for f in FOSSILS:
		var cell := _pick_edge_cell(used)
		if cell == null:
			continue
		used.append(cell)
		_add_sprite_fossil(f[0], cell, f[1], f[2])


func _pick_edge_cell(used: Array) -> Vector2i:
	for attempt in 200:
		var cell: Vector2i = _edge_cells[_rng.randi_range(0, _edge_cells.size() - 1)]
		if not used.has(cell):
			return cell
	return _edge_cells[0]


func _add_sprite_fossil(tex_path: String, cell: Vector2i, y: float, size: float) -> void:
	var tex := load(tex_path) as Texture2D
	if tex == null:
		return
	var spr := Sprite3D.new()
	spr.texture = tex
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	spr.material_override = mat
	spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	spr.pixel_size = size / 128.0
	# Outward face of the edge cell (first empty neighbor direction).
	var dir: Vector2i = _outward_dirs(cell)[0]
	var cx: float = cell.x * CELL + dir.x * (CELL / 2.0 + 0.07)
	var cz: float = cell.y * CELL + dir.y * (CELL / 2.0 + 0.07)
	spr.position = Vector3(cx, y, cz)
	spr.rotation.y = atan2(float(dir.x), float(dir.y))
	add_child(spr)
