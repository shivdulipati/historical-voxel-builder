shader_type spatial;
// BUILD 51: AF-exact marble replication. The .model's material defs prove
// _defaultMat (marble) is mapping:0 = _Overwrite OFF = BOX UVs — exactly
// UVMapping.BoxUV from AF's Assembly-CSharp.dll (decompiled): per-face
// dominant-axis projection of the WORLD-space vertex (current transform via
// MODEL_MATRIX — glued to the mesh, so camera/stage motion can't slide it).
// No scale multiplier: AF's material scale is (1.0, 1.0) = 1 tile per unit.
// Everything else (sand) is mapping:1 = authored UVs, baked into the GLBs.

uniform sampler2D tex : source_color, filter_linear, repeat_enable;

void fragment() {
	vec3 wv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize(NORMAL);
	vec2 uv;
	if (abs(n.x) > abs(n.y) && abs(n.x) > abs(n.z)) {
		uv = vec2(wv.z * sign(n.x), wv.y);
	} else if (abs(n.y) > abs(n.z)) {
		uv = vec2(wv.x, wv.z * sign(n.y));
	} else {
		uv = vec2(wv.x * -sign(n.z), wv.y);
	}
	ALBEDO = texture(tex, uv).rgb;
	METALLIC = 0.25;
	ROUGHNESS = 0.75;
}
