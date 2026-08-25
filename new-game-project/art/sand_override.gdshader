shader_type spatial;
// BUILD 39: replicate Asset Forge material overrides (custom1 = sand,
// _defaultMat = marble). AF's material panel uses UV mapping (NOT triplanar —
// user's panel screenshot, 2026-08-25) with shader Default, metallic 0.25,
// glossiness 0.25.
//
// Sand blocks carry a BAKED per-face planar UV1 (TEXCOORD_1 -> Godot UV2,
// 1 tile per unit, continuous across faces) so the sand looks identical on
// every block (floor tiles, stairs, debris, hedges). The marble domes use
// their own authored UVs (use_uv2 = false).

uniform sampler2D tex : source_color, filter_linear, repeat_enable;
uniform bool use_uv2 = true;

void fragment() {
	vec2 uv = use_uv2 ? UV2 : UV;
	ALBEDO = texture(tex, uv).rgb;
	METALLIC = 0.25;
	ROUGHNESS = 0.75;
}
