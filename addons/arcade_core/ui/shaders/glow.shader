shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.42, 0.86, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float falloff : hint_range(0.5, 4.0) = 2.1;
uniform float edge_mix : hint_range(0.0, 1.0) = 0.75;
uniform float time_scale : hint_range(0.0, 4.0) = 0.35;
uniform float pulse_amount : hint_range(0.0, 0.6) = 0.14;
uniform float t = 0.0;

void fragment() {
	vec2 uv = UV * 2.0 - vec2(1.0);
	float dist = length(uv);
	float ring = pow(max(0.0, 1.0 - dist), falloff);
	float edge = smoothstep(0.95, 0.1, abs(max(abs(uv.x), abs(uv.y))));
	float pulse = 1.0 + sin(t * time_scale * 6.28318) * pulse_amount;
	float alpha = (ring * (1.0 - edge_mix) + edge * edge_mix) * intensity * pulse;
	COLOR = vec4(glow_color.rgb, glow_color.a * alpha);
}
