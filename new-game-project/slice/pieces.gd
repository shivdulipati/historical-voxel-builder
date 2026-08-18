extends RefCounted
## pieces.gd — Multi-cell piece registry for the History in Voxels slice.
## A piece is a rigid compound of unit cells placed as ONE body: it fills
## several target cells at once, validates against its own support rule, and
## is removed atomically. Cells are local offsets from the origin (0,0,0) —
## the piece's handle cell. A held piece rotates 90° around Y per second-finger
## tap (single axis); any piece that must face a different axis in-game should
## be offered as an oriented variant in the tray (per playtest decision).

static func pieces() -> Dictionary:
	return {
		## Göbekli T-cap: 3-wide head resting on a single pillar stem.
		"t_cap": {
			"name": "T-Cap",
			"cells": [Vector3i(-1, 0, 0), Vector3i(0, 0, 0), Vector3i(1, 0, 0)],
			"anchors": [Vector3i(0, 0, 0)],
			"min_anchors": 1,
		},
		## Persepolis roof: 3x3 slab resting on the four column tops.
		"plate_3x3": {
			"name": "Roof Slab",
			"cells": [
				Vector3i(-1, 0, -1), Vector3i(0, 0, -1), Vector3i(1, 0, -1),
				Vector3i(-1, 0, 0), Vector3i(0, 0, 0), Vector3i(1, 0, 0),
				Vector3i(-1, 0, 1), Vector3i(0, 0, 1), Vector3i(1, 0, 1),
			],
			"anchors": [
				Vector3i(-1, 0, -1), Vector3i(1, 0, -1),
				Vector3i(-1, 0, 1), Vector3i(1, 0, 1),
			],
			"min_anchors": 2,
		},
	}


## Rotate a local cell 90° around Y, `steps` times (0-3).
static func rotate_cell(cell: Vector3i, steps: int) -> Vector3i:
	var c := cell
	for i in steps % 4:
		c = Vector3i(-c.z, c.y, c.x)
	return c
