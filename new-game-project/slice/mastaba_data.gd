extends RefCounted
## mastaba_data.gd — Pure mathematical spec for the Mastaba of Ti playtest slice.
## No eyeballing: every cell coordinate is explicit. Derived plan/elevation views
## are computed from these dicts, never hand-drawn.

## Material color names -> RGBA (rough Egyptian palette)
const COLORS := {
	"mudbrick":    Color("#C08552"),
	"mudbrick_old": Color("#9C6B3F"),   # weathered, excavated state
	"limestone":   Color("#F2EBD9"),
	"redband":     Color("#C1440E"),
	"dust":        Color("#E0C9A6"),
}

## ---- BEAT 1 · THE RAISING (core massing, "bones") ----
## Stepped mastaba: 5x3 base, 3x1 upper tier (battered silhouette).
## Grid centered on origin; y=0 is the ground plane.
const CORE_CELLS := {
	# base layer y=0 (15)
	Vector3i(-2,0,-1): "mudbrick", Vector3i(-1,0,-1): "mudbrick", Vector3i(0,0,-1): "mudbrick", Vector3i(1,0,-1): "mudbrick", Vector3i(2,0,-1): "mudbrick",
	Vector3i(-2,0,0): "mudbrick", Vector3i(-1,0,0): "mudbrick", Vector3i(0,0,0): "mudbrick", Vector3i(1,0,0): "mudbrick", Vector3i(2,0,0): "mudbrick",
	Vector3i(-2,0,1): "mudbrick", Vector3i(-1,0,1): "mudbrick", Vector3i(0,0,1): "mudbrick", Vector3i(1,0,1): "mudbrick", Vector3i(2,0,1): "mudbrick",
	# upper tier y=1 (3)
	Vector3i(-1,1,0): "mudbrick", Vector3i(0,1,0): "mudbrick", Vector3i(1,1,0): "mudbrick",
}

## ---- BEAT 2 · THE RESTORATION (zenith: cornice, entrance columns, offering table) ----
const ZENITH_CELLS := {
	# red terracotta cornice on the roof edge, y=2 (3)
	Vector3i(-1,2,0): "redband", Vector3i(0,2,0): "redband", Vector3i(1,2,0): "redband",
	# white limestone entrance columns flanking the east face (4)
	Vector3i(2,1,-1): "limestone", Vector3i(2,1,1): "limestone",
	Vector3i(2,0,-1): "limestone", Vector3i(2,0,1): "limestone",
	# offering table in front of the entrance (1)
	Vector3i(3,0,0): "limestone",
}

## ---- BEAT 4 · THE EXCAVATION ----
## What survives the millennia (today's excavated state): the base layer minus
## three cells (a broken corner, the stripped doorway, a missing block).
const SURVIVOR_CELLS := {
	Vector3i(-2,0,-1): "mudbrick_old", Vector3i(-1,0,-1): "mudbrick_old", Vector3i(0,0,-1): "mudbrick_old", Vector3i(1,0,-1): "mudbrick_old", Vector3i(2,0,-1): "mudbrick_old",
	Vector3i(-2,0,0): "mudbrick_old", Vector3i(-1,0,0): "mudbrick_old", Vector3i(1,0,0): "mudbrick_old",
	Vector3i(-2,0,1): "mudbrick_old", Vector3i(-1,0,1): "mudbrick_old", Vector3i(0,0,1): "mudbrick_old", Vector3i(2,0,1): "mudbrick_old",
	# the offering table survived, weathered
	Vector3i(3,0,0): "limestone",
}
## Missing from survivor set (the absences are part of the story):
## (0,0,0) stripped doorway · (2,0,0) fallen block · (1,0,1) broken corner

## Dust overlay cells for the excavation beat: every survivor cell gets a dust mound.
static func dust_cells() -> Dictionary:
	var d := {}
	for pos in SURVIVOR_CELLS:
		d[pos] = "dust"
	return d

## Grid limits shared by all beats (x to 3 for the offering table).
const LIMIT_X := 3.0
const LIMIT_Z := 1.0
const LIMIT_Y := 3.0

## ---- Derived views (for the blueprint sheet) ----
## Combined occupancy for the blueprint: core + zenith.
static func combined_cells() -> Dictionary:
	var all := {}
	for pos in CORE_CELLS:
		all[pos] = CORE_CELLS[pos]
	for pos in ZENITH_CELLS:
		all[pos] = ZENITH_CELLS[pos]
	return all

## Plan view: top-down (x,z) footprint per y layer. Returns {y: {Vector2i: color}}.
static func plan_layers() -> Dictionary:
	var layers := {}
	var all := combined_cells()
	for pos in all:
		var layer: int = pos.y
		if not layers.has(layer):
			layers[layer] = {}
		layers[layer][Vector2i(pos.x, pos.z)] = all[pos]
	return layers

## Elevation view (east/front): for each (z,y), occupied if any x holds a cell.
## Returns {Vector2i(z, y): color}.
static func elevation_cells() -> Dictionary:
	var elev := {}
	var all := combined_cells()
	for pos in all:
		var key := Vector2i(pos.z, pos.y)
		elev[key] = all[pos]
	return elev
