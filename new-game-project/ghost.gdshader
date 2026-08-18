shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Ghost cell shader: translucent fill with a crisp dark outline band drawn
// from the mesh's own UVs — ONE mesh per ghost, so clearing works and the
// outline can never bleed through the fill (the old rim-behind-fill approach
// made every ghost read as a black block).

uniform vec4 fill_color : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(0.08, 0.06, 0.04, 1.0);
uniform float edge_width : hint_range(0.0, 0.25) = 0.09;
uniform float alpha : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 uv = UV;
	float e = edge_width;
	float edge = step(1.0 - e, uv.x) + step(1.0 - e, uv.y) + step(uv.x, e) + step(uv.y, e);
	float band = clamp(edge, 0.0, 1.0);
	ALBEDO = mix(fill_color.rgb, edge_color.rgb, band);
	ALPHA = mix(alpha, 0.9, band);
}
