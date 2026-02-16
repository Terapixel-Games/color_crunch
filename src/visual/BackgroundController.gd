extends Node2D
class_name BackgroundController

@onready var bg_rect: ColorRect = $ColorRect
@onready var center_glow: ColorRect = $CenterGlow
@onready var particles: GPUParticles2D = $Particles
@onready var streak_particles: GPUParticles2D = $StreakParticles
@onready var long_streak_particles: GPUParticles2D = $LongStreakParticles

var _deterministic := false
var _t := 0.0
var _mood_tween: Tween
var _star_tween: Tween
var _pulse_tween: Tween
var _emission_tween: Tween

var _calm_a := Color(0.88, 0.93, 1.0, 1.0)
var _calm_b := Color(0.64, 0.76, 1.0, 1.0)
var _hype_a := Color(0.2, 0.26, 0.66, 1.0)
var _hype_b := Color(0.6, 0.28, 0.94, 1.0)
var _particle_tex: Texture2D
var _streak_tex: Texture2D
var _boost_particles: GPUParticles2D
var _boost_streak_particles: GPUParticles2D
var _star_density: float = 1.0
var _star_speed: float = 1.0
var _star_brightness: float = 0.4
var _match_density_mul: float = 1.0
var _match_speed_mul: float = 1.0
var _match_brightness_mul: float = 1.0
var _emission_activity: float = 1.0
var _current_calm_weight: float = 1.0
var _menu_density_mul: float = 1.0
var _menu_alpha_mul: float = 1.0
var _menu_emission_persistent: bool = false
var _calm_point_color: Color = Color(0.36, 0.84, 1.0, 1.0)
var _calm_streak_color: Color = Color(0.58, 0.92, 1.0, 1.0)
var _hype_point_color: Color = Color(1, 1, 1, 1)
var _hype_streak_color: Color = Color(1, 1, 1, 1)
var _base_point_color: Color = Color(1, 1, 1, 1)
var _base_streak_color: Color = Color(1, 1, 1, 1)
var _boost_point_color: Color = Color(1, 1, 1, 1)
var _boost_streak_color: Color = Color(1, 1, 1, 1)
var _viewport_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/visual/GradientBackground.gdshader")
	mat.set_shader_parameter("color_a", _calm_a)
	mat.set_shader_parameter("color_b", _calm_b)
	bg_rect.material = mat
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_rect.position = Vector2.ZERO
	_viewport_size = get_viewport_rect().size
	bg_rect.set_deferred("size", _viewport_size)
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = preload("res://src/visual/CenterGlow.gdshader")
	center_glow.material = glow_mat
	center_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_glow.position = Vector2.ZERO
	center_glow.set_deferred("size", _viewport_size)
	var center: Vector2 = _viewport_size * 0.5
	particles.position = center
	streak_particles.position = center
	long_streak_particles.position = center
	_particle_tex = _build_soft_particle_texture(34, 1.6)
	_streak_tex = _build_streak_texture(56, 18)
	particles.texture = _particle_tex
	streak_particles.texture = _streak_tex
	_setup_boost_emitters(center)
	var pm: ParticleProcessMaterial = particles.process_material
	if pm:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		pm.direction = Vector3(1.0, 0.0, 0.0)
		pm.spread = 180.0
		pm.gravity = Vector3.ZERO
	var spm: ParticleProcessMaterial = streak_particles.process_material
	if spm:
		spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		spm.direction = Vector3(1.0, 0.0, 0.0)
		spm.spread = 180.0
		spm.gravity = Vector3.ZERO
	var lspm: ParticleProcessMaterial = long_streak_particles.process_material
	if lspm:
		lspm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		lspm.direction = Vector3(1.0, 0.0, 0.0)
		lspm.spread = 180.0
		lspm.gravity = Vector3.ZERO
	particles.emitting = true
	streak_particles.emitting = true
	long_streak_particles.emitting = true
	_boost_particles.emitting = false
	_boost_streak_particles.emitting = false
	_calm_point_color = FeatureFlags.starfield_calm_point_color()
	_calm_streak_color = FeatureFlags.starfield_calm_streak_color()
	_hype_point_color = FeatureFlags.starfield_hype_point_color()
	_hype_streak_color = FeatureFlags.starfield_hype_streak_color()
	_base_point_color = _calm_point_color
	_base_streak_color = _calm_streak_color
	_boost_point_color = FeatureFlags.starfield_boost_point_color()
	_boost_streak_color = FeatureFlags.starfield_boost_streak_color()
	reset_starfield_emission_taper()
	set_mood(BackgroundMood.get_mood())

