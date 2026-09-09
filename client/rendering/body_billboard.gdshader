// Camera-facing sprite for planets and suns (assets/README.md Bodies
// pipeline: bodies are billboards, and the fixed iso pitch means a spinning
// sprite reads as a sphere). Handles both real rotation sheets (frames > 1,
// played at fps) and the current single-angle stills, which are animated by
// rotating the UVs instead; suns add a counter-rotating second layer for a
// churning corona plus a slow pulse.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D sheet : source_color, filter_linear_mipmap;
uniform int frames = 1;
uniform float fps = 0.0;
uniform float spin_speed = 0.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_mix = 0.0;
uniform bool corona = false;
uniform float pulse = 0.0;
// Quad size / ball size. Above 1 the base image shrinks inside the quad
// while the corona layers keep the full quad, so the fire ring widens
// without growing the ball (which must keep matching its collision circle).
uniform float corona_spread = 1.0;

vec4 sample_frame(vec2 uv, float angle, float zoom) {
	// Rotate and zoom in frame-local space, then pick the strip frame.
	// Samples that land outside the frame are transparent, not clamped —
	// the source images carry fire right up to their edges, and clamping
	// smears that into a visible rotated square.
	vec2 centered = (uv - 0.5) * zoom;
	float s = sin(angle);
	float c = cos(angle);
	vec2 local = vec2(c * centered.x - s * centered.y, s * centered.x + c * centered.y) + 0.5;
	// 0.492, not 0.5: crops the light border some source renders bake into
	// their outermost pixels, which would show as a spinning square line.
	float in_frame = step(abs(local.x - 0.5), 0.492) * step(abs(local.y - 0.5), 0.492);
	local = clamp(local, vec2(0.0), vec2(1.0));
	if (frames > 1) {
		float frame = floor(mod(TIME * fps, float(frames)));
		local.x = (local.x + frame) / float(frames);
	}
	return texture(sheet, local) * in_frame;
}

void vertex() {
	float breathe = 1.0 + pulse * sin(TIME * 1.7);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz) * breathe,
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz) * breathe,
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec4 col = sample_frame(UV, TIME * spin_speed, corona_spread);
	if (corona) {
		vec4 back = sample_frame(UV, -TIME * spin_speed * 0.63 + 2.1, 1.0);
		vec4 front = sample_frame(UV, TIME * spin_speed * 0.41 + 4.4, 1.0);
		vec4 fire = max(back * 0.85, front * 0.65);
		if (corona_spread > 1.001) {
			// The full-quad corona copies carry their own solid ball; keep
			// only the part outside the (shrunk) base ball so they read as
			// a fire ring around it, not a second ball over it.
			float ball_edge = 0.36 / corona_spread;
			fire *= smoothstep(ball_edge * 0.55, ball_edge * 1.05, length(UV - 0.5));
		}
		// Screen blend so the fire layers brighten instead of occlude.
		col.rgb = 1.0 - (1.0 - col.rgb) * (1.0 - fire.rgb);
		col.a = max(col.a, fire.a);
	}
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = clamp(mix(col.rgb, lum * tint * 2.0, tint_mix), 0.0, 1.0);
	ALBEDO = col.rgb;
	ALPHA = col.a;
}
