shader_type spatial;
// Face-selected material for the earth-slice slab: the top face samples the
// sand texture, the four sides sample the strata strip (world-space UV so the
// bands stay glued to absolute height), the bottom face is bedrock color.
// One material for the whole box — no per-face mesh juggling.

uniform sampler2D strata_tex : source_color, filter_linear, repeat_enable;
uniform sampler2D top_tex : source_color, filter_linear, repeat_enable;
uniform vec4 bedrock_color : source_color = vec4(0.36, 0.31, 0.27, 1.0);
uniform float depth : hint_range(1.0, 32.0) = 8.0;
uniform float tile : hint_range(0.25, 4.0) = 1.0;

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 albedo;
	if (wn.y > 0.5) {
		albedo = texture(top_tex, wp.xz / tile).rgb;
	} else if (wn.y < -0.5) {
		albedo = bedrock_color.rgb;
	} else {
		// Side faces: horizontal repeat of the strip; V maps absolute depth
		// (0 at the surface -> 1 at the bottom) so bands align across faces.
		vec2 uv;
		if (abs(wn.x) > abs(wn.z)) {
			uv = vec2(wp.z, -wp.y) / vec2(tile, depth);
		} else {
			uv = vec2(wp.x, -wp.y) / vec2(tile, depth);
		}
		albedo = texture(strata_tex, uv).rgb;
	}
	ALBEDO = albedo;
}
