// Per-system space backdrop: a crop of the galaxy master image for the
// large-scale nebula color, plus two procedural star layers for the
// high-frequency detail the master cannot provide (a 7200px image spread
// over a system would be ~13x magnified at gameplay zoom). Stars hash from
// world position, so they are static in space and read as motion parallax
// reference while flying.
shader_type spatial;
render_mode unshaded;

uniform sampler2D master : source_color, filter_linear_mipmap;
uniform vec2 uv_offset = vec2(0.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec3 darken : source_color = vec3(0.55, 0.55, 0.6);
// Per-system offset so different systems show different star patterns.
uniform vec2 star_seed = vec2(0.0);

varying vec2 world_xz;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
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
	return smoothstep(radius, radius * 0.3, dist) * (0.4 + h.y * 0.6);
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 nebula = texture(master, UV * uv_scale + uv_offset).rgb * darken;
	float stars = star_layer(world_xz, 4.0, 0.16, 0.30)
		+ star_layer(world_xz + vec2(53.7, 17.3), 9.0, 0.30, 0.45) * 0.8;
	ALBEDO = nebula + vec3(0.85, 0.9, 1.0) * min(stars, 1.0);
}