func _process(delta: float) -> void:
	if _deterministic:
		_t = 0.0
	else:
		_t += delta
		_update_starfield_runtime()
	_sync_layout()
	if bg_rect.material:
		bg_rect.material.set_shader_parameter("t", _t)
		bg_rect.material.set_shader_parameter("drift", 0.0 if _deterministic else 1.0)
	if center_glow.material:
		center_glow.material.set_shader_parameter("t", _t)

func set_mood(mood: int, fade_seconds: float = 0.8) -> void:
	var to_a := _calm_a if mood == BackgroundMood.Mood.CALM else _hype_a
	var to_b := _calm_b if mood == BackgroundMood.Mood.CALM else _hype_b
	var calm_weight: float = 1.0 if mood == BackgroundMood.Mood.CALM else 0.0
	_current_calm_weight = calm_weight
	_apply_mood_targets(to_a, to_b, calm_weight, fade_seconds)

func set_mood_mix(calm_weight: float, fade_seconds: float = 0.8) -> void:
	var mix_t: float = clamp(calm_weight, 0.0, 1.0)
	_current_calm_weight = mix_t
	var to_a: Color = _hype_a.lerp(_calm_a, mix_t)
	var to_b: Color = _hype_b.lerp(_calm_b, mix_t)
	_apply_mood_targets(to_a, to_b, mix_t, fade_seconds)

func set_theme_palette(calm_a: Color, calm_b: Color, hype_a: Color, hype_b: Color) -> void:
	_calm_a = calm_a
	_calm_b = calm_b
	_hype_a = hype_a
	_hype_b = hype_b
	if bg_rect and bg_rect.material:
		bg_rect.material.set_shader_parameter("color_a", _calm_a)
		bg_rect.material.set_shader_parameter("color_b", _calm_b)
	set_mood(BackgroundMood.get_mood(), 0.2)

func _apply_mood_targets(to_a: Color, to_b: Color, calm_weight: float, fade_seconds: float) -> void:
	if is_instance_valid(_mood_tween):
		_mood_tween.kill()
	_mood_tween = create_tween()
	_mood_tween.set_parallel(true)
	_mood_tween.tween_property(bg_rect.material, "shader_parameter/color_a", to_a, fade_seconds)
	_mood_tween.tween_property(bg_rect.material, "shader_parameter/color_b", to_b, fade_seconds)
	var hype: float = 1.0 - clamp(calm_weight, 0.0, 1.0)
	var density: float = lerp(FeatureFlags.starfield_calm_density(), FeatureFlags.starfield_hype_density(), hype)
	# Keep baseline speed calm in all moods; only match pulses accelerate speed.
	var speed: float = FeatureFlags.starfield_calm_speed()
	var brightness: float = lerp(FeatureFlags.starfield_calm_brightness(), FeatureFlags.starfield_hype_brightness(), hype)
	_base_point_color = _calm_point_color.lerp(_hype_point_color, hype)
	_base_streak_color = _calm_streak_color.lerp(_hype_streak_color, hype)
	_set_starfield_profile(density, speed, brightness, fade_seconds)

func set_deterministic(enabled: bool) -> void:
	_deterministic = enabled
	if enabled:
		particles.emitting = false
		streak_particles.emitting = false
		long_streak_particles.emitting = false
		if _boost_particles:
			_boost_particles.emitting = false
		if _boost_streak_particles:
			_boost_streak_particles.emitting = false
		if is_instance_valid(_emission_tween):
			_emission_tween.kill()

