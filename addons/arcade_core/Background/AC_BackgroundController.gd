class_name AC_BackgroundController
extends Node2D
## Orchestrates all background layers and runtime reactivity from profile data.

const BACKGROUND_PROFILES_SCRIPT := preload("res://addons/arcade_core/Background/AC_BackgroundProfiles.gd")
const PARALLAX_LAYER_SCRIPT := preload("res://addons/arcade_core/Background/AC_ParallaxLayer.gd")
const FLOW_PARTICLES_SCRIPT := preload("res://addons/arcade_core/Background/AC_FlowFieldParticles.gd")
const LIGHT_SWEEP_SCRIPT := preload("res://addons/arcade_core/Background/AC_LightSweep.gd")

signal profile_loaded(name: String)
signal tier_changed(tier: int)
signal performance_throttled(new_count: int)

@export var profiles_path: String = BACKGROUND_PROFILES_SCRIPT.DEFAULT_PATH
@export var initial_profile: String = "calm_puzzle"
@export var initial_tier: int = 1
@export var combo_lerp_speed: float = 2.6

var active_profile_name: String = ""
var active_profile: Variant = null

var _combo_target: float = 0.0
var _combo_current: float = 0.0
var _tier: int = 1
var _paused_background: bool = false
var _time_sec: float = 0.0
var _powerup_boost: float = 0.0

var _current_parallax_speed_mult: float = 1.0
var _target_parallax_speed_mult: float = 1.0
var _current_flow_speed_mult: float = 1.0
var _target_flow_speed_mult: float = 1.0
var _target_flow_count_mult: float = 1.0
var _current_flow_count_mult: float = 1.0
var _target_hue_speed_mult: float = 1.0
var _current_hue_speed_mult: float = 1.0
var _combo_reactive_enabled: bool = false
var _grid_reactive_boost: float = 0.0

var _layer_overrides: Dictionary = {}

var _background_canvas: CanvasLayer
var _viewport_root: Control
var _gradient_rect: ColorRect
var _parallax_root: Node2D
var _flow_particles: Node2D
var _grid_rect: ColorRect
var _sweep_layer: ColorRect
var _color_grade_rect: ColorRect

var _gradient_material: ShaderMaterial
var _grid_material: ShaderMaterial
var _color_grade_material: ShaderMaterial

var _parallax_layers: Array = []
var _viewport_size: Vector2 = Vector2(1080.0, 1920.0)

func _ready() -> void:
	_viewport_size = _resolve_viewport_size()
	_ensure_nodes()
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	load_profile(initial_profile)
	set_tier(initial_tier)
	set_process(true)

func _exit_tree() -> void:
	var viewport := get_viewport()
	if viewport != null and viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.disconnect(_on_viewport_size_changed)

func _process(delta: float) -> void:
	if _paused_background or active_profile == null:
		return

	_time_sec += delta
	_combo_current = move_toward(_combo_current, _combo_target, delta * combo_lerp_speed)
	_powerup_boost = move_toward(_powerup_boost, 0.0, delta * 1.2)
	_grid_reactive_boost = move_toward(_grid_reactive_boost, 0.0, delta * 1.6)

	_current_parallax_speed_mult = _smooth(_current_parallax_speed_mult, _target_parallax_speed_mult, delta, 2.4)
	_current_flow_speed_mult = _smooth(_current_flow_speed_mult, _target_flow_speed_mult, delta, 2.8)
	_current_flow_count_mult = _smooth(_current_flow_count_mult, _target_flow_count_mult, delta, 2.2)
	_current_hue_speed_mult = _smooth(_current_hue_speed_mult, _target_hue_speed_mult, delta, 1.9)

	var combo_drive := _combo_current if _combo_reactive_enabled else 0.0

	_update_gradient(combo_drive)
	_update_parallax(delta, combo_drive)
	_update_flow(delta, combo_drive)
	_update_grid(combo_drive)
	_update_color_grade(combo_drive)
	_update_sweep(delta)

