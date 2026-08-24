extends Node3D
## BUILD 25 POC v2 → v3: the organic "mini-map" earth slice at 1-unit block
## resolution, ~a third of the original area:
##  * a noise-perturbed island mask (~27 wide, forced solid under the build)
##  * the FLOOR = platformer-kit block-grass models on every interior cell —
##    the block's own brown body IS the strata now, stretched TALL so the
##    cliff reads (no 2D tiles, no strip shader; user: "remove the strata
##    entirely... use tall blocks from the models")
##  * floor tiles overlapped slightly in XZ (OVERLAP) so the beveled top
##    corners can't leave diamond gaps between neighbours (user gap report)
##  * platformer-kit grass overhang blocks along the rim, corners handled
##  * a few platformer trees + rocks
##  * NO fossils yet (user: "we'll tackle those later")
## Pure visuals — no physics, no collisions.

const CELL := 1.0
const GRID := 18            # mask half-extent (units)
const TALL := 4.0           # vertical stretch of the grass blocks = strata height
const OVERLAP := 1.08       # XZ scale per tile: kills the beveled-corner gaps
const BLOB_SEED := 1337

const GRASS_MODEL := "res://art/platformer/block-grass.glb"
const RIM_MODEL := "res://art/platformer/block-grass-overhang-narrow.glb"
const CORNER_MODEL := "res://art/platformer/block-grass-corner-overhang.glb"
const TREE_MODEL := "res://art/platformer/tree.glb"
const ROCKS_MODEL := "res://art/platformer/rocks.glb"

var _rng := RandomNumberGenerator.new()
var _mask := {}          # Vector2i -> true
var _edge_cells: Array = []
var _grass_mesh: Mesh = null


func build(structure_id: String) -> void:
	_clear()
	if structure_id != "mastaba" and structure_id != "diorama_debug":
		return
	_rng.seed = BLOB_SEED
	_gen_mask()
	_build_grass_floor()
	_build_rim()
	_build_props()


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
			# ~13.5-unit radius, two noise octaves → organic outline.
			var r := 13.5 + (_noise(gx * 0.17, gz * 0.17) - 0.5) * 6.0 \
					+ (_noise(gx * 0.53 + 31.7, gz * 0.53 - 7.1) - 0.5) * 2.0
			var solid := d < r
			# The build area (±4 cells around the mastaba) is always solid.
			if absf(gx) <= 4 and absf(gz) <= 4:
				solid = true
			if solid:
				_mask[Vector2i(gx, gz)] = true
	# Prune detached cells: keep only the component connected to the center
	# (noise bumps can leave lone columns floating off the coast).
	var connected := {}
	var queue: Array = [Vector2i(0, 0)]
	connected[Vector2i(0, 0)] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if _mask.has(n) and not connected.has(n):
				connected[n] = true
				queue.append(n)
	_mask = connected
	for gx in range(-GRID, GRID + 1):
		for gz in range(-GRID, GRID + 1):
			if not _mask.has(Vector2i(gx, gz)):
				continue
			if not _mask.has(Vector2i(gx + 1, gz)) or not _mask.has(Vector2i(gx - 1, gz)) \
					or not _mask.has(Vector2i(gx, gz + 1)) or not _mask.has(Vector2i(gx, gz - 1)):
				_edge_cells.append(Vector2i(gx, gz))


# --- Grass floor + strata (the block's own brown body, stretched tall) ----

func _build_grass_floor() -> void:
	var scene := load(GRASS_MODEL) as PackedScene
	var sample := scene.instantiate()
	var mi_node: MeshInstance3D = _first_mesh(sample)
	if mi_node == null or mi_node.mesh == null:
		push_error("blob: block-grass has no mesh")
		sample.free()
		return
	_grass_mesh = mi_node.mesh
	var aabb := _grass_mesh.get_aabb()
	# Top-pinned tall scale: world top stays at y=0, the body runs down to -TALL.
	var top_mesh: float = aabb.position.y + aabb.size.y
	var scale_v := Vector3(OVERLAP, TALL, OVERLAP)
	var origin_y: float = -top_mesh * TALL
	sample.free()

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _grass_mesh
	var interior: Array = []
	for cell in _mask:
		if not _edge_cells.has(cell):
			interior.append(cell)
	mm.instance_count = interior.size()
	var i := 0
	for cell in interior:
		var t := Transform3D(Basis.IDENTITY.scaled(scale_v),
				Vector3(cell.x * CELL, origin_y, cell.y * CELL))
		mm.set_instance_transform(i, t)
		i += 1
	var mi := MultiMeshInstance3D.new()
	mi.name = "GrassFloor"
	mi.multimesh = mm
	add_child(mi)


# --- Rim overhang (grass blocks with the lip over the strata) --------------

func _build_rim() -> void:
	var rim := load(RIM_MODEL) as PackedScene
	var corner := load(CORNER_MODEL) as PackedScene
	var scale_v := Vector3(OVERLAP, TALL, OVERLAP)
	for cell in _edge_cells:
		var dirs := _outward_dirs(cell)
		if dirs.size() == 0:
			continue
		var is_corner: bool = dirs.size() >= 2 \
				and (dirs[0] + dirs[1]).x != 0 and (dirs[0] + dirs[1]).y != 0
		var inst: Node3D = (corner if is_corner else rim).instantiate()
		var m: MeshInstance3D = _first_mesh(inst)
		var aabb := m.mesh.get_aabb() if m != null and m.mesh != null else AABB(Vector3.ZERO, Vector3.ONE)
		inst.scale = scale_v
		# Top-pinned: the lip stays at world y=0, the body runs down to -TALL.
		inst.position = Vector3(cell.x * CELL,
				-(aabb.position.y + aabb.size.y) * TALL, cell.y * CELL)
		var dir: Vector2i = dirs[0]
		# +Z (the lip side) faces outward.
		inst.rotation.y = atan2(float(dir.x), float(dir.y))
		add_child(inst)


func _outward_dirs(cell: Vector2i) -> Array:
	var out: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _mask.has(cell + d):
			out.append(d)
	return out


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null


# --- Props ------------------------------------------------------------------

func _build_props() -> void:
	var tree := load(TREE_MODEL) as PackedScene
	var rocks := load(ROCKS_MODEL) as PackedScene
	var placed := 0
	while placed < 6:
		var gx := _rng.randi_range(-GRID, GRID)
		var gz := _rng.randi_range(-GRID, GRID)
		var cell := Vector2i(gx, gz)
		if not _mask.has(cell):
			continue
		if absf(gx) <= 5 and absf(gz) <= 5:
			continue  # keep the build area clear
		var inst: Node3D = (tree if placed % 2 == 0 else rocks).instantiate()
		var m: MeshInstance3D = _first_mesh(inst)
		var aabb := m.mesh.get_aabb() if m != null and m.mesh != null else AABB(Vector3.ZERO, Vector3.ONE)
		var target := 2.2 if placed % 2 == 0 else 1.2
		var s := target / maxf(aabb.size.y, 0.001)
		inst.scale = Vector3.ONE * s
		inst.position = Vector3(cell.x * CELL + _rng.randf_range(-0.3, 0.3),
				0.0, cell.y * CELL + _rng.randf_range(-0.3, 0.3))
		inst.rotation.y = _rng.randf_range(0.0, TAU)
		add_child(inst)
		placed += 1