func pulse_starfield() -> void:
	if _deterministic:
		return
	if is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
	_match_density_mul = FeatureFlags.starfield_match_pulse_density_mult()
	_match_speed_mul = FeatureFlags.starfield_match_pulse_speed_mult()
	_match_brightness_mul = FeatureFlags.starfield_match_pulse_brightness_mult()
	_update_starfield_runtime()
	_pulse_tween = create_tween()
	# Mirror match-layer envelope timing: hold, then taper back to base.
	_pulse_tween.tween_interval(FeatureFlags.combo_decay_delay_seconds())
	if _boost_particles:
		_boost_particles.restart()
		_boost_particles.emitting = true
	if _boost_streak_particles:
		_boost_streak_particles.restart()
		_boost_streak_particles.emitting = true
	_pulse_tween.set_parallel(true)
	_pulse_tween.tween_method(func(v: float) -> void:
		_match_speed_mul = v
		_update_starfield_runtime()
	, _match_speed_mul, 1.0, FeatureFlags.combo_decay_seconds())
	_pulse_tween.tween_method(func(v: float) -> void:
		_match_density_mul = v
	, _match_density_mul, 1.0, FeatureFlags.combo_decay_seconds())
	_pulse_tween.tween_method(func(v: float) -> void:
		_match_brightness_mul = v
	, _match_brightness_mul, 1.0, FeatureFlags.combo_decay_seconds())
	_pulse_tween.finished.connect(func() -> void:
		if _boost_particles:
			_boost_particles.emitting = false
		if _boost_streak_particles:
			_boost_streak_particles.emitting = false
	)

func reset_starfield_emission_taper(ramp_up_seconds: float = -1.0) -> void:
	if _deterministic:
		return
	if is_instance_valid(_emission_tween):
		_emission_tween.kill()
	var ramp_up: float = ramp_up_seconds
	if ramp_up < 0.0:
		ramp_up = FeatureFlags.starfield_emission_ramp_up_seconds()
	ramp_up = max(0.0, ramp_up)
	var duration: float = max(0.1, FeatureFlags.match_hint_delay_seconds())
	var hype_weight: float = 1.0 - clamp(_current_calm_weight, 0.0, 1.0)
	var target_floor: float = lerp(
		FeatureFlags.starfield_calm_emission_floor(),
		FeatureFlags.starfield_hype_emission_floor(),
		hype_weight
	)
	_emission_tween = create_tween()
	if ramp_up > 0.0:
		_emission_tween.tween_method(Callable(self, "_set_emission_activity"), _emission_activity, 1.0, ramp_up)
	else:
		_set_emission_activity(1.0)
	_emission_tween.tween_method(Callable(self, "_set_emission_activity"), 1.0, target_floor, duration)

func set_emission_activity(value: float, stop_taper: bool = false) -> void:
	if stop_taper and is_instance_valid(_emission_tween):
		_emission_tween.kill()
	_set_emission_activity(value)

func set_menu_visibility_boost(density_mul: float = 1.0, alpha_mul: float = 1.0) -> void:
	_menu_density_mul = max(1.0, density_mul)
	_menu_alpha_mul = max(1.0, alpha_mul)
	_update_starfield_runtime()

func set_menu_emission_persistent(enabled: bool) -> void:
	_menu_emission_persistent = enabled
	if _menu_emission_persistent:
		if is_instance_valid(_emission_tween):
			_emission_tween.kill()
		_set_emission_activity(1.0)

