shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, unshaded;

uniform vec4 grid_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float line_thickness = 0.03;
uniform float floor_opacity = 0.2;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// Erase the walls and ceiling entirely. Only the bottom face renders.
	if (local_pos.y > -0.49) {
		discard;
	}

	// Calculate the 2D grid strictly on the XZ floor plane
	vec2 grid = abs(fract(local_pos.xz + 0.5) - 0.5);
	vec2 lines = step(grid, vec2(line_thickness));
	float grid_mask = max(lines.x, lines.y);

	ALBEDO = grid_color.rgb;
	ALPHA = max(grid_mask, floor_opacity) * grid_color.a;
}