func load_profile(profile_name: String) -> void:
	var profile: Variant = BACKGROUND_PROFILES_SCRIPT.get_profile(profile_name, profiles_path)
	apply_profile(profile)

func apply_profile(profile: Variant) -> void:
	if profile == null:
		return
	active_profile = profile
	active_profile_name = profile.profile_name

	_apply_gradient_config(profile.gradient)
	_apply_parallax_config(profile.parallax_layers)
	_apply_flow_config(profile.flow_particles)
	_apply_grid_config(profile.grid)
	_apply_sweep_config(profile.sweep)

	set_tier(_tier)
	_sync_layer_visibility()
	emit_signal("profile_loaded", active_profile_name)

func set_combo_intensity(v: float) -> void:
	_combo_target = clampf(v, 0.0, 1.0)

func set_tier(t: int) -> void:
	_tier = maxi(1, t)
	if active_profile == null:
		emit_signal("tier_changed", _tier)
		return

	var tier_settings: Dictionary = active_profile.get_tier_settings(_tier)
	_target_parallax_speed_mult = float(tier_settings.get("parallax_speed_mult", 1.0))
	_target_flow_speed_mult = float(tier_settings.get("flow_speed_mult", 1.0))
	_target_flow_count_mult = float(tier_settings.get("flow_count_mult", 1.0))
	_target_hue_speed_mult = float(tier_settings.get("hue_speed_mult", 1.0))
	_combo_reactive_enabled = bool(tier_settings.get("combo_reactive", false))

	var tier_grid_enabled := bool(tier_settings.get("grid_enabled", false))
	if active_profile.grid.has("enabled"):
		_grid_rect.visible = tier_grid_enabled and bool(active_profile.grid.get("enabled", false))

	_grid_reactive_boost = maxf(_grid_reactive_boost, float(tier_settings.get("grid_warp_boost", 0.0)))
	_sync_layer_visibility()
	emit_signal("tier_changed", _tier)

func trigger_powerup_pulse(strength: float = 1.0) -> void:
	var s := clampf(strength, 0.0, 2.0)
	_powerup_boost = maxf(_powerup_boost, s)
	_grid_reactive_boost = maxf(_grid_reactive_boost, s)
	if _sweep_layer != null:
		_sweep_layer.trigger_now(0.8 + s * 0.3)

func set_enabled_layer(layer_id: String, enabled: bool) -> void:
	_layer_overrides[layer_id] = enabled
	_sync_layer_visibility()

func set_pause_background(paused: bool) -> void:
	_paused_background = paused

func _ensure_nodes() -> void:
	if _background_canvas != null:
		return

	_background_canvas = CanvasLayer.new()
	_background_canvas.layer = -100
	add_child(_background_canvas)

	_viewport_root = Control.new()
	_viewport_root.name = "ViewportRoot"
	_viewport_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background_canvas.add_child(_viewport_root)

	_gradient_rect = ColorRect.new()
	_gradient_rect.name = "Gradient"
	_gradient_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gradient_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gradient_rect.z_index = 0
	_gradient_material = ShaderMaterial.new()
	_gradient_material.shader = load("res://addons/arcade_core/Background/AC_GradientWarp.shader")
	_gradient_rect.material = _gradient_material
	_viewport_root.add_child(_gradient_rect)

	_parallax_root = Node2D.new()
	_parallax_root.name = "ParallaxRoot"
	_parallax_root.z_index = 10
	_viewport_root.add_child(_parallax_root)

	_flow_particles = FLOW_PARTICLES_SCRIPT.new()
	_flow_particles.name = "FlowParticles"
	_flow_particles.z_index = 20
	_flow_particles.throttled.connect(_on_flow_throttled)
	_viewport_root.add_child(_flow_particles)

	_grid_rect = ColorRect.new()
	_grid_rect.name = "Grid"
	_grid_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid_rect.z_index = 30
	_grid_material = ShaderMaterial.new()
	_grid_material.shader = load("res://addons/arcade_core/Background/AC_GridWarp.shader")
	_grid_rect.material = _grid_material
	_viewport_root.add_child(_grid_rect)

	_sweep_layer = LIGHT_SWEEP_SCRIPT.new()
	_sweep_layer.name = "Sweep"
	_sweep_layer.z_index = 40
	_viewport_root.add_child(_sweep_layer)

	_color_grade_rect = ColorRect.new()
	_color_grade_rect.name = "ColorGrade"
	_color_grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_grade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_color_grade_rect.z_index = 50
	_color_grade_material = ShaderMaterial.new()
	_color_grade_material.shader = load("res://addons/arcade_core/Background/AC_ColorGrade.shader")
	_color_grade_rect.material = _color_grade_material
	_viewport_root.add_child(_color_grade_rect)