func _set_starfield_profile(density: float, speed: float, brightness: float, fade_seconds: float) -> void:
	_star_density = max(0.1, density)
	_star_speed = max(0.1, speed)
	_star_brightness = max(0.1, brightness)
	particles.amount = int(round(300.0 * _star_density))
	streak_particles.amount = int(round(86.0 * _star_density))
	long_streak_particles.amount = max(2, int(round(12.0 * _star_density)))
	var pm: ParticleProcessMaterial = particles.process_material
	if pm:
		pm.initial_velocity_min = 180.0 * _star_speed
		pm.initial_velocity_max = 340.0 * _star_speed
		pm.radial_accel_min = 0.0
		pm.radial_accel_max = 0.0
		pm.linear_accel_min = 130.0 * _star_speed
		pm.linear_accel_max = 260.0 * _star_speed
		pm.scale_min = 0.14
		pm.scale_max = 0.3
	var spm: ParticleProcessMaterial = streak_particles.process_material
	if spm:
		spm.initial_velocity_min = 420.0 * _star_speed
		spm.initial_velocity_max = 760.0 * _star_speed
		spm.radial_accel_min = 0.0
		spm.radial_accel_max = 0.0
		spm.linear_accel_min = 240.0 * _star_speed
		spm.linear_accel_max = 420.0 * _star_speed
		spm.scale_min = 0.3
		spm.scale_max = 0.72
	var lspm: ParticleProcessMaterial = long_streak_particles.process_material
	if lspm:
		lspm.initial_velocity_min = 560.0 * _star_speed
		lspm.initial_velocity_max = 1020.0 * _star_speed
		lspm.radial_accel_min = 0.0
		lspm.radial_accel_max = 0.0
		lspm.linear_accel_min = 320.0 * _star_speed
		lspm.linear_accel_max = 520.0 * _star_speed
		lspm.scale_min = 0.34
		lspm.scale_max = 0.85
	if is_instance_valid(_star_tween):
		_star_tween.kill()
	_star_tween = create_tween()
	_star_tween.set_parallel(true)
	_star_tween.tween_property(particles, "modulate", Color(1, 1, 1, min(1.0, 0.9 * _star_brightness)), fade_seconds)
	_star_tween.tween_property(streak_particles, "modulate", Color(1, 1, 1, min(1.0, 1.0 * _star_brightness)), fade_seconds)
	_star_tween.tween_property(long_streak_particles, "modulate", Color(1, 1, 1, min(1.0, 0.92 * _star_brightness)), fade_seconds)
	_update_starfield_runtime()

func _update_starfield_runtime() -> void:
	if _menu_emission_persistent and _emission_activity < 1.0:
		_emission_activity = 1.0
	var bpm: float = float(FeatureFlags.BPM)
	if MusicManager and MusicManager.has_method("get_current_track_bpm"):
		bpm = max(40.0, float(MusicManager.get_current_track_bpm()))
	var beat_hz: float = bpm / 60.0
	var beat_wave: float = sin(_t * TAU * beat_hz)
	var beat_pulse_depth: float = FeatureFlags.starfield_beat_pulse_depth()
	var beat_speed_mul: float = 1.0
	var pulse01: float = (beat_wave + 1.0) * 0.5
	var beat_brightness_mul: float = 1.0 + (pulse01 * beat_pulse_depth * 0.5)
	var density_mul: float = _menu_density_mul
	var speed_mul: float = beat_speed_mul
	var brightness_mul: float = _match_brightness_mul * beat_brightness_mul * _menu_alpha_mul

	particles.amount = max(1, int(round(300.0 * _star_density * density_mul)))
	streak_particles.amount = max(1, int(round(86.0 * _star_density * density_mul)))
	long_streak_particles.amount = max(1, int(round(10.0 * _star_density * density_mul)))
	# Keep base field velocity stable; match speed boost is additive via boost emitters only.
	particles.speed_scale = _star_speed * speed_mul
	streak_particles.speed_scale = _star_speed * speed_mul
	long_streak_particles.speed_scale = _star_speed * speed_mul * 1.12
	particles.modulate = Color(
		_base_point_color.r,
		_base_point_color.g,
		_base_point_color.b,
		min(1.0, 0.9 * _star_brightness * brightness_mul * _emission_activity)
	)
	streak_particles.modulate = Color(
		_base_streak_color.r,
		_base_streak_color.g,
		_base_streak_color.b,
		min(1.0, 1.0 * _star_brightness * brightness_mul * _emission_activity)
	)
	long_streak_particles.modulate = Color(
		_base_streak_color.r,
		_base_streak_color.g,
		_base_streak_color.b,
		min(1.0, 0.82 * _star_brightness * brightness_mul * _emission_activity)
	)
	particles.emitting = _emission_activity > 0.01
	streak_particles.emitting = _emission_activity > 0.01
	long_streak_particles.emitting = _emission_activity > 0.01
	if center_glow.material:
		center_glow.material.set_shader_parameter(
			"glow_color",
			Color(_base_streak_color.r, _base_streak_color.g, _base_streak_color.b, 0.16 + (0.18 * _star_brightness * _emission_activity))
		)
	_update_boost_emitters()

