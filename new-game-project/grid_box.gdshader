shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, unshaded;

uniform vec4 grid_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float line_thickness = 0.04;
uniform float floor_opacity = 0.2;
uniform float box_height = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// Mathematically isolate the bottom face of the box
	float bottom_y = -(box_height / 2.0);
	float is_bottom = 0.0;
	if (local_pos.y < bottom_y + 0.05) {
		is_bottom = 1.0;
	}

	// 2D grid strictly on the XZ floor plane
	vec2 grid = abs(fract(local_pos.xz + 0.5) - 0.5);
	vec2 lines = step(grid, vec2(line_thickness));
	float grid_mask = max(lines.x, lines.y);

	ALBEDO = grid_color.rgb;
	// The walls disappear because is_bottom is 0.0 everywhere except the floor
	ALPHA = max(grid_mask, floor_opacity) * grid_color.a * is_bottom;
}
