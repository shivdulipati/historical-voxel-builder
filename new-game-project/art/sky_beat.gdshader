shader_type sky;
// BUILD 33: the sky is a Kenney equirectangular skybox panorama (4096x2048,
// world-fixed — rotating the diorama never moves the sky). The panorama
// carries its own sun/moon/stars; the beat system swaps the texture
// (morning / day / night) and applies a subtle per-beat tint.
//
// EYEDIR points from the sky point TOWARD the camera: dir.y = -1 at the
// zenith, 0 at the horizon, +1 at the nadir. The standard equirectangular
// mapping v = 0.5 + dir.y * 0.5 puts the panorama's top row at the zenith,
// its middle row on the horizon, and its bottom row at the nadir — so the
// skybox's own below-horizon haze fills the underside of the dome.

uniform sampler2D sky_tex : source_color, filter_linear;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec2 uv = vec2(atan(dir.z, dir.x) / 6.2831853 + 0.5, 0.5 + dir.y * 0.5);
	vec3 texcol = texture(sky_tex, uv).rgb;
	COLOR = texcol * tint.rgb;
}
