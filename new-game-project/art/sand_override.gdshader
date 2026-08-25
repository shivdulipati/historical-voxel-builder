shader_type spatial;
// BUILD 36: replicate Asset Forge material overrides (e.g. custom1 = sand,
// _defaultMat = marble) on kit blocks. AF's material panel uses UV mapping
// (NOT triplanar — user's panel screenshot, 2026-08-25) with shader Default,
// metallic 0.25, glossiness 0.25. The kit blocks' UVs are the shared
// colormap layout, so the override texture maps per-face exactly as AF's UV
// mapping does.

uniform sampler2D tex : source_color, filter_linear, repeat_enable;

void fragment() {
	ALBEDO = texture(tex, UV).rgb;
	METALLIC = 0.25;
	ROUGHNESS = 0.75;
}
