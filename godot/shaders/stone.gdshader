shader_type spatial;
render_mode cull_disabled;
uniform vec3 stone_color = vec3(0.29, 0.28, 0.245);

varying vec3 world_point;
varying vec3 world_normal;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 p = abs(world_normal.y) > 0.5 ? world_point.xz : vec2(abs(world_normal.x) > 0.5 ? world_point.z : world_point.x, world_point.y);
	float row = floor(p.y / 1.8);
	vec2 cell = vec2(p.x / 3.8 + mod(row, 2.0) * 0.5, p.y / 1.8);
	vec2 seam = abs(fract(cell) - 0.5);
	float mortar = smoothstep(0.40, 0.49, max(seam.x, seam.y));
	float grain = fract(sin(dot(floor(cell), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = mix(stone_color * (0.87 + grain * 0.23), stone_color * 0.63, mortar * 0.30);
	ROUGHNESS = 0.95;
}
