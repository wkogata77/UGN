shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform bool smooth_motion = false;
uniform float interpolation_fraction = 1.0;

void vertex() {
	if (smooth_motion) VERTEX += COLOR.rgb * (1.0 - interpolation_fraction);
}

void fragment() {
	float radius = length((UV - 0.5) * 2.0);
	ALBEDO = vec3(0.07, 0.10, 0.07);
	ALPHA = (1.0 - smoothstep(0.15, 1.0, radius)) * 0.32;
}
