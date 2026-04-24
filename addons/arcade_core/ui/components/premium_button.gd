extends Button

const UI_COLORS := preload("res://addons/arcade_core/ui/theme/UIColors.gd")
const GLOW_SHADER := preload("res://addons/arcade_core/ui/shaders/glow.gdshader")

@export_enum("primary", "secondary") var button_tier: String = "primary"
@export var idle_pulse_enabled: bool = true
@export var pulse_rate: float = 1.5
@export var pulse_size: float = 0.022
@export var hover_scale: float = 1.03
@export var pressed_scale: float = 0.975
@export var glow_intensity: float = 1.0

var _t: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _state_tween: Tween
var _glow_layer: ColorRect
func _ready() -> void:
	clip_contents = false
	focus_mode = Control.FOCUS_NONE
	_base_scale = scale
	_refresh_center_pivot()
	call_deferred("_refresh_center_pivot")
	_apply_theme()
	_ensure_glow_layer()
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_sync_visual_state()

func _process(delta: float) -> void:
	_t += delta
	if _glow_layer:
		var material := _glow_layer.material as ShaderMaterial
		if material:
			material.set_shader_parameter("t", _t)
	if not idle_pulse_enabled:
		return
	if disabled or button_pressed or is_hovered():
		return
	scale = _base_scale * (1.0 + sin(_t * TAU * pulse_rate) * pulse_size)

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_refresh_center_pivot()

func _refresh_center_pivot() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	pivot_offset = size * 0.5

func _apply_theme() -> void:
	add_theme_font_size_override("font_size", 34 if button_tier == "primary" else 30)
	add_theme_color_override("font_color", Color(0.10, 0.08, 0.06, 1.0) if button_tier == "primary" else UI_COLORS.TEXT_PRIMARY)
	add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.04, 1.0) if button_tier == "primary" else Color.WHITE)
	add_theme_color_override("font_pressed_color", Color(0.08, 0.06, 0.04, 1.0) if button_tier == "primary" else Color.WHITE)
	add_theme_color_override("font_outline_color", Color(0.01, 0.05, 0.14, 0.92))
	add_theme_constant_override("outline_size", 2 if button_tier == "primary" else 3)

	var fill: Color = UI_COLORS.primary_button_fill()
	var edge: Color = UI_COLORS.primary_button_edge()
	if button_tier == "secondary":
		fill = UI_COLORS.secondary_button_fill()
		edge = UI_COLORS.secondary_button_edge()

	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_width_left = 2 if button_tier == "primary" else 1
	normal.border_width_top = normal.border_width_left
	normal.border_width_right = normal.border_width_left
	normal.border_width_bottom = normal.border_width_left
	normal.border_color = edge
	normal.corner_radius_top_left = 26
	normal.corner_radius_top_right = 26
	normal.corner_radius_bottom_right = 26
	normal.corner_radius_bottom_left = 26
	normal.content_margin_left = 18.0
	normal.content_margin_right = 18.0
	normal.content_margin_top = 14.0
	normal.content_margin_bottom = 14.0
	normal.shadow_color = Color(0.02, 0.05, 0.12, 0.26) if button_tier == "primary" else Color(0.02, 0.05, 0.12, 0.18)
	normal.shadow_size = 14 if button_tier == "primary" else 10
	normal.anti_aliasing = true
	normal.anti_aliasing_size = 1.2

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = fill.lightened(0.08)
	hover.border_color = edge.lightened(0.06)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = fill.darkened(0.06)
	pressed.shadow_size = max(0, normal.shadow_size - 4)

	var disabled_style: StyleBoxFlat = normal.duplicate()
	disabled_style.bg_color = fill.darkened(0.16)
	disabled_style.border_color = edge.darkened(0.18)
	disabled_style.shadow_size = 0

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("focus", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("disabled", disabled_style)

func _ensure_glow_layer() -> void:
	if _glow_layer != null:
		return
	_glow_layer = ColorRect.new()
	_glow_layer.name = "GlowLayer"
	_glow_layer.anchor_right = 1.0
	_glow_layer.anchor_bottom = 1.0
	_glow_layer.color = Color(1.0, 1.0, 1.0, 1.0)
	_glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_layer.show_behind_parent = true
	_glow_layer.z_index = -1
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	_glow_layer.material = mat
	add_child(_glow_layer)
	move_child(_glow_layer, 0)

func _sync_visual_state() -> void:
	if _glow_layer == null:
		return
	var material := _glow_layer.material as ShaderMaterial
	if material == null:
		return
	var intensity := glow_intensity
	var color := UI_COLORS.ACCENT_COLOR if button_tier == "primary" else UI_COLORS.GLOW_COLOR
	if button_tier == "secondary":
		intensity *= 0.58
		color = UI_COLORS.PRIMARY_COLOR.lightened(0.18)
	if disabled:
		intensity *= 0.4
	elif button_pressed:
		intensity *= 1.15
	elif is_hovered():
		intensity *= 1.25
	material.set_shader_parameter("glow_color", color)
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("edge_mix", 0.88 if button_tier == "primary" else 0.68)

func _on_mouse_entered() -> void:
	_animate_scale(_base_scale * hover_scale, 0.12)
	_sync_visual_state()

func _on_mouse_exited() -> void:
	_animate_scale(_base_scale, 0.14)
	_sync_visual_state()

func _on_button_down() -> void:
	_animate_scale(_base_scale * pressed_scale, 0.08)
	_sync_visual_state()

func _on_button_up() -> void:
	if is_hovered():
		_animate_scale(_base_scale * hover_scale, 0.09)
	else:
		_animate_scale(_base_scale, 0.1)
	_sync_visual_state()

func _animate_scale(target: Vector2, duration: float) -> void:
	if is_instance_valid(_state_tween):
		_state_tween.kill()
	_state_tween = create_tween()
	_state_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(self, "scale", target, duration)
