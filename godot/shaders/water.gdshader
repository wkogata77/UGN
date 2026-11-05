shader_type spatial;
render_mode cull_disabled;

uniform float simulation_time = 0.0;
uniform bool campaign = false;
uniform bool valeggio = false;
uniform sampler2D surface_texture : filter_linear_mipmap, repeat_enable;
varying vec2 world_point;
void vertex() {
	world_point = VERTEX.xz;
}
void fragment() {
	vec3 smooth_normal = NORMAL;
	float along = campaign ? world_point.x : world_point.y;
	float across = campaign ? world_point.y : world_point.x;
	float drift = simulation_time * 1.8;
	float wave = sin(along * 0.13 - drift + sin(across * 0.06) * 2.0);
	float ripple = sin(along * 0.52 - drift * 1.5 + across * 0.08);
	float bank = abs(UV.y - 0.5) * 2.0;
	float shallows = smoothstep(0.45, 1.0, bank);
	ALBEDO = mix(vec3(0.19, 0.28, 0.33), vec3(0.28, 0.32, 0.30), shallows);
	ALBEDO += (wave * 0.012 + ripple * 0.004) * (1.0 - shallows);
	ROUGHNESS = 0.32;
	SPECULAR = 0.55;
	NORMAL = normalize(NORMAL + TANGENT * wave * 0.025 + BINORMAL * ripple * 0.012);
	if (valeggio) {
		float current = texture(surface_texture, world_point / vec2(70.0, 105.0) + vec2(0.0, -simulation_time * 0.005)).g;
		float eddy = texture(surface_texture, world_point.yx / vec2(48.0, 81.0) + vec2(-simulation_time * 0.003, 0.0)).r;
		ALBEDO = mix(vec3(0.105, 0.20, 0.245), vec3(0.215, 0.28, 0.235), shallows);
		ALBEDO += (current - 0.4) * 0.15 + (eddy - 0.4) * 0.065;
		ROUGHNESS = 0.68;
		SPECULAR = 0.22;
		NORMAL = smooth_normal;
	}
}