func _on_viewport_size_changed() -> void:
	_viewport_size = _resolve_viewport_size()
	if _viewport_size.x <= 0.0 or _viewport_size.y <= 0.0:
		return
	if _viewport_root != null:
		_viewport_root.size = _viewport_size
	if _flow_particles != null:
		_flow_particles.set_bounds_from_viewport(_viewport_size)
	for layer in _parallax_layers:
		if layer != null:
			layer.set_viewport_size(_viewport_size)

func _apply_gradient_config(cfg: Dictionary) -> void:
	_gradient_material.set_shader_parameter("base_color_a", Color.from_string(str(cfg.get("base_color_a", "#101825")), Color(0.06, 0.10, 0.15)))
	_gradient_material.set_shader_parameter("base_color_b", Color.from_string(str(cfg.get("base_color_b", "#2a1b3f")), Color(0.16, 0.11, 0.24)))
	_gradient_material.set_shader_parameter("hue_speed", float(cfg.get("hue_speed", 0.012)))
	_gradient_material.set_shader_parameter("pulse_intensity", float(cfg.get("pulse_intensity", 0.06)))
	_gradient_material.set_shader_parameter("pulse_speed", float(cfg.get("pulse_speed", 0.22)))
	_gradient_material.set_shader_parameter("vignette", float(cfg.get("vignette", 0.2)))

func _apply_parallax_config(layer_data: Array[Dictionary]) -> void:
	_ensure_parallax_pool(layer_data.size())
	for i in range(_parallax_layers.size()):
		var layer: Node2D = _parallax_layers[i]
		if layer == null:
			continue
		var enabled := i < layer_data.size()
		layer.visible = enabled
		if enabled:
			layer.configure(layer_data[i], _viewport_size)

func _ensure_parallax_pool(count: int) -> void:
	while _parallax_layers.size() < count:
		var layer: Node2D = PARALLAX_LAYER_SCRIPT.new()
		layer.name = "ParallaxLayer_%d" % _parallax_layers.size()
		layer.z_index = _parallax_layers.size()
		_parallax_root.add_child(layer)
		_parallax_layers.append(layer)

func _apply_flow_config(cfg: Dictionary) -> void:
	_flow_particles.configure(cfg, _viewport_size)

func _apply_grid_config(cfg: Dictionary) -> void:
	_grid_material.set_shader_parameter("grid_color", Color.from_string(str(cfg.get("color", "#56caff")), Color(0.35, 0.82, 1.0)))
	_grid_material.set_shader_parameter("grid_opacity", float(cfg.get("opacity", 0.12)))
	_grid_material.set_shader_parameter("warp_amount", float(cfg.get("warp_amount", 0.06)))
	_grid_material.set_shader_parameter("warp_speed", float(cfg.get("warp_speed", 0.35)))
	_grid_material.set_shader_parameter("line_thickness", float(cfg.get("thickness", 0.045)))
	_grid_material.set_shader_parameter("spacing", float(cfg.get("spacing", 52.0)))

func _apply_sweep_config(cfg: Dictionary) -> void:
	_sweep_layer.configure(cfg)

