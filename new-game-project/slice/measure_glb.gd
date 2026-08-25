extends SceneTree
## measure_glb.gd — print AABB (size + origin) of key diorama GLBs (BUILD 35).

func _initialize() -> void:
	var files := [
		"res://art/platformer/block-grass-large-tall.glb",
		"res://art/platformer/hedge-corner.glb",
		"res://art/platformer/block-snow-low-large.glb",
		"res://art/platformer/block-snow-large.glb",
		"res://art/platformer/icosphere_half.glb",
		"res://art/platformer/stairs_half_corner.glb",
		"res://art/platformer/debris_stone.glb",
	]
	for f in files:
		var ps := load(f) as PackedScene
		if ps == null:
			print(f, " MISSING")
			continue
		var inst := ps.instantiate()
		root.add_child(inst)
		var aabb := AABB()
		for vi in inst.find_children("*", "VisualInstance3D", true, false):
			aabb = aabb.merge((vi as VisualInstance3D).get_aabb())
		print(f.split("/")[-1], " size=", aabb.size, " origin=", aabb.position)
		inst.free()
	quit()
