shader_type canvas_item;

uniform vec4 base_color_a : source_color = vec4(0.07, 0.10, 0.16, 1.0);
uniform vec4 base_color_b : source_color = vec4(0.20, 0.12, 0.28, 1.0);
uniform float hue_speed : hint_range(0.0, 2.0) = 0.012;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.06;
uniform float pulse_speed : hint_range(0.0, 4.0) = 0.22;
uniform float vignette : hint_range(0.0, 1.0) = 0.25;
uniform float time_sec = 0.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 uv = UV;
	float diag = clamp(uv.y * 0.82 + uv.x * 0.35, 0.0, 1.0);
	vec3 base = mix(base_color_a.rgb, base_color_b.rgb, diag);

	float hue_shift = sin(time_sec * hue_speed * 6.28318) * 0.08;
	vec3 hsv = rgb_to_hsv(base);
	hsv.x = fract(hsv.x + hue_shift);

	float radial = 1.0 - clamp(distance(uv, vec2(0.5, 0.5)) * 1.35, 0.0, 1.0);
	float pulse = 1.0 + pulse_intensity * radial * sin(time_sec * pulse_speed * 6.28318);
	vec3 final_col = hsv_to_rgb(hsv) * pulse;

	float edge = smoothstep(1.0, 0.22, length((uv - 0.5) * vec2(1.0, 1.1)));
	final_col *= mix(1.0 - vignette, 1.0, edge);

	COLOR = vec4(final_col, 1.0);
}