func _setup_boost_emitters(center: Vector2) -> void:
	_boost_particles = GPUParticles2D.new()
	_boost_particles.name = "BoostParticles"
	_boost_particles.position = center
	_boost_particles.local_coords = true
	_boost_particles.one_shot = true
	_boost_particles.explosiveness = 1.0
	_boost_particles.lifetime = particles.lifetime
	_boost_particles.preprocess = particles.preprocess
	_boost_particles.texture = _particle_tex
	_boost_particles.process_material = (particles.process_material as ParticleProcessMaterial).duplicate(true)
	add_child(_boost_particles)

	_boost_streak_particles = GPUParticles2D.new()
	_boost_streak_particles.name = "BoostStreakParticles"
	_boost_streak_particles.position = center
	_boost_streak_particles.local_coords = true
	_boost_streak_particles.one_shot = true
	_boost_streak_particles.explosiveness = 1.0
	_boost_streak_particles.lifetime = streak_particles.lifetime
	_boost_streak_particles.preprocess = streak_particles.preprocess
	_boost_streak_particles.texture = _streak_tex
	_boost_streak_particles.process_material = (streak_particles.process_material as ParticleProcessMaterial).duplicate(true)
	add_child(_boost_streak_particles)

func _update_boost_emitters() -> void:
	if _boost_particles == null or _boost_streak_particles == null:
		return
	var extra_density: float = max(0.0, _match_density_mul - 1.0)
	_boost_particles.amount = max(1, int(round(220.0 * _star_density * extra_density)))
	_boost_streak_particles.amount = max(1, int(round(70.0 * _star_density * extra_density)))
	_boost_particles.speed_scale = _star_speed * _match_speed_mul
	_boost_streak_particles.speed_scale = _star_speed * _match_speed_mul
	_boost_particles.modulate = Color(
		_boost_point_color.r,
		_boost_point_color.g,
		_boost_point_color.b,
		min(1.0, 0.85 * _star_brightness * _match_brightness_mul)
	)
	_boost_streak_particles.modulate = Color(
		_boost_streak_color.r,
		_boost_streak_color.g,
		_boost_streak_color.b,
		min(1.0, 1.0 * _star_brightness * _match_brightness_mul)
	)
	if _emission_activity <= 0.01:
		_boost_particles.emitting = false
		_boost_streak_particles.emitting = false

func _set_emission_activity(v: float) -> void:
	_emission_activity = clamp(v, 0.0, 1.0)
	particles.emitting = _emission_activity > 0.01
	streak_particles.emitting = _emission_activity > 0.01
	long_streak_particles.emitting = _emission_activity > 0.01

func _sync_layout() -> void:
	var next_size: Vector2 = get_viewport_rect().size
	if next_size == _viewport_size:
		return
	_viewport_size = next_size
	bg_rect.size = _viewport_size
	center_glow.size = _viewport_size
	var center: Vector2 = _viewport_size * 0.5
	particles.position = center
	streak_particles.position = center
	long_streak_particles.position = center
	if _boost_particles:
		_boost_particles.position = center
	if _boost_streak_particles:
		_boost_streak_particles.position = center

func _build_soft_particle_texture(size: int, softness: float) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius: float = size * 0.5
	for y in range(size):
		for x in range(size):
			var d: float = center.distance_to(Vector2(x, y)) / radius
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			a = pow(a, softness)
			if d < 0.28:
				a = min(1.0, a + 0.35)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(image)

func _build_streak_texture(width: int, height: int) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var center_y: float = float(height) * 0.5
	for y in range(height):
		for x in range(width):
			var ux: float = float(x) / max(1.0, float(width - 1))
			var uy: float = abs(float(y) - center_y) / max(1.0, center_y)
			# Symmetric streak body avoids false "reverse" direction cues.
			var along: float = 1.0 - abs(ux * 2.0 - 1.0)
			var x_falloff: float = pow(max(0.0, along), 0.55)
			var y_falloff: float = pow(max(0.0, 1.0 - uy), 1.3)
			var a: float = x_falloff * y_falloff
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(image)
