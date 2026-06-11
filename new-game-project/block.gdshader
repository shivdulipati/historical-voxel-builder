shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float edge_thickness = 0.04;
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 dist = abs(local_pos);
	vec3 edges = step(0.5 - edge_thickness, dist);

	// An edge occurs where 2 or more axes are near the 0.5 boundary
	float edge_mask = max(max(edges.x * edges.y, edges.x * edges.z), edges.y * edges.z);

	ALBEDO = mix(albedo_color.rgb, edge_color.rgb, edge_mask);
	ALPHA = alpha;
}
