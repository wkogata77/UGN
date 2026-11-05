shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform sampler2D ground_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 point;
varying vec4 crop;
void vertex() {
	point = VERTEX.xz;
	crop = COLOR;
}
void fragment() {
	float grain = texture(ground_texture, point / vec2(160.0, 110.0)).r;
	float furrow = 0.5 + 0.5 * sin(UV.x * 300.0 + sin(UV.y * 4.0) * 0.6);
	vec3 soil = vec3(0.29, 0.285, 0.20);
	vec3 wheat = vec3(0.36, 0.37, 0.20);
	vec3 pasture = vec3(0.25, 0.32, 0.19);
	vec3 color = crop.r < 0.3 ? soil : crop.r < 0.7 ? wheat : pasture;
	ALBEDO = color * (0.85 + grain * 0.55 + furrow * 0.09);
	ROUGHNESS = 1.0;
	vec2 boundary_uv = UV + vec2(sin(UV.y * 6.283 + crop.r * 17.0), sin(UV.x * 6.283 + crop.r * 29.0)) * 0.045;
	vec2 edge = min(boundary_uv, vec2(1.0) - boundary_uv);
	ALPHA = smoothstep(0.0, 0.08 + grain * 0.06, min(edge.x, edge.y)) * 0.64;
}
