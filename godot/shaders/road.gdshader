shader_type spatial;
render_mode cull_disabled, depth_draw_never;

uniform sampler2D ground_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool valeggio = false;
varying vec2 world_point;

void vertex() {
	world_point = VERTEX.xz;
}

void fragment() {
	float grain = texture(ground_texture, world_point / vec2(180.0, 120.0)).r;
	float edge = abs(UV.y - 0.5) * 2.0;
	float ruts = exp(-pow((UV.y - 0.27) * 24.0, 2.0)) + exp(-pow((UV.y - 0.73) * 24.0, 2.0));
	ALBEDO = vec3(0.34, 0.29, 0.21) * (0.82 + grain * 0.6 - ruts * 0.13);
	ROUGHNESS = 1.0;
	ALPHA = (1.0 - smoothstep(0.58 + grain * 0.15, 1.0, edge)) * 0.9;
	if (valeggio) {
		float fleck = texture(ground_texture, world_point / vec2(39.0, 26.0)).g;
		ALBEDO = vec3(0.40, 0.345, 0.255) * (0.88 + grain * 0.28 + fleck * 0.10 - ruts * 0.12);
		ALPHA = (1.0 - smoothstep(0.38 + fleck * 0.18, 0.98, edge)) * 0.94;
	}
}
