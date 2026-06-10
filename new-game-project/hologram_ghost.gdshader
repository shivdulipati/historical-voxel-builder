shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

uniform vec4 albedo_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.08;
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.75;
uniform float rim_emission_strength : hint_range(0.0, 8.0) = 2.5;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

void fragment() {
	// Fresnel / rim factor: 0.0 at face-on, 1.0 at silhouette edges
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);

	ALBEDO = albedo_color.rgb;

	// Face-on areas are nearly invisible; edges are brighter
	ALPHA = clamp(base_alpha + fresnel * rim_alpha, 0.0, 1.0);

	// Emit cyan light strongest at the edges so it glows through fog/darkness
	EMISSION = albedo_color.rgb * fresnel * rim_emission_strength;
}
