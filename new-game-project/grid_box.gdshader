shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 line_color : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform vec4 glass_color : source_color = vec4(0.2, 0.8, 1.0, 0.1);
uniform float line_thickness : hint_range(0.0, 0.5) = 0.05;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Shift X and Z by 0.5 to align lines with the block edges, keep Y as is
	vec3 shifted_pos = vec3(world_pos.x + 0.5, world_pos.y, world_pos.z + 0.5);

	vec3 f = fract(shifted_pos);
	vec3 df = min(f, 1.0 - f);

	bool on_x = df.x < line_thickness;
	bool on_y = df.y < line_thickness;
	bool on_z = df.z < line_thickness;

	// A 3D line only exists where at least two planes intersect
	bool is_line = (on_x && on_y) || (on_x && on_z) || (on_y && on_z);

	if (is_line) {
		ALBEDO = line_color.rgb;
		ALPHA = line_color.a;
	} else {
		// Draw the faint glass face instead of discarding
		ALBEDO = glass_color.rgb;
		ALPHA = glass_color.a;
	}
}
