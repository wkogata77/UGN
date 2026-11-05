shader_type spatial;
render_mode cull_disabled;

uniform vec4 tint : source_color = vec4(0.4, 0.4, 0.3, 1.0);
uniform bool masonry = false;
uniform bool wicker = false;
uniform bool timber = false;
uniform sampler2D ground_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 point;
varying vec3 normal;

void vertex() {
	point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float grain = fract(sin(dot(floor(point * 4.0), vec3(12.98, 37.72, 78.23))) * 43758.54);
	vec2 p = abs(normal.y) > 0.5 ? point.xz : vec2(abs(normal.x) > 0.5 ? point.z : point.x, point.y);
	float detail = 0.94 + grain * 0.12;
	if (masonry) {
		float row = floor(p.y / 1.45);
		vec2 cell = vec2(p.x / 3.2 + mod(row, 2.0) * 0.5, p.y / 1.45);
		float seam = smoothstep(0.38, 0.49, max(abs(fract(cell).x - 0.5), abs(fract(cell).y - 0.5)));
		detail *= (1.0 - seam * 0.28) * (0.88 + fract(sin(dot(floor(cell), vec2(18.3, 7.1))) * 781.7) * 0.24);
	} else if (wicker) {
		detail *= 0.8 + 0.2 * smoothstep(0.08, 0.28, abs(sin(point.y * 6.0)));
	} else if (timber) {
		detail *= 0.9 + 0.1 * sin(p.x * 11.0 + sin(p.y * 0.5));
	} else {
		detail *= 0.72 + texture(ground_texture, point.xz / vec2(85.0, 65.0)).r * 0.75;
	}
	ALBEDO = tint.rgb * detail;
	ROUGHNESS = 0.96;
}
