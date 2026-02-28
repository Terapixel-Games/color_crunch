shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float saturation_boost : hint_range(0.7, 1.3) = 1.0;
uniform float brightness_boost : hint_range(0.7, 1.3) = 1.0;

void fragment() {
	vec4 src = texture(screen_tex, SCREEN_UV);
	float luma = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 sat = mix(vec3(luma), src.rgb, saturation_boost);
	vec3 lit = sat * brightness_boost;
	COLOR = vec4(clamp(lit, vec3(0.0), vec3(1.0)), src.a);
}
