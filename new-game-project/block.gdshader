shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

// Erase-mode highlight: pulsing edge outline when `outline` > 0. Edges are
// detected in LOCAL SPACE (two axes near the box surface) — the same
// technique as ghost.gdshader; BoxMesh UVs cannot drive edge bands.

uniform float outline : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(1.0, 0.8, 0.1, 1.0);
uniform float outline_width : hint_range(0.0, 0.25) = 0.035;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	ALPHA = alpha;
	vec3 d = abs(local_pos);
	float e = outline_width;
	float ex = step(0.5 - e, d.x);
	float ey = step(0.5 - e, d.y);
	float ez = step(0.5 - e, d.z);
	float band = clamp(ex * (ey + ez) + ey * ez, 0.0, 1.0);
	ALBEDO = mix(ALBEDO, outline_color.rgb, band * outline);
}
