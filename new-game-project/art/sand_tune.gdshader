shader_type spatial;
// BUILD 50: EXACT replication of Asset Forge's UVMapping.BoxUV — decompiled
// from Assembly-CSharp.dll (GetBoxDir + GetBoxUV). Per-face dominant-axis
// projection of the WORLD-space vertex (block origin + local vertex), no
// scale multiplier (1 tile per unit is AF's true default), _Overwrite
// materials excluded (kit defaults) — overrides (sand) get box UVs.
// The [ ] / - = knobs still let the user fine-tune; AF's defaults are
// scale = 1.0, rot = 0.

uniform sampler2D tex : source_color, filter_linear, repeat_enable;
uniform vec3 origin = vec3(0.0);  // the block's world position (per instance)
uniform float scale = 1.0;
uniform float rot = 0.0;

void fragment() {
	vec3 wv = origin + VERTEX;
	vec3 n = NORMAL;
	vec2 uv;
	if (abs(n.x) > abs(n.y) && abs(n.x) > abs(n.z)) {
		uv = vec2(wv.z * sign(n.x), wv.y);
	} else if (abs(n.y) > abs(n.z)) {
		uv = vec2(wv.x, wv.z * sign(n.y));
	} else {
		uv = vec2(wv.x * -sign(n.z), wv.y);
	}
	uv *= scale;
	float r = radians(rot);
	float c = cos(r);
	float s = sin(r);
	uv = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
	ALBEDO = texture(tex, uv).rgb;
	METALLIC = 0.25;
	ROUGHNESS = 0.75;
}
