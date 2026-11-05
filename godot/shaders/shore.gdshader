shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform sampler2D ground_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool valeggio = false;
varying vec2 point;
void vertex() { point = VERTEX.xz; }
void fragment() {
	float grain = texture(ground_texture, point / vec2(90.0, 65.0)).r;
	ALBEDO = mix(vec3(0.19, 0.19, 0.135), vec3(0.32, 0.275, 0.18), smoothstep(0.0, 0.6, UV.y)) * (0.8 + grain * 0.55);
	ROUGHNESS = 0.96;
	ALPHA = (1.0 - smoothstep(0.35 + grain * 0.15, 1.0, UV.y)) * 0.88;
	if (valeggio) {
		float gravel = texture(ground_texture, point / vec2(24.0, 17.0)).r;
		ALBEDO = mix(vec3(0.16, 0.195, 0.18), vec3(0.33, 0.315, 0.25), smoothstep(0.0, 0.45, UV.y)) * (0.86 + grain * 0.3 + gravel * 0.14);
		ALPHA = (1.0 - smoothstep(0.20 + grain * 0.3, 0.92, UV.y)) * 0.94;
	}
}
