shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Ghost cell shader: translucent fill with a crisp dark outline band.
// Edges are detected in LOCAL SPACE (abs(VERTEX) near the unit-box surface),
// NOT from UVs — a BoxMesh shares UV strips between faces, so UV-based bands
// only ever land on the faces touching the UV border (some edges get no
// outline, others read double-thick). An edge here means TWO local axes are
// near the box surface at once (face interior has only one).

uniform vec4 fill_color : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(0.08, 0.06, 0.04, 1.0);
uniform float edge_width : hint_range(0.0, 0.25) = 0.025;
uniform float alpha : hint_range(0.0, 1.0) = 0.45;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 d = abs(local_pos);
	float e = edge_width;
	float ex = step(0.5 - e, d.x);
	float ey = step(0.5 - e, d.y);
	float ez = step(0.5 - e, d.z);
	// Edge only where at least TWO axes touch the surface (cube corners/edges).
	float band = clamp(ex * (ey + ez) + ey * ez, 0.0, 1.0);
	ALBEDO = mix(fill_color.rgb, edge_color.rgb, band);
	ALPHA = mix(alpha, 0.92, band);
}
