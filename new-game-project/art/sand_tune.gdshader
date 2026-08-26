shader_type spatial;
// BUILD 46: live sand-tune override. Samples AF's sand dune texture through
// the per-face UVs at a runtime-adjustable density. scale = tiles per unit:
// small values (0.1) = fine grain -> uniform sand look; large values (2+)
// = coarse dunes. The user tunes it live in the editor with [ and ] and
// reports the value; the chosen scale becomes the baked default.

uniform sampler2D tex : source_color, filter_linear, repeat_enable;
uniform float scale = 0.25;
uniform float rot = 0.0;  // degrees — rotates the texture pattern

void fragment() {
	vec2 uv = UV * scale;
	float r = radians(rot);
	uv = mat2(cos(r), -sin(r), sin(r), cos(r)) * uv;
	ALBEDO = texture(tex, uv).rgb;
	METALLIC = 0.25;
	ROUGHNESS = 0.75;
}
