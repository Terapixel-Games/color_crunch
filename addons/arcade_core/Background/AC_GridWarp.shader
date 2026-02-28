shader_type canvas_item;

uniform vec4 grid_color : source_color = vec4(0.35, 0.82, 1.0, 1.0);
uniform float grid_opacity : hint_range(0.0, 1.0) = 0.14;
uniform float warp_amount : hint_range(0.0, 1.5) = 0.08;
uniform float warp_speed : hint_range(0.0, 6.0) = 0.45;
uniform float line_thickness : hint_range(0.001, 0.45) = 0.045;
uniform float spacing : hint_range(8.0, 256.0) = 54.0;
uniform float reactive_boost : hint_range(0.0, 1.0) = 0.0;
uniform float time_sec = 0.0;

float grid_line(float coord, float width) {
	float d = abs(fract(coord) - 0.5);
	return smoothstep(0.5, 0.5 - width, d);
}

void fragment() {
	vec2 uv = UV;
	float horizon = clamp((uv.y - 0.08) / 0.92, 0.0, 1.0);
	float perspective = mix(0.25, 1.0, horizon * horizon);

	float wave = sin((uv.x * 2.8 + uv.y * 3.5 + time_sec * warp_speed) * 3.14159);
	float warp = (warp_amount + reactive_boost * 0.22) * wave * (0.15 + horizon * 0.85);

	vec2 coord = vec2((uv.x + warp) * spacing * perspective, uv.y * spacing * 0.65);
	float thickness = line_thickness * mix(1.3, 0.6, horizon);
	float gx = grid_line(coord.x, thickness);
	float gy = grid_line(coord.y, thickness * 0.9);
	float lines = clamp(gx + gy, 0.0, 1.0);

	float fade = smoothstep(1.0, 0.08, horizon);
	float alpha = lines * grid_opacity * fade;
	COLOR = vec4(grid_color.rgb, alpha * grid_color.a);
}
