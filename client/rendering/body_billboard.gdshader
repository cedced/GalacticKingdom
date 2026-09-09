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

vec2 rotate_uv(vec2 uv, float angle) {
	vec2 centered = uv - 0.5;
	float s = sin(angle);
	float c = cos(angle);
	return vec2(c * centered.x - s * centered.y, s * centered.x + c * centered.y) + 0.5;
}

vec4 sample_frame(vec2 uv, float angle) {
	// Rotate in frame-local space, then pick the strip frame. The sprites
	// keep a transparent margin, so clamped out-of-disc samples stay empty.
	vec2 local = clamp(rotate_uv(uv, angle), vec2(0.0), vec2(1.0));
	if (frames > 1) {
		float frame = floor(mod(TIME * fps, float(frames)));
		local.x = (local.x + frame) / float(frames);
	}
	return texture(sheet, local);
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
	vec4 col = sample_frame(UV, TIME * spin_speed);
	if (corona) {
		vec4 back = sample_frame(UV, -TIME * spin_speed * 0.63 + 2.1);
		// Screen blend so the two fire layers brighten instead of occlude.
		col.rgb = 1.0 - (1.0 - col.rgb) * (1.0 - back.rgb * 0.85);
		col.a = max(col.a, back.a * 0.85);
	}
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = clamp(mix(col.rgb, lum * tint * 2.0, tint_mix), 0.0, 1.0);
	ALBEDO = col.rgb;
	ALPHA = col.a;
}