func _update_gradient(combo_drive: float) -> void:
	if _gradient_material == null or active_profile == null:
		return
	var base_hue := float(active_profile.gradient.get("hue_speed", 0.012))
	var base_pulse := float(active_profile.gradient.get("pulse_intensity", 0.06))
	var base_speed := float(active_profile.gradient.get("pulse_speed", 0.22))

	_gradient_material.set_shader_parameter("time_sec", _time_sec)
	_gradient_material.set_shader_parameter("hue_speed", base_hue * _current_hue_speed_mult)
	_gradient_material.set_shader_parameter("pulse_intensity", clampf(base_pulse + combo_drive * 0.05 + _powerup_boost * 0.1, 0.0, 1.0))
	_gradient_material.set_shader_parameter("pulse_speed", clampf(base_speed + combo_drive * 0.4 + _powerup_boost * 0.7, 0.0, 6.0))

func _update_parallax(delta: float, combo_drive: float) -> void:
	if _parallax_root == null or not _parallax_root.visible:
		return
	var speed_boost := _current_parallax_speed_mult * (1.0 + combo_drive * 0.2)
	for layer in _parallax_layers:
		if layer != null and layer.visible:
			layer.set_intensity(0.65 + combo_drive * 0.35)
			layer.tick(delta, speed_boost)

func _update_flow(delta: float, combo_drive: float) -> void:
	if _flow_particles == null:
		return
	var intensity := clampf(_current_flow_count_mult * 0.75 + combo_drive * 0.35, 0.0, 1.0)
	_flow_particles.set_intensity(intensity)
	_flow_particles.set_speed_multiplier(_current_flow_speed_mult * (1.0 + combo_drive * 0.2 + _powerup_boost * 0.12))
	_flow_particles.tick(delta)

func _update_grid(combo_drive: float) -> void:
	if _grid_material == null:
		return
	_grid_material.set_shader_parameter("time_sec", _time_sec)
	_grid_material.set_shader_parameter("reactive_boost", clampf(_grid_reactive_boost + combo_drive * 0.45 + _powerup_boost * 0.5, 0.0, 1.0))

func _update_color_grade(combo_drive: float) -> void:
	if _color_grade_material == null:
		return
	var sat := 1.0 + combo_drive * 0.15
	var brt := 1.0 + combo_drive * 0.12
	_color_grade_material.set_shader_parameter("saturation_boost", sat)
	_color_grade_material.set_shader_parameter("brightness_boost", brt)

func _update_sweep(delta: float) -> void:
	if _sweep_layer != null:
		_sweep_layer.tick(delta)

func _on_flow_throttled(new_count: int) -> void:
	emit_signal("performance_throttled", new_count)

func _sync_layer_visibility() -> void:
	if active_profile == null:
		return

	_gradient_rect.visible = _layer_flag("gradient", true)
	_parallax_root.visible = _layer_flag("parallax", true)
	_flow_particles.set_enabled_effect(_layer_flag("flow_particles", bool(active_profile.flow_particles.get("enabled", true))))
	_grid_rect.visible = _layer_flag("grid", _grid_rect.visible)
	_sweep_layer.set_enabled_effect(_layer_flag("sweep", bool(active_profile.sweep.get("enabled", true))))
	_color_grade_rect.visible = _layer_flag("color_grade", true)

func _layer_flag(layer_id: String, default_enabled: bool) -> bool:
	if _layer_overrides.has(layer_id):
		return bool(_layer_overrides[layer_id])
	return default_enabled

func _smooth(current: float, target: float, delta: float, speed: float) -> float:
	var t := 1.0 - exp(-delta * speed)
	return lerpf(current, target, t)

func _resolve_viewport_size() -> Vector2:
	var size := get_viewport_rect().size
	if size.x > 0.0 and size.y > 0.0:
		return size
	var width := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1080))
	var height := float(ProjectSettings.get_setting("display/window/size/viewport_height", 1920))
	return Vector2(maxf(1.0, width), maxf(1.0, height))
