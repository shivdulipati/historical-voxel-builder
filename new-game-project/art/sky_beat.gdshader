shader_type sky;
// BUILD 29: the sky base is now the Kenney new-platformer-pack background
// clouds texture (2D side-scroller art, mapped equirectangular onto the
// dome). It is sampled from the view ray direction, so it stays fixed in
// world space — the diorama rotates beneath it, the sky does not move.
// Per-beat mood comes from a multiplicative TINT (dawn warm / noon white /
// dusk orange / night deep blue) + the sun/moon/star overlays. The band
// below the horizon fades to below_col so clouds never hang under the
// island.

uniform sampler2D sky_tex : source_color, filter_linear, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 below_col : source_color = vec4(0.55, 0.5, 0.41, 1.0);

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

void sky() {
	// EYEDIR points from the sky point TOWARD the camera (the reverse of the
	// view ray) — negate so h > 0 means above the horizon.
	vec3 dir = normalize(EYEDIR);
	float h = -dir.y;

	// Equirectangular sample from the view direction: u wraps around (the
	// texture tiles horizontally by design). EYEDIR points from the sky point
	// TOWARD the camera, so dir.y = -1 at the zenith, 0 at the horizon. The
	// texture's white cloud band sits at its BOTTOM rows: v = 1 + dir.y puts
	// the clouds on the horizon band and the clear blue over the dome.
	vec2 uv = vec2(atan(dir.z, dir.x) / 6.2831853 + 0.5, clamp(1.0 + dir.y, 0.0, 1.0));
	vec3 texcol = texture(sky_tex, uv).rgb;

	vec3 skycol = texcol * tint.rgb;

	// Sun / moon discs with a tight glow (no broad radial wash).
	float s = max(dot(dir, normalize(sun_dir)), 0.0);
	skycol += sun_col.rgb * (pow(s, 900.0) * 1.5 + pow(s, 30.0) * 0.25) * sun_alpha;
	float m = max(dot(dir, normalize(moon_dir)), 0.0);
	skycol += moon_col.rgb * (pow(m, 300.0) * 1.1 + pow(m, 20.0) * 0.15) * moon_alpha;

	// Static stars (night only), well above the horizon so they never stretch.
	if (h > 0.15) {
		vec2 sp = dir.xz / max(h, 0.2) * 2.0;
		vec2 g = floor(sp * 9.0);
		float st = hash21(g);
		skycol += vec3(0.85, 0.9, 1.0) * step(0.968, st) * stars_alpha;
	}

	COLOR = skycol;
}
