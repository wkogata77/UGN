shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
varying vec2 cell;
varying float opacity;
varying float dust;

void vertex() {
	float index = floor(INSTANCE_CUSTOM.r + 0.01);
	cell = vec2(mod(index, 3.0), floor(index / 3.0));
	opacity = INSTANCE_CUSTOM.g;
	dust = INSTANCE_CUSTOM.b;
}

void fragment() {
	vec4 painted = texture(atlas, (UV + cell) / vec2(3.0, 2.0));
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.88, 1.0, UV.x)) * (1.0 - smoothstep(0.88, 1.0, UV.y));
	ALBEDO = painted.rgb * mix(vec3(0.91, 0.94, 0.96), vec3(0.59, 0.49, 0.34), dust);
	ALPHA = painted.a * opacity * edge;
}
