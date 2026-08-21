extends Node3D
## test_support.gd — BUILD 12: audits EVERY structure's cells for support
## (below in core/zenith/survivor union, or y==0) and within placement limits.
## Piece-covered cells (e.g. T-cap overhangs, roof-slab edges) are expected
## false positives — the piece's anchor carries them.

const STRUCTS = preload("res://slice/structures.gd")

func _ready() -> void:
	var all := STRUCTS.structures()
	var flagged := []
	for i in range(all.size()):
		var st := all[i]
		var union := {}
		union.merge(st["core"])
		union.merge(st["zenith"])
		union.merge(st["survivor"])
		var lim: Vector3 = st["limits"]
		for zone in ["core", "zenith", "survivor"]:
			for pos in st[zone]:
				var below := Vector3i(pos.x, pos.y - 1, pos.z)
				if absi(pos.x) > int(lim.x) or absi(pos.z) > int(lim.z) or pos.y > int(lim.y):
					flagged.append("%s[%s] %s OUT_OF_LIMITS" % [st["id"], zone, pos])
				if pos.y > 0 and not union.has(below):
					flagged.append("%s[%s] %s UNSUPPORTED" % [st["id"], zone, pos])
	if flagged.is_empty():
		print("SUPPORT-TEST: ALL PASS")
	else:
		for f in flagged:
			print("SUPPORT-TEST: FLAG ", f)
	get_tree().quit()
