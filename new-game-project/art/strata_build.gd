extends Node
## One-shot tool: composites the earth-slice strata strip from Kenney voxel-pack
## tiles (CC0) into res://art/textures/strata_default.png.
##
## The strip is 256x1024: 128px per world unit (matching the 1-unit voxel grid),
## 8 units tall, one band per geological layer. Every band height is a multiple
## of 128px so vertical tiling is seamless; horizontal sampling is offset per
## 8px row-group so the 128px tile repeat is invisible (the bands read as one
## continuous noise field instead of repeated tiles).
##
## Run: Godot --headless --path . res://art/strata_build.tscn

const OUT_PATH := "res://art/textures/strata_default.png"
const STRIP_W := 256
const PX_PER_UNIT := 128

## [tile_file, height_in_units]
const BANDS: Array = [
	["res://art/2d_src/sand.png", 1.0],
	["res://art/2d_src/dirt_sand.png", 1.0],
	["res://art/2d_src/dirt.png", 2.0],
	["res://art/2d_src/gravel_dirt.png", 1.5],
	["res://art/2d_src/stone.png", 1.5],
	["res://art/2d_src/brick_grey.png", 1.0],
]

## [band_index, x0, x1, blend] — gold ore pockets painted into the stone band.
const GOLD_POCKETS: Array = [
	[4, 34, 72, 0.6],
	[4, 168, 208, 0.55],
]

func _ready() -> void:
	var total := 0.0
	for band in BANDS:
		total += band[1]
	assert(absf(total - 8.0) < 0.01, "strata bands must sum to 8.0 units")

	var strip := Image.create(STRIP_W, int(total * PX_PER_UNIT), false, Image.FORMAT_RGBA8)
	var tiles := {}  # path -> Image
	for band in BANDS:
		if not tiles.has(band[0]):
			var img := Image.load_from_file(band[0])
			assert(img != null, "cannot load tile: " + band[0])
			tiles[band[0]] = img
	# Extra tiles used only for detail blending (gold pockets).
	var ore_img := Image.load_from_file("res://art/2d_src/stone_gold.png")
	assert(ore_img != null, "cannot load stone_gold.png")
	tiles["res://art/2d_src/stone_gold.png"] = ore_img

	var row := 0
	for bi in range(BANDS.size()):
		var band: Array = BANDS[bi]
		var tile: Image = tiles[band[0]]
		var band_h := int(band[1] * PX_PER_UNIT)
		for r in range(band_h):
			# Per-8px-group horizontal offset breaks the tile's 128px repeat.
			var off: int = (row / 8) * 53 % 128
			for x in range(STRIP_W):
				var c: Color = tile.get_pixel((x + off) % 128, r % 128)
				strip.set_pixel(x, row, c)
			row += 1
		# Dark seam line above each band boundary (reads as a strata break).
		for d in range(3):
			var seam := row - 1 - d
			if seam >= 0:
				for x in range(STRIP_W):
					strip.set_pixel(x, seam, strip.get_pixel(x, seam).darkened(0.45))

	# Gold ore pockets in the stone band.
	for pocket in GOLD_POCKETS:
		var band_h := int(BANDS[pocket[0]][1] * PX_PER_UNIT)
		var base := 0
		for b in range(pocket[0]):
			base += int(BANDS[b][1] * PX_PER_UNIT)
		var ore: Image = tiles["res://art/2d_src/stone_gold.png"]
		for r in range(18):
			for x in range(pocket[1], pocket[2]):
				var src: Color = ore.get_pixel((x * 7 + r * 13) % 128, (r * 5) % 128)
				var dst: Color = strip.get_pixel(x, base + band_h - 26 + r)
				strip.set_pixel(x, base + band_h - 26 + r, dst.lerp(src, pocket[3]))

	var dir_ok := DirAccess.make_dir_recursive_absolute("res://art/textures")
	assert(dir_ok == OK, "cannot create res://art/textures")
	var err := strip.save_png(OUT_PATH)
	print("STRATA-BUILD: saved ", OUT_PATH, " err=", err,
			" size=", strip.get_width(), "x", strip.get_height())
	get_tree().quit(0)
