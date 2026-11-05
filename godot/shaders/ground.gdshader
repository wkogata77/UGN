shader_type spatial;
render_mode cull_disabled;

uniform sampler2D ground_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool campaign = true;
uniform bool river = true;
uniform bool valeggio = false;
uniform bool landscape_style = false;
uniform sampler2D cultivated_map : filter_linear, repeat_disable;
uniform sampler2D settlement_map : filter_linear, repeat_disable;
uniform sampler2D landscape_shadows : filter_linear_mipmap, repeat_disable;
uniform sampler2D meadow_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D land_materials : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool fog_enabled = false;
uniform sampler2D fog_map : filter_linear, repeat_disable;
uniform sampler2D woodland_map : filter_linear, repeat_disable;
uniform vec2 landscape_origin = vec2(-1400.0);
uniform vec2 landscape_size = vec2(4240.0, 3760.0);
uniform float campaign_scale = 1.0;
uniform vec2 map_size = vec2(1440.0, 960.0);
uniform vec2 battle_offset = vec2(0.0);
uniform bool river_vertical = false;
uniform vec2 river_points[9];
varying vec2 world_point;
varying float altitude;
varying float slope;
varying vec3 land_normal;

void vertex() {
	world_point = VERTEX.xz;
	altitude = VERTEX.y;
	slope = 1.0 - NORMAL.y;
	land_normal = NORMAL;
}

vec3 painted_material(vec2 point, float scale, vec2 tile) {
	vec2 mirrored = 1.0 - abs(mod(point / scale, 2.0) - 1.0);
	return texture(land_materials, tile * 0.5 + vec2(0.008) + mirrored * 0.484).rgb;
}

