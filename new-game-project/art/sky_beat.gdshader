shader_type sky;
// Static beat sky for the floating earth-slice diorama. The pattern is
// sampled from the view ray direction, so it is fixed in world space — the
// diorama rotates beneath it; only the camera's look direction reveals
// different parts of the sky, exactly like a real sky. No time animation
// (clouds do not drift, stars do not twinkle), and the cloud mapping clamps
// the horizon division so the noise never stretches into warping streaks
// (the BUILD 23 sky-streak bug). The beat palettes are set from GDScript.

uniform vec4 top_col : source_color = vec4(0.24, 0.50, 0.85, 1.0);
uniform vec4 horizon_col : source_color = vec4(0.95, 0.87, 0.72, 1.0);
uniform vec4 below_col : source_color = vec4(0.88, 0.80, 0.66, 1.0);
uniform vec4 cloud_col : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform float cloud_alpha : hint_range(0.0, 1.0) = 0.45;

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

	// Sun / moon discs with a tight glow (no broad radial wash).
	float s = max(dot(dir, normalize(sun_dir)), 0.0);
	skycol += sun_col.rgb * (pow(s, 900.0) * 1.5 + pow(s, 30.0) * 0.25) * sun_alpha;
	float m = max(dot(dir, normalize(moon_dir)), 0.0);
	skycol += moon_col.rgb * (pow(m, 300.0) * 1.1 + pow(m, 20.0) * 0.15) * moon_alpha;

	// Static cloud band above the horizon. The UV division is clamped so the
	// noise cannot stretch into streaks, and the band fades to zero well
	// before the clamp region — nothing warps as the camera turns.
	float band = smoothstep(0.04, 0.10, h) * (1.0 - smoothstep(0.42, 0.62, h));
	if (band > 0.001) {
		vec2 cuv = dir.xz / max(h, 0.28);
		float n1 = fbm(cuv * 1.6 + vec2(13.7, 7.3));
		float n2 = fbm(cuv * 3.1 - vec2(5.1, 11.9));
		float clouds = smoothstep(0.52, 0.78, n1 * 0.62 + n2 * 0.38);
		skycol = mix(skycol, cloud_col.rgb, clouds * cloud_alpha * band);
	}

	// Static stars (night only), well above the horizon so they never stretch.
	if (h > 0.15) {
		vec2 sp = dir.xz / max(h, 0.2) * 2.0;
		vec2 g = floor(sp * 9.0);
		float st = hash21(g);
		skycol += vec3(0.85, 0.9, 1.0) * step(0.968, st) * stars_alpha;
	}

	COLOR = skycol;
}
