extends Node3D
## The earth-slice diorama: a thick slab of earth (sand top + strata sides +
## bedrock bottom) floating in pure sky, with fun fossils embedded in the
## cross-section (gold ore, coins, gems, a bone). Replaces the old flat-floor
## + prop-scatter diorama. Pure visuals — no physics, no collisions.

const SLAB_HALF := 22.0    # 44x44 top surface
const SLAB_DEPTH := 8.0    # how deep the chunk of earth goes
## How far fossils protrude OUTSIDE the side faces: a decal placed just
## outside the wall plane is between the outside viewer and the wall, so side
## views (camera outside the slab) see it flat against the strata. Placing it
## inside the face hides it BEHIND its own wall — the BUILD 23 occlusion bug.
## The part of a SURFACE FIND (y ≈ -0.15) above the top rim is additionally
## visible from elevated build views, past the wall's top edge.
const FOSSIL_PROUD := 0.07

## [texture path, face, y (depth), along (position on the face), size]
## Deep fossils live in the strata bands — only visible from eye-level side
## views (the top face hides anything below it from elevated cameras).
## The three y≈-0.15 entries are SURFACE FINDS: they poke just above the top
## rim so the default build view hints that the strata hides treasures.
const FOSSILS: Array = [
	["res://art/2d_src/ore_gold.png", "+x", -5.2, 6.0, 0.9],
	["res://art/2d_src/coin_gold.png", "-x", -1.1, -8.0, 0.6],
	["res://art/2d_src/gem_green.png", "-x", -6.3, 3.0, 0.55],
	["res://art/2d_src/ore_gold.png", "+z", -4.7, -7.0, 0.85],
	["res://art/2d_src/gem_red.png", "-z", -5.5, -3.0, 0.5],
	["res://art/2d_src/coin_gold.png", "-z", -0.9, 9.0, 0.6],
	["res://art/2d_src/coin_gold.png", "+z", -1.2, 11.0, 0.55],
	# Surface finds: all on the NEAR +x wall (the default build view's right
	# rim — clear of the ghost-scaffold zone) and sized to poke above the rim.
	["res://art/2d_src/ore_gold.png", "+x", -0.1, 12.0, 1.0],
	["res://art/2d_src/coin_gold.png", "+x", -0.1, 4.0, 0.8],
	["res://art/2d_src/gem_red.png", "+x", -0.1, -6.0, 0.65],
]

## [face, y, along, size] — the procedural voxel-style bone (no bone asset in
## any pack, so it's built from primitives: shaft + two knobs).
const BONES: Array = [
	["+z", -3.6, -11.0, 0.8],
]

var fossil_count := 0
var bone_count := 0


func build(structure_id: String) -> void:
	_clear()
	# Only mastaba (and the stage-only debug level, which shows the mastaba
	# stage in isolation) has the earth slice for now. Other structures get
	# nothing until their biomes roll out.
	if structure_id != "mastaba" and structure_id != "diorama_debug":
		return
	_build_slab()
	_build_fossils()
	_build_bones()


func _clear() -> void:
	# Immediate free, NOT queue_free: build() can run twice in one frame
	# (structure reload), and a queued old child still owns its name — the
	# replacement gets auto-renamed "@Sprite3D@73"-style and name lookups in
	# tests/diagnostics break (the BUILD 23 rename bug).
	for child in get_children():
		child.free()
	fossil_count = 0
	bone_count = 0


# --- Slab -------------------------------------------------------------------

func _build_slab() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(SLAB_HALF * 2.0, SLAB_DEPTH, SLAB_HALF * 2.0)
	var mi := MeshInstance3D.new()
	mi.name = "EarthSlab"
	mi.mesh = mesh
	mi.position = Vector3(0.0, -SLAB_DEPTH / 2.0, 0.0)  # top face at y=0
	mi.material_override = _slab_material()
	add_child(mi)


func _slab_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://art/strata_face.gdshader")
	mat.set_shader_parameter("strata_tex", load("res://art/textures/strata_default.png"))
	mat.set_shader_parameter("top_tex", load("res://art/2d_src/sand.png"))
	mat.set_shader_parameter("depth", SLAB_DEPTH)
	mat.set_shader_parameter("tile", 1.0)
	return mat


# --- Fossils ----------------------------------------------------------------

func _build_fossils() -> void:
	for f in FOSSILS:
		_add_sprite_fossil(f[0], f[1], f[2], f[3], f[4])


## Embed a 2D art fossil flat against a side face (Sprite3D, unshaded — the
## voxel art is flat-lit by design). It pokes out of the strata by a hair so
## it reads as embedded but visible from side views.
func _add_sprite_fossil(tex_path: String, face: String, y: float, along: float, size: float) -> void:
	var tex := load(tex_path) as Texture2D
	if tex == null:
		push_error("earth_slice: cannot load fossil texture " + tex_path)
		return
	var spr := Sprite3D.new()
	spr.texture = tex
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	spr.material_override = mat
	spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	spr.pixel_size = size / 128.0  # 128px art scaled to `size` world units tall
	spr.name = "Fossil" + tex_path.get_file().get_basename()
	_place_on_face(spr, face, y, along)
	add_child(spr)
	fossil_count += 1


func _place_on_face(node: Node3D, face: String, y: float, along: float) -> void:
	match face:
		"+x":
			node.position = Vector3(SLAB_HALF + FOSSIL_PROUD, y, along)
			node.rotation.y = PI / 2.0
		"-x":
			node.position = Vector3(-SLAB_HALF - FOSSIL_PROUD, y, along)
			node.rotation.y = -PI / 2.0
		"+z":
			node.position = Vector3(along, y, SLAB_HALF + FOSSIL_PROUD)
			node.rotation.y = 0.0
		"-z":
			node.position = Vector3(along, y, -SLAB_HALF - FOSSIL_PROUD)
			node.rotation.y = PI


# --- Bone -------------------------------------------------------------------

func _build_bones() -> void:
	for b in BONES:
		_add_bone(b[0], b[1], b[2], b[3])


func _add_bone(face: String, y: float, along: float, size: float) -> void:
	var bone := Node3D.new()
	bone.name = "FossilBone"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.89, 0.79)
	mat.roughness = 1.0

	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.085
	cyl.bottom_radius = 0.085
	cyl.height = 0.5
	shaft.mesh = cyl
	shaft.rotation.z = PI / 2.0  # Y-aligned cylinder → along +X: the bone lies
	# ALONG the wall face (horizontal), not pointing into it (BUILD 23 fix —
	# the old rotation.x=PI/2 made the bone read end-on as a tiny blob).
	shaft.material_override = mat
	bone.add_child(shaft)

	for knob_x in [-0.26, 0.26]:
		var knob := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.14
		sph.height = 0.28
		knob.mesh = sph
		knob.position.x = knob_x
		knob.material_override = mat
		bone.add_child(knob)

	bone.scale = Vector3.ONE * size
	_place_on_face(bone, face, y, along)
	add_child(bone)
	bone_count += 1