void fragment() {
	vec2 tiled = world_point / vec2(1440.0, 960.0);
	vec2 uv = 1.0 - abs(mod(tiled, 2.0) - 1.0);
	vec3 ground = texture(ground_texture, uv, 0.5).rgb;
	ground = mix(ground, vec3(0.31, 0.33, 0.27), 0.18);
	vec2 strategic = world_point / campaign_scale;
	vec2 tactical = world_point - battle_offset;
	float bank = campaign ? abs(strategic.y - (455.0 + sin(strategic.x / 175.0) * 46.0 + strategic.x * 0.045)) : abs(tactical.x - (720.0 + sin((tactical.y - 480.0) / 190.0) * 35.0));
	if (river_vertical) {
		float channel = river_points[8].x;
		for (int i = 1; i < 9; i++) {
			if (world_point.y <= river_points[i].y) {
				float t = clamp((world_point.y - river_points[i - 1].y) / (river_points[i].y - river_points[i - 1].y), 0.0, 1.0);
				channel = mix(river_points[i - 1].x, river_points[i].x, t);
				break;
			}
		}
		bank = abs(world_point.x - channel) / campaign_scale;
	}
	if (river) {
		float edge = campaign ? 24.0 : 39.0;
		float rough_bank = texture(ground_texture, world_point / vec2(280.0, 185.0)).r * 3.0;
		ground = mix(vec3(0.33, 0.32, 0.25), ground, smoothstep(edge - 4.0 + rough_bank, edge + 5.0, bank));
	}
	float luminance = dot(ground, vec3(0.2126, 0.7152, 0.0722));
	ground = mix(vec3(luminance), ground, 0.87) * vec3(0.95, 1.05, 1.03);
	float detail = dot(texture(ground_texture, world_point / vec2(240.0, 160.0)).rgb, vec3(0.2126, 0.7152, 0.0722));
	ground *= 0.91 + detail * 0.35;
	ground = mix(ground, ground * vec3(1.14, 1.06, 0.95), smoothstep(25.0, 140.0, altitude) * 0.4);
	ground = mix(ground, vec3(luminance * 0.85, luminance * 0.9, luminance * 0.88), smoothstep(0.09, 0.36, slope) * 0.35);
	ground *= vec3(0.60, 0.66, 0.63);
	float woodland = texture(woodland_map, (world_point - landscape_origin) / landscape_size).r;
	ground *= mix(vec3(1.0), vec3(0.87, 0.91, 0.84), woodland);
	if (landscape_style) {
		// Fine painted grain stays subordinate to the authored land-use pattern.
		vec3 meadow = texture(meadow_texture, world_point / 290.0).rgb;
		meadow = mix(vec3(dot(meadow, vec3(0.25, 0.6, 0.15))), meadow, 0.72);
		float fine = dot(meadow, vec3(0.25, 0.6, 0.15));
		float broad = texture(ground_texture, world_point / vec2(1100.0, 733.0)).g;
		ground = mix(vec3(0.19, 0.225, 0.135), vec3(0.29, 0.30, 0.18), broad);
		ground = mix(ground, meadow * vec3(0.74, 0.80, 0.69), 0.24);
		vec3 grass_paint = painted_material(world_point, 160.0, vec2(0.0));
		ground *= 0.85 + dot(grass_paint, vec3(0.25, 0.6, 0.15)) * 0.4;
		vec4 land = texture(cultivated_map, world_point / map_size);
		float inside = step(0.0, world_point.x) * step(0.0, world_point.y) * step(world_point.x, map_size.x) * step(world_point.y, map_size.y);
		float perimeter = min(min(world_point.x, world_point.y), min(map_size.x - world_point.x, map_size.y - world_point.y));
		land *= smoothstep(0.0, 90.0, perimeter);
		land *= inside * (1.0 - woodland) * (river ? smoothstep(campaign ? 29.0 : 52.0, campaign ? 42.0 : 73.0, bank) : 1.0);
		float row_spacing = 2.6;
		float row_phase = world_point.x / row_spacing + world_point.y * 0.025;
		float rows = sin(row_phase * 6.283) * (1.0 - smoothstep(0.3, 0.9, fwidth(row_phase)));
		vec3 soil_paint = painted_material(world_point, 100.0, vec2(1.0, 0.0));
		vec3 straw_paint = painted_material(world_point, 120.0, vec2(0.0, 1.0));
		ground = mix(ground, vec3(0.245, 0.215, 0.145) * (0.91 + fine * 0.36 + rows * 0.027) * (0.60 + soil_paint * 0.9), land.r * 0.90);
		ground = mix(ground, vec3(0.37, 0.335, 0.18) * (0.91 + fine * 0.34 + rows * 0.018) * (0.65 + straw_paint * 0.6), land.g * 0.88);
		ground = mix(ground, vec3(0.20, 0.25, 0.145) * (0.93 + fine * 0.3), land.b * 0.88);
		float yard = texture(settlement_map, world_point / map_size).r * inside;
		ground = mix(ground, vec3(0.33, 0.29, 0.205) * (0.91 + fine * 0.36), yard * 0.78);
		float wet = (1.0 - smoothstep(46.0, 83.0, bank + (fine - 0.5) * 14.0));
		ground = mix(ground, vec3(0.17, 0.205, 0.135) * (0.9 + fine * 0.3), wet * (river ? 0.68 : 0.0));
		ground *= mix(vec3(1.0), vec3(0.69, 0.75, 0.65), woodland * (0.85 + fine * 0.15));
		ground *= mix(vec3(1.0), vec3(1.04, 1.015, 0.95), smoothstep(15.0, 65.0, altitude));
		// Stony shoulders follow the real slope; broad hill light remains legible
		// at command zoom while fine texture stays quiet.
		float stone = smoothstep(0.018, 0.10, slope) * smoothstep(18.0, 70.0, altitude);
		float stone_grain = texture(ground_texture, world_point / vec2(105.0, 72.0)).r;
		float aspect = dot(land_normal.xz, normalize(vec2(0.75, 1.0))) / max(0.001, length(land_normal.xz));
		stone *= smoothstep(-0.10, 0.55, aspect) * smoothstep(0.13, 0.52, stone_grain);
		vec3 rock_paint = painted_material(world_point, 72.0, vec2(1.0));
		ground = mix(ground, vec3(0.40, 0.39, 0.34) * (0.86 + stone_grain * 0.28) * (0.55 + rock_paint * 0.8), stone * 0.86);
		float shoulder_light = clamp(dot(normalize(land_normal), normalize(vec3(-0.60, 0.64, -0.35))), 0.0, 1.0);
		ground *= 0.72 + shoulder_light * 0.49;
		ground *= mix(vec3(1.0), texture(landscape_shadows, world_point / map_size).rgb, inside * 0.86);
	}
	if (fog_enabled) {
		float visibility = texture(fog_map, world_point / map_size).r;
		ground = mix(ground * vec3(0.70, 0.79, 0.83), ground, smoothstep(0.0, 1.0, visibility));
	}
	ALBEDO = ground;
	ROUGHNESS = 1.0;
}
