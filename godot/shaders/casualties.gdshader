shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform sampler2D fog_map : filter_nearest, repeat_disable;
uniform bool fog_enabled = false;
uniform vec2 map_size = vec2(1440.0, 960.0);
varying vec2 map_point;
varying float enemy;
void vertex() {
	map_point = VERTEX.xz;
	enemy = COLOR.r;
}
void fragment() {
	if (fog_enabled && enemy > 0.5 && texture(fog_map, map_point / map_size).r < 0.5) discard;
	vec4 painted = texture(atlas, UV);
	if (painted.a < 0.25) discard;
	ALBEDO = painted.rgb / max(0.01, painted.a) * vec3(0.75, 0.78, 0.72);
	ALPHA = painted.a;
	ALPHA_SCISSOR_THRESHOLD = 0.25;
}
