shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(0.02, 0.08, 0.21, 1.0);
uniform vec4 color_b : source_color = vec4(0.05, 0.18, 0.38, 1.0);
uniform vec4 accent_color : source_color = vec4(0.10, 0.46, 0.78, 1.0);
uniform float t = 0.0;
uniform float drift_speed : hint_range(0.0, 2.0) = 0.26;

void fragment() {
	vec2 uv = UV;
	float drift = sin((uv.y * 1.6 + uv.x * 0.5 + t * drift_speed) * 6.28318) * 0.055;
	float mixv = clamp(uv.y + drift, 0.0, 1.0);
	vec4 base = mix(color_a, color_b, mixv);
	float bloom = smoothstep(0.65, 0.05, distance(uv, vec2(0.5, 0.28)));
	base.rgb += accent_color.rgb * bloom * 0.23;
	COLOR = vec4(base.rgb, 1.0);
}
