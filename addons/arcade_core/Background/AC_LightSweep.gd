class_name AC_LightSweep
extends ColorRect
## Slow, low-opacity diagonal light sweep overlay with randomized interval timing.

var enabled_effect: bool = true
var sweep_opacity: float = 0.08
var interval_min: float = 20.0
var interval_max: float = 40.0
var sweep_speed: float = 0.45

var _sweep_progress: float = -2.0
var _time_to_next: float = 24.0
var _material: ShaderMaterial
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	color = Color(1, 1, 1, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_create_material()
	_schedule_next()

func configure(config: Dictionary) -> void:
	enabled_effect = bool(config.get("enabled", enabled_effect))
	sweep_opacity = clampf(float(config.get("opacity", sweep_opacity)), 0.0, 1.0)
	interval_min = maxf(1.0, float(config.get("interval_min", interval_min)))
	interval_max = maxf(interval_min, float(config.get("interval_max", interval_max)))
	sweep_speed = maxf(0.01, float(config.get("speed", sweep_speed)))
	visible = enabled_effect
	_schedule_next()
	_update_shader_uniforms()

func set_enabled_effect(v: bool) -> void:
	enabled_effect = v
	visible = enabled_effect

func trigger_now(strength: float = 1.0) -> void:
	if not enabled_effect:
		return
	_sweep_progress = -1.2
	if _material != null:
		_material.set_shader_parameter("opacity", sweep_opacity * clampf(strength, 0.0, 2.0))

func tick(delta: float) -> void:
	if not enabled_effect or _material == null:
		return
	if _sweep_progress >= -1.1:
		_sweep_progress += delta * sweep_speed
		_material.set_shader_parameter("band_pos", _sweep_progress)
		if _sweep_progress > 2.2:
			_sweep_progress = -2.0
			_material.set_shader_parameter("band_pos", _sweep_progress)
			_schedule_next()
			_update_shader_uniforms()
	else:
		_time_to_next -= delta
		if _time_to_next <= 0.0:
			trigger_now(1.0)

func _schedule_next() -> void:
	_time_to_next = _rng.randf_range(interval_min, interval_max)

func _create_material() -> void:
	if _material != null:
		return
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float band_pos = -2.0;
uniform float opacity = 0.08;
uniform float band_width = 0.22;

void fragment() {
	vec2 uv = UV;
	float diag = uv.x + uv.y * 0.75;
	float core = abs(diag - band_pos);
	float band = smoothstep(band_width, 0.0, core);
	float feather = smoothstep(band_width * 1.8, band_width * 0.2, core);
	float alpha = band * feather * opacity;
	vec3 col = mix(vec3(0.75, 0.88, 1.0), vec3(1.0), 0.45);
	COLOR = vec4(col, alpha);
}
"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material
	_update_shader_uniforms()

func _update_shader_uniforms() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("opacity", sweep_opacity)
	_material.set_shader_parameter("band_pos", _sweep_progress)
