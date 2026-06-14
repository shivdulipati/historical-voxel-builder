shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, unshaded;

uniform vec4 grid_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float line_thickness = 0.04;
uniform float floor_opacity = 0.2;
uniform vec2 grid_dimensions = vec2(5.0, 5.0);

varying vec2 UV_coords;

void vertex() {
	// For a PlaneMesh, VERTEX.xz gives us perfect local coordinates from center
	UV_coords = VERTEX.xz;
}

void fragment() {
	// Center-aligned grid lines matching world units
	vec2 grid = abs(fract(UV_coords) - 0.5);
	vec2 lines = step(grid, vec2(line_thickness));
	float grid_mask = max(lines.x, lines.y);

	ALBEDO = grid_color.rgb;
	ALPHA = max(grid_mask, floor_opacity) * grid_color.a;
}
