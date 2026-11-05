shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform sampler2D actions : source_color, filter_linear_mipmap;
uniform sampler2D directions : source_color, filter_linear_mipmap;
uniform sampler2D walking : source_color, filter_linear_mipmap;
uniform sampler2D melee : source_color, filter_linear_mipmap;
uniform sampler2D loading : source_color, filter_linear_mipmap;
uniform sampler2D cycle : source_color, filter_linear_mipmap;
uniform int troop_type = 0;
uniform bool smooth_motion = false;
uniform float interpolation_fraction = 1.0;
uniform float simulation_time = 0.0;
uniform float view_height_factor = 1.0;
uniform sampler2D landscape_shadows : filter_linear_mipmap, repeat_disable;
uniform vec2 map_size = vec2(1.0);
varying vec4 motion;
varying vec3 ground_light;
varying vec2 world_foot;

void vertex() {
	motion = INSTANCE_CUSTOM;
	world_foot = MODEL_MATRIX[3].xz;
	float anchor = troop_type < 2 ? 0.42 : troop_type == 6 ? 0.415 : 0.44;
	VERTEX.y = (VERTEX.y + anchor) * view_height_factor - anchor;
	ground_light = smooth_motion ? vec3(COLOR.a) : COLOR.rgb;
	if (smooth_motion) VERTEX += COLOR.rgb * (1.0 - interpolation_fraction);
	float packed = floor(motion.b + 0.01);
	float mirrored = mod(packed, 2.0);
	float direction = mod(floor(packed / 2.0), 5.0);
	float pose = floor(packed / 10.0);
	if (pose > 9.5) {
		float duration = motion.r;
		float age = mod(simulation_time - motion.a, 32.0);
		pose = age < duration ? (age < 0.38 ? 1.0 : 2.0) : 0.0;
		float progress = clamp((age - 0.38) / max(0.01, duration - 0.38), 0.0, 1.0);
		motion.b = mod(packed, 10.0) + pose * 10.0 + (pose > 0.5 ? progress * 0.5 : 0.25);
		motion.a = pose > 0.5 ? age : 0.0;
		motion.r = 0.0;
	}
	if (pose > 7.5 && pose < 9.5 && motion.a > 3.3) {
		motion.r += simulation_time * motion.a;
	} else if (smooth_motion && (pose < 0.5 || pose > 2.5)) {
		motion.r += motion.a * (1.0 - interpolation_fraction);
		motion.g += (fract(motion.b) - 0.25) * 4.0 * (1.0 - interpolation_fraction);
	}
	// The mounted general has one painting; keep its rider still and hoof motion small.
	if (troop_type == 6) {
		float legs = smoothstep(0.76, 0.94, UV.y);
		float step = sin(motion.r) * (1.0 - 2.0 * smoothstep(0.47, 0.54, UV.x));
		VERTEX.x += step * legs * motion.g * 0.018;
		VERTEX.y += max(0.0, step) * legs * motion.g * 0.01;
	}
	float recoil = smoothstep(0.0, 0.045, motion.a) * (1.0 - smoothstep(0.045, 0.48, motion.a));
	recoil *= 1.0 - smoothstep(0.1, 0.65, motion.g);
	if (troop_type >= 6 || pose < 0.5 || pose > 2.5) recoil = 0.0;
	float body = 1.0 - smoothstep(0.52, 0.84, UV.y);
	if (direction < 0.5) {
		// Recoil follows the weapon, including left-facing troops, without bending the gun carriage.
		float support = troop_type == 4 || troop_type == 5 ? 1.0 : body;
		VERTEX.x -= (1.0 - 2.0 * mirrored) * recoil * support * 0.022;
	} else {
		VERTEX.y += (direction < 1.5 ? -1.0 : 1.0) * recoil * body * 0.008;
	}
}

float legacy_direction(float direction) {
	if (troop_type >= 4) return direction;
	return direction == 2.0 ? 1.0 : direction == 4.0 ? 2.0 : 0.0;
}

vec4 cycle_frame(vec2 cell, float direction, float frame) {
	return texture(cycle, (cell + vec2(frame, direction)) / vec2(troop_type < 2 ? 8.0 : 6.0, 5.0));
}

