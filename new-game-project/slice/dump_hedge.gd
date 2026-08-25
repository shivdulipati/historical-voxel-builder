extends SceneTree
## dump_hedge.gd — print the hedge-corner GLB's mesh vertices so the L's
## actual notch/elbow orientation in GLB-local space is known (BUILD 38).

func _initialize() -> void:
	var ps := load("res://art/platformer/hedge-corner.glb") as PackedScene
	var inst := ps.instantiate()
	root.add_child(inst)
	var mi := inst.find_child("", true, false) as MeshInstance3D
	if mi == null:
		# find any MeshInstance3D
		for c in inst.find_children("*", "MeshInstance3D", true, false):
			mi = c
			break
	var mesh := mi.mesh as ArrayMesh
	var verts := PackedVector3Array()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		verts.append_array(arr[Mesh.ARRAY_VERTEX])
	print("HEDGE VERTS:", verts.size())
	# min-y slice = the base footprint in GLB local XZ
	var miny := 1e9
	for v in verts:
		miny = minf(miny, v.y)
	var base := []
	for v in verts:
		if v.y < miny + 0.02:
			base.append(v)
	print("base verts:", base.size())
	var occ := {"+x+z": 0, "+x-z": 0, "-x+z": 0, "-x-z": 0}
	for v in base:
		occ["+x+z" if v.x >= 0 else "-x+z" if v.z >= 0 else "+x-z" if v.x >= 0 else "-x-z"] += 1
	# careful: build the key properly
	occ = {}
	for v in base:
		var key := ("+" if v.x >= 0.0 else "-") + "x" + ("+" if v.z >= 0.0 else "-") + "z"
		occ[key] = occ.get(key, 0) + 1
	print("base quadrants (GLB local XZ):", occ)
	# full extent per axis
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	print("AABB local: origin=", lo, " size=", hi - lo)
	quit()
