shader_type sky;
// Sky for the floating earth-slice diorama: a vertical gradient that runs
// past the horizon (no flat "ground" band — the slab floats in pure sky),
// drifting fbm clouds, a sun disc + glow, and an optional moon + stars for
// the EXCAVATION (night) beat. The beat palettes are set from GDScript via
// the *_col uniforms.

uniform vec4 top_col : source_color = vec4(0.24, 0.50, 0.85, 1.0);
uniform vec4 horizon_col : source_color = vec4(0.95, 0.87, 0.72, 1.0);
uniform vec4 below_col : source_color = vec4(0.88, 0.80, 0.66, 1.0);
uniform vec4 cloud_col : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform float cloud_alpha : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_speed : hint_range(0.0, 0.2) = 0.02;

uniform vec3 sun_dir = vec3(-0.35, 0.45, -0.55);
uniform vec4 sun_col : source_color = vec4(1.0, 0.95, 0.82, 1.0);
uniform float sun_alpha : hint_range(0.0, 1.0) = 1.0;

uniform vec3 moon_dir = vec3(0.45, 0.35, 0.5);
uniform vec4 moon_col : source_color = vec4(0.85, 0.9, 1.0, 1.0);
uniform float moon_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float stars_alpha : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * vnoise(p);
		p = p * 2.03 + vec2(11.7, 5.3);
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;

	// Gradient runs continuously through the horizon (no ground band).
	vec3 skycol;
	if (h >= 0.0) {
		skycol = mix(horizon_col.rgb, top_col.rgb, pow(clamp(h, 0.0, 1.0), 0.45));
	} else {
		skycol = mix(horizon_col.rgb, below_col.rgb, pow(clamp(-h, 0.0, 1.0), 0.55));
	}

	// Sun disc + soft glow; moon (night) with a cooler, dimmer glow.
	float s = max(dot(dir, normalize(sun_dir)), 0.0);
	skycol += sun_col.rgb * (pow(s, 900.0) * 1.5 + pow(s, 6.0) * 0.28) * sun_alpha;
	float m = max(dot(dir, normalize(moon_dir)), 0.0);
	skycol += moon_col.rgb * (pow(m, 300.0) * 1.1 + pow(m, 4.0) * 0.1) * moon_alpha;

	// Two fbm layers drifting at different speeds; fade out at the horizon.
	if (h > -0.02) {
		vec2 cuv = dir.xz / max(h, 0.08);
		float n1 = fbm(cuv * 1.6 + vec2(TIME * cloud_speed * 3.0, TIME * cloud_speed * 1.7));
		float n2 = fbm(cuv * 3.1 - vec2(TIME * cloud_speed * 2.1, 0.0) + 7.3);
		float clouds = smoothstep(0.52, 0.78, n1 * 0.62 + n2 * 0.38);
		skycol = mix(skycol, cloud_col.rgb, clouds * cloud_alpha * smoothstep(-0.02, 0.06, h));
	}

	// Stars: fixed hash points on the dome, gently twinkling. Night only.
	if (h > 0.05) {
		vec2 sp = dir.xz / max(h, 0.05) * 2.0;
		vec2 g = floor(sp * 9.0);
		float st = hash21(g);
		float tw = 0.55 + 0.45 * sin(TIME * 2.0 + hash21(g + 17.0) * 40.0);
		skycol += vec3(0.85, 0.9, 1.0) * step(0.968, st) * tw * stars_alpha;
	}

	COLOR = skycol;
}