vec4 cycle_walk(vec2 cell, float direction) {
	float gait = floor(motion.g / 2.0);
	float moving = mod(motion.g, 2.0);
	vec4 rest = cycle_frame(cell, direction, 0.0);
	if (moving < 0.08) return rest;
	float phase = motion.r / 6.28318530718;
	float frame;
	float next;
	float beat;
	if (troop_type >= 2 && gait > 1.5) {
		beat = fract(phase * 4.0);
		frame = 4.0 + mod(floor(phase * 4.0), 2.0);
		next = frame == 4.0 ? 5.0 : 4.0;
	} else {
		float step = phase * (gait > 0.5 ? 8.0 : 4.0);
		float index = mod(floor(step), 4.0);
		beat = fract(step);
		frame = index + 1.0;
		next = mod(index + 1.0, 4.0) + 1.0;
		if (troop_type >= 2) {
			frame = index == 3.0 ? 2.0 : frame;
			next = next == 4.0 ? 2.0 : next;
		}
	}
	vec4 travel = mix(cycle_frame(cell, direction, frame), cycle_frame(cell, direction, next), smoothstep(0.72, 1.0, beat));
	return mix(rest, travel, smoothstep(0.08, 0.65, moving));
}

vec4 walk_pose(vec2 cell, float direction, float columns) {
	vec2 grid = vec2(columns, 3.0);
	float travel = smoothstep(0.08, 0.7, motion.g);
	float swing = sin(motion.r);
	vec4 rest = texture(walking, (cell + vec2(0.0, direction)) / grid);
	if (travel < 0.001) return rest;
	vec4 step;
	if (troop_type == 4 || troop_type == 5 || troop_type == 7) {
		// Crews keep pushing between steps; a ready pose here would make them stand up twice per stride.
		float blend = smoothstep(-0.24, 0.24, swing);
		step = mix(texture(walking, (cell + vec2(2.0, direction)) / grid),
			texture(walking, (cell + vec2(1.0, direction)) / grid), blend);
	} else {
		// A brief planted/passing pose connects the two painted strides; no rubber-leg deformation.
		travel *= smoothstep(0.06, 0.5, abs(swing));
		step = texture(walking, (cell + vec2(swing >= 0.0 ? 1.0 : 2.0, direction)) / grid);
	}
	return mix(rest, step, travel);
}

vec4 firing_pose(vec2 cell, float direction, float pose) {
	float column = float(troop_type % 4) * 0.25;
	float progress = fract(motion.b) * 2.0;
	float ram = smoothstep(0.18, 0.34, progress) * (1.0 - smoothstep(0.52, 0.68, progress));
	if (pose > 1.5 && troop_type < 4) {
		return mix(texture(loading, (cell + vec2(0.0, direction)) / vec2(2.0, 3.0)),
			texture(loading, (cell + vec2(1.0, direction)) / vec2(2.0, 3.0)), ram);
	}
	if (troop_type == 4 || troop_type == 5) {
		if (pose > 1.5) {
			vec4 swab = texture(walking, (cell + vec2(4.0, direction)) / vec2(7.0, 3.0));
			vec4 ram = texture(walking, (cell + vec2(5.0, direction)) / vec2(7.0, 3.0));
			vec4 prime = texture(walking, (cell + vec2(6.0, direction)) / vec2(7.0, 3.0));
			return mix(mix(swab, ram, smoothstep(0.29, 0.38, progress)), prime, smoothstep(0.68, 0.77, progress));
		}
		return texture(walking, (cell + vec2(3.0, direction)) / vec2(7.0, 3.0));
	}
	if (direction > 0.5) {
		float row = direction < 1.5 ? 0.0 : 0.5;
		vec2 uv = cell * 0.25 + vec2(column, row);
		if ((troop_type == 2 || troop_type == 3) && direction < 1.5) uv.y = cell.y * 0.26;
		return texture(directions, uv);
	}
	if (troop_type == 1 && cell.x > 0.94) return vec4(0.0);
	return texture(actions, cell * vec2(0.25, 0.5) + vec2(column, pose < 1.5 ? 0.0 : 0.5));
}

