shader_type sky;
// BUILD 34: corrected vertical orientation + vertical scale.
//
// BUILD 33 shipped v = 0.5 + dir.y * 0.5 which renders equirect panoramas
// UPSIDE DOWN (probe-verified with a labeled texture on 2026-08-24: the
// image's bottom edge appeared at the zenith). The skyboxes' moon/stars live
// in the top half of the panorama, so they mapped below the horizon and were
// invisible. flip_v = 1 is the standard equirect mapping: texture top row at
// the zenith, middle row on the horizon, bottom row at the nadir.
//
// v_zoom scales the vertical span (centered on the horizon): > 1 makes sky
// features appear bigger and pulls them down toward the reachable view. The
// night moon (panorama row ~455 = v 0.78) lands at ~25 deg elevation, inside
// the camera's sky band (pitch clamp keeps the frame top at +30 deg max).
//
// EYEDIR in Godot sky shaders points from the sky point TOWARD the camera:
// dir.y = -1 at the zenith, 0 at the horizon, +1 at the nadir.
// Godot shader UV: v = 1 is the TOP row of the texture.

uniform sampler2D sky_tex : source_color, filter_linear;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flip_v : hint_range(0.0, 1.0) = 1.0;   // 1 = standard equirect orientation
uniform float v_zoom : hint_range(0.5, 2.0) = 1.3;   // vertical scale (features bigger)

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec2 uv = vec2(atan(dir.z, dir.x) / 6.2831853 + 0.5, 0.5 + dir.y * 0.5 * v_zoom * (1.0 - 2.0 * flip_v));
	vec3 texcol = texture(sky_tex, uv).rgb;
	COLOR = texcol * tint.rgb;
}
