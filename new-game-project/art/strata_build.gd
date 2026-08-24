extends Node
## One-shot tool: composites strata strips from Kenney tiles (CC0).
##
## Two outputs:
##  * res://art/textures/strata_default.png — voxel-pack tiles, 128px/unit
##    (the BUILD 23 look).
##  * res://art/textures/strata_platformer.png — new-platformer-pack-1.1
##    2D tiles, 64px/unit, with a grass cap band (the BUILD 24 look).
##
## Band heights are multiples of the tile size so vertical tiling is seamless;
## horizontal sampling is offset per row-group so the tile repeat is invisible
## (each band reads as one continuous noise field).
##
## Run: Godot --headless --path . res://art/strata_build.tscn

## [out_path, px_per_unit, [ [tile_path, height_units], ... ], gold_pockets, mode]
## mode: "noise" = per-row offset scramble (voxel-pack noise tiles);
##       "straight" = sample tiles as designed (platformer tiles are full
##       terrain blocks with a designed top edge and tile perfectly).
## gold_pockets: [ [band_index, x0, x1, blend], ... ] — ore pockets blended
## into that band (uses stone_gold.png; pass [] to skip).
const THEMES := [
	[
		"res://art/textures/strata_default.png", 128,
		[
			["res://art/2d_src/sand.png", 1.0],
			["res://art/2d_src/dirt_sand.png", 1.0],
			["res://art/2d_src/dirt.png", 2.0],
			["res://art/2d_src/gravel_dirt.png", 1.5],
			["res://art/2d_src/stone.png", 1.5],
			["res://art/2d_src/brick_grey.png", 1.0],
		],
		[[4, 34, 72, 0.6], [4, 168, 208, 0.55]],
		"noise",
	],
	[
		"res://art/textures/strata_platformer.png", 64,
		[
			["res://art/2d_src/platformer/terrain_grass_block_center.png", 1.0],
			["res://art/2d_src/platformer/terrain_sand_block_center.png", 1.5],
			["res://art/2d_src/platformer/terrain_dirt_block_center.png", 1.5],
			["res://art/2d_src/platformer/terrain_stone_block_center.png", 2.0],
			["res://art/2d_src/platformer/terrain_snow_block_center.png", 2.0],
		],
		[],
		"straight",
	],
]

const STRIP_W := 256

func _ready() -> void:
	for theme in THEMES:
		_build_strip(theme[0], theme[1], theme[2], theme[3], theme[4])
	print("STRATA-BUILD: all themes saved")
	get_tree().quit(0)


func _build_strip(out_path: String, px_per_unit: int, bands: Array, gold_pockets: Array, mode: String) -> void:
	var total := 0.0
	for band in bands:
		total += band[1]
	assert(absf(total - 8.0) < 0.01, "strata bands must sum to 8.0 units")

	var strip := Image.create(STRIP_W, int(total * px_per_unit), false, Image.FORMAT_RGBA8)
	var tiles := {}  # path -> Image
	for band in bands:
		if not tiles.has(band[0]):
			var img := Image.load_from_file(band[0])
			assert(img != null, "cannot load tile: " + band[0])
			tiles[band[0]] = img

	var row := 0
	for band in bands:
		var tile: Image = tiles[band[0]]
		var band_h := int(band[1] * px_per_unit)
		for r in range(band_h):
			var off := 0
			if mode == "noise":
				# Per-8px-group horizontal offset breaks the tile's repeat.
				off = (row / 8) * 53 % tile.get_width()
			for x in range(STRIP_W):
				var c: Color = tile.get_pixel((x + off) % tile.get_width(), r % tile.get_height())
				strip.set_pixel(x, row, c)
			row += 1
		# Dark seam line above each band boundary (reads as a strata break).
		for d in range(3):
			var seam := row - 1 - d
			if seam >= 0:
				for x in range(STRIP_W):
					strip.set_pixel(x, seam, strip.get_pixel(x, seam).darkened(0.45))

	# Gold ore pockets blended into their band (uses stone_gold.png).
	if not gold_pockets.is_empty():
		var ore := Image.load_from_file("res://art/2d_src/stone_gold.png")
		assert(ore != null, "cannot load stone_gold.png")
		for pocket in gold_pockets:
			var base := 0
			for b in range(pocket[0]):
				base += int(bands[b][1] * px_per_unit)
			var band_h := int(bands[pocket[0]][1] * px_per_unit)
			for r in range(18):
				for x in range(pocket[1], pocket[2]):
					var src: Color = ore.get_pixel((x * 7 + r * 13) % 128, (r * 5) % 128)
					var dst: Color = strip.get_pixel(x, base + band_h - 26 + r)
					strip.set_pixel(x, base + band_h - 26 + r, dst.lerp(src, pocket[3]))

	var dir_ok := DirAccess.make_dir_recursive_absolute("res://art/textures")
	assert(dir_ok == OK, "cannot create res://art/textures")
	var err := strip.save_png(out_path)
	print("STRATA-BUILD: saved ", out_path, " err=", err,
			" size=", strip.get_width(), "x", strip.get_height())
