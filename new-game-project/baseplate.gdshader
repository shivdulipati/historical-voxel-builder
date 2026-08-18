shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Baseplate tile shader: tile colour with a dark grout line around each edge,
// so the build grid reads clearly from the top-down view.

uniform vec4 tile_color : source_color = vec4(0.604, 0.498, 0.314, 1.0);
uniform vec4 line_color : source_color = vec4(0.25, 0.19, 0.11, 1.0);
uniform float line_width : hint_range(0.0, 0.25) = 0.09;

void fragment() {
	vec2 uv = UV;
	float e = line_width;
	float edge = step(1.0 - e, uv.x) + step(1.0 - e, uv.y) + step(uv.x, e) + step(uv.y, e);
	ALBEDO = mix(tile_color.rgb, line_color.rgb, clamp(edge, 0.0, 1.0));
}
