shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha, skip_vertex_transform;

uniform sampler2D painting : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 camera_right = vec3(1.0, 0.0, 0.0);
uniform vec3 camera_up = vec3(0.0, 0.819152, -0.573576);
uniform float cutoff = 0.18;

void vertex() {
	// Build the camera-facing painting around its true root, including during
	// camera tilt. Both the color pass and the light's shadow pass use this root.
	vec3 root = (MODEL_MATRIX * vec4(0.0, -0.5, 0.0, 1.0)).xyz;
	float width = length(MODEL_MATRIX[0].xyz) * sign(MODEL_MATRIX[0].x);
	float height = length(MODEL_MATRIX[1].xyz);
	vec3 point = root + camera_right * VERTEX.x * width + camera_up * (VERTEX.y + 0.5) * height;
	VERTEX = (VIEW_MATRIX * vec4(point, 1.0)).xyz;
}

void fragment() {
	vec4 painted = texture(painting, UV);
	ALBEDO = painted.rgb * tint.rgb * COLOR.rgb;
	ALPHA = painted.a;
	ALPHA_SCISSOR_THRESHOLD = cutoff;
}
