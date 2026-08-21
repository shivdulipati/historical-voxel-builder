extends Node
## art/measure.gd — load key GLBs headless and print their AABB bounds + the
## first material's albedo/vertex-color state, so the diorama config uses
## correct per-model scales and TRUE default colors.

const MODELS := [
	"tree_palmTall", "tree_palmShort", "tree_palmDetailedTall", "tree_palmBend",
	"tree_oak", "tree_pineTallA", "rock_largeA", "rock_largeB", "rock_smallA",
	"rock_smallFlatA", "stone_smallA", "stone_smallFlatA", "stone_tallA",
	"grass", "grass_large", "flower_redA", "flower_yellowA", "plant_bush",
	"plant_bushSmall", "log", "log_stack", "statue_obelisk", "statue_column",
	"ground_grass", "ground_pathRocks", "ground_pathStraight", "crops_dirtSingle",
	"mushroom_red", "stump_round", "tent_smallClosed", "campfire_stones",
	"cactus_short", "lily_small",
]

func _ready() -> void:
	for name in MODELS:
		var path := "res://art/nature/%s.glb" % name
		if not ResourceLoader.exists(path):
			print("%-22s MISSING" % name)
			continue
		var ps: PackedScene = load(path)
		var inst := ps.instantiate()
		add_child(inst)
		await get_tree().process_frame
		var aabb: AABB = _scene_aabb(inst)
		var mat_desc := _first_material_desc(inst)
		print("%-22s size=%s %s" % [name, aabb.size, mat_desc])
		inst.queue_free()
	await get_tree().process_frame
	get_tree().quit()


## Merge AABBs of every VisualInstance3D descendant (glTF roots are Node3D).
func _scene_aabb(node: Node3D) -> AABB:
	var out: AABB
	var first := true
	var stack: Array[Node3D] = [node]
	while not stack.is_empty():
		var n: Node3D = stack.pop_back()
		if n is VisualInstance3D:
			var a: AABB = (n as VisualInstance3D).get_aabb()
			if a.size.length() > 0.0:
				if first:
					out = a
					first = false
				else:
					out = out.merge(a)
		for child in n.get_children():
			if child is Node3D:
				stack.push_back(child)
	return out


## Describe the first StandardMaterial3D found (albedo + vertex-color flag).
func _first_material_desc(node: Node3D) -> String:
	var stack: Array[Node3D] = [node]
	while not stack.is_empty():
		var n: Node3D = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var m: Material = mi.material_override
			if m == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
				m = mi.mesh.surface_get_material(0)
			if m is StandardMaterial3D:
				var sm := m as StandardMaterial3D
				return "albedo=%s vcolor=%s" % [sm.albedo_color, sm.vertex_color_use_as_albedo]
		for child in n.get_children():
			if child is Node3D:
				stack.push_back(child)
	return "no-material"
