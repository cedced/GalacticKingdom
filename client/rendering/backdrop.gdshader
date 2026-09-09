// Fully procedural per-system space backdrop: near-black space, three
// star layers, and a faint value-noise nebula haze. Everything hashes
// from world position plus a per-system seed, so each system looks
// distinct, stays deterministic, and the stars double as motion
// reference while flying. Replaced the photo-crop approach: no crop of
// a fixed-resolution master survives gameplay zoom without pixelation,
// and generated space can be as black as space should be.
shader_type spatial;
render_mode unshaded;

uniform vec3 base_color : source_color = vec3(0.006, 0.007, 0.012);
uniform vec3 nebula_color : source_color = vec3(0.10, 0.14, 0.25);
uniform float nebula_intensity : hint_range(0.0, 1.0) = 0.10;
// Per-system offset so no two systems share a sky.
uniform vec2 star_seed = vec2(0.0);

varying vec2 world_xz;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = p - cell;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash22(cell).x;
	float b = hash22(cell + vec2(1.0, 0.0)).x;
	float c = hash22(cell + vec2(0.0, 1.0)).x;
	float d = hash22(cell + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float total = value_noise(p) * 0.5;
	total += value_noise(p * 2.03 + 11.7) * 0.25;
	total += value_noise(p * 4.11 + 37.2) * 0.125;
	return total;
}

// One star at most per grid cell, kept away from cell borders so it never
// pops across cells; density is the fraction of cells that get one.
float star_layer(vec2 p, float cell_size, float radius, float density) {
	vec2 cell = floor(p / cell_size);
	vec2 h = hash22(cell + star_seed);
	if (h.x > density) {
		return 0.0;
	}
	vec2 star_pos = (cell + vec2(0.35) + h * 0.3) * cell_size;
	float dist = distance(p, star_pos);
	return smoothstep(radius, radius * 0.25, dist) * (0.3 + h.y * 0.7);
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// pow keeps the haze to sparse wisps instead of an even wash.
	float haze = pow(fbm(world_xz * 0.02 + star_seed), 3.0);
	vec3 col = base_color + nebula_color * haze * nebula_intensity;
	float faint = star_layer(world_xz + vec2(19.1, 71.3), 2.6, 0.08, 0.35);
	float mid = star_layer(world_xz, 5.5, 0.14, 0.30);
	float bright = star_layer(world_xz + vec2(53.7, 17.3), 12.0, 0.28, 0.45);
	col += vec3(0.75, 0.82, 0.95) * faint * 0.35;
	col += vec3(0.85, 0.90, 1.00) * mid * 0.75;
	col += vec3(1.00, 0.96, 0.88) * min(bright, 1.0);
	ALBEDO = col;
}