void fragment() {
	float packed = floor(motion.b + 0.01);
	float mirrored = mod(packed, 2.0);
	float direction = mod(floor(packed / 2.0), 5.0);
	float pose = floor(packed / 10.0);
	float old_direction = legacy_direction(direction);
	vec2 cell = UV;
	if (mirrored > 0.5) cell.x = 1.0 - cell.x;
	vec4 painted;
	float column = float(troop_type % 4) * 0.25;
	if (pose > 4.5 && troop_type < 4) {
		float beat = fract(motion.r / 6.28318530718);
		if (pose > 7.5) {
			vec4 guard = texture(melee, (cell + vec2(0.0, old_direction)) / 3.0);
			float thrust = pose < 8.5 ? smoothstep(0.18, 0.25, beat) * (1.0 - smoothstep(0.34, 0.45, beat)) : 0.0;
			float parry = smoothstep(0.58, 0.65, beat) * (1.0 - smoothstep(0.72, 0.82, beat));
			painted = mix(guard, texture(melee, (cell + vec2(1.0, old_direction)) / 3.0), thrust);
			painted = mix(painted, texture(melee, (cell + vec2(2.0, old_direction)) / 3.0), parry);
		} else {
		float action = pose < 5.5 ? 0.0 : pose < 6.5
			? smoothstep(0.18, 0.25, beat) * (1.0 - smoothstep(0.34, 0.45, beat))
			: smoothstep(0.58, 0.65, beat) * (1.0 - smoothstep(0.72, 0.82, beat));
		painted = texture(melee, (cell + vec2(0.0, old_direction)) / 3.0);
		if (action > 0.001) painted = mix(painted, texture(melee, (cell + vec2(pose - 5.0, old_direction)) / 3.0), action);
		}
	} else if (troop_type != 6) {
		painted = troop_type < 4 ? cycle_walk(cell, direction) : walk_pose(cell, direction, troop_type == 4 || troop_type == 5 ? 7.0 : 3.0);
		if (pose > 0.5 && pose < 2.5) {
			float reload = smoothstep(0.30, 0.46, motion.a);
			vec4 work = firing_pose(cell, old_direction, 1.0);
			if (reload > 0.001) work = mix(work, firing_pose(cell, old_direction, 2.0), reload);
			if (troop_type < 2 && direction == 0.0) {
				float progress = fract(motion.b) * 2.0;
				vec4 ram = cycle_frame(cell, direction, 6.0);
				vec4 prime = cycle_frame(cell, direction, 7.0);
				vec4 ready = cycle_frame(cell, direction, 5.0);
				vec4 loading_pose = progress < 0.68 ? mix(ram, prime, smoothstep(0.48, 0.68, progress)) : mix(prime, ready, smoothstep(0.86, 1.0, progress));
				work = mix(ready, loading_pose, reload);
			}
			// Finish settling before the packed pose rolls over to idle. This also
			// keeps reduced custom-data precision from leaving a loading afterimage.
			float active = smoothstep(0.0, 0.055, motion.a) * (1.0 - smoothstep(0.78, 0.92, fract(motion.b) * 2.0));
			active *= 1.0 - smoothstep(0.1, 0.65, motion.g);
			painted = mix(painted, work, active);
		}
	} else if (direction > 0.5) {
		float row = (direction < 1.5 ? 0.0 : 0.5) + (troop_type >= 4 ? 0.25 : 0.0);
		vec2 direction_uv = cell * 0.25 + vec2(column, row);
		if ((troop_type == 2 || troop_type == 3) && direction < 1.5) direction_uv.y = cell.y * 0.26;
		if (troop_type >= 4 && direction < 1.5 && cell.y < 0.03) discard;
		painted = texture(directions, direction_uv);
	} else {
		if ((troop_type < 2 || troop_type == 3) && cell.y > 0.915) discard;
		if (troop_type == 6 && cell.x > 0.94) discard;
		painted = texture(atlas, cell * vec2(0.25, 0.5) + vec2(column, troop_type < 4 ? 0.0 : 0.5));
	}
	if (painted.a < 0.28) discard;
	vec3 color = painted.rgb / max(0.01, painted.a);
	float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
	float canopy = texture(landscape_shadows, world_foot / map_size).r;
	ALBEDO = mix(vec3(luminance), color, 0.88) * vec3(0.94, 0.96, 0.95) * ground_light * mix(1.0, canopy, 0.55);
	ALPHA = painted.a;
	ALPHA_SCISSOR_THRESHOLD = 0.28;
}
