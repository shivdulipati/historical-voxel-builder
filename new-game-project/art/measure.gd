extends Node
## art/measure.gd — load key GLBs headless and print their AABB bounds so the
## diorama config uses correct per-model scales (Kenney packs vary in units).

const MODELS := [
	"tree_palmTall", "tree_palmShort", "tree_palmDetailedTall", "tree_palmBend",
	"tree_oak", "tree_pineTallA", "rock_largeA", "rock_largeB", "rock_smallA",
	"rock_smallFlatA", "stone_smallA", "stone_smallFlatA", "stone_tallA",
	"grass", "grass_large", "flower_redA", "plant_bush", "log",
	"statue_obelisk", "statue_column", "ground_grass", "ground_pathRocks",
	"crops_dirtSingle", "mushroom_red", "stump_round",
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
		print("%-22s min=%s max=%s size=%s" % [name, aabb.position, aabb.end, aabb.size])
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
				var t: AABB = a
				if first:
					out = t
					first = false
				else:
					out = out.merge(t)
		for child in n.get_children():
			if child is Node3D:
				stack.push_back(child)
	return out
