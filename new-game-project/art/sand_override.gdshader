shader_type spatial;
// BUILD 36: replicate Asset Forge material overrides (e.g. custom1 = sand,
// _defaultMat = marble) on kit blocks. Triplanar sampling tiles the texture
// across every face regardless of the kit colormap UV layout (the colormap
// UVs would stretch one texture across the whole block instead).

uniform sampler2D tex : source_color, filter_linear, repeat_enable;
uniform float tile_scale : hint_range(0.25, 4.0) = 1.25;

void fragment() {
	// VERTEX/NORMAL arrive in view space; recover world-space values.
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 absn = abs(wn);
	vec3 wps = wp * tile_scale;
	vec3 col;
	if (absn.y >= absn.x && absn.y >= absn.z) {
		col = texture(tex, wps.xz).rgb;
	} else if (absn.x >= absn.z) {
		col = texture(tex, wps.zy).rgb;
	} else {
		col = texture(tex, wps.xy).rgb;
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
