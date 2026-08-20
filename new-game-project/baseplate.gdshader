shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Baseplate tile shader: tile colour with a dark grout line around the tile's
// perimeter. Edge detection is LOCAL-SPACE based (abs(VERTEX) near the tile
// edge), not UV-based — BoxMesh UV strips share faces, which made the old
// UV-step version draw lines in only one direction. The tile is FLAT (|y| is
// tiny), so a grout line is where either |x| or |z| touches the surface —
// the top-face perimeter plus the thin walls, forming a full 2D grid.

uniform vec4 tile_color : source_color = vec4(0.604, 0.498, 0.314, 1.0);
uniform vec4 line_color : source_color = vec4(0.25, 0.19, 0.11, 1.0);
uniform float line_width : hint_range(0.0, 0.25) = 0.035;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 d = abs(local_pos);
	float e = line_width;
	float edge = clamp(step(0.5 - e, d.x) + step(0.5 - e, d.z), 0.0, 1.0);
	ALBEDO = mix(tile_color.rgb, line_color.rgb, edge);
}
