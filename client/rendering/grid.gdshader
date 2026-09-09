// Faint reference grid on the XZ play plane. Lines only, transparent
// elsewhere: the galaxy backdrop (SystemView) sits just below this plane
// and provides the ground since M1.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 line_color: source_color = vec4(0.35, 0.45, 0.65, 0.16);
uniform float cell_size = 6.0;
uniform float line_width = 0.08;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 g = abs(fract(world_pos.xz / cell_size - 0.5) - 0.5) * cell_size;
	float dist_to_line = min(g.x, g.y);
	float line = 1.0 - smoothstep(0.0, line_width, dist_to_line);
	ALBEDO = line_color.rgb;
	ALPHA = line * line_color.a;
}
