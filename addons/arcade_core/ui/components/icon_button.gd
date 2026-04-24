extends Button

const GLOW_SHADER := preload("res://addons/arcade_core/ui/shaders/glow.gdshader")
const UI_COLORS := preload("res://addons/arcade_core/ui/theme/UIColors.gd")

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_apply_icon()

@export var tooltip_text_override: String = "":
	set(value):
		tooltip_text_override = value
		tooltip_text = value

@export var accessibility_name_override: String = "":
	set(value):
		accessibility_name_override = value
		accessibility_name = value

@export var glow_intensity: float = 0.68

@onready var _icon_rect: TextureRect = $Center/Icon

var _glow_layer: ColorRect
var _base_scale: Vector2 = Vector2.ONE
var _press_tween: Tween
var _t: float = 0.0

func _ready() -> void:
	text = ""
	clip_contents = false
	focus_mode = Control.FOCUS_NONE
	_refresh_center_pivot()
	call_deferred("_refresh_center_pivot")
	_base_scale = scale
	_apply_styles()
	_apply_icon()
	tooltip_text = tooltip_text_override
	accessibility_name = accessibility_name_override
	_ensure_glow_layer()
	mouse_entered.connect(_sync_icon_state)
	mouse_exited.connect(_sync_icon_state)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	_sync_icon_state()

func _process(delta: float) -> void:
	_t += delta
	if _glow_layer == null:
		return
	var material := _glow_layer.material as ShaderMaterial
	if material:
		material.set_shader_parameter("t", _t)

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_refresh_center_pivot()

func _refresh_center_pivot() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	pivot_offset = size * 0.5

func _apply_styles() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = UI_COLORS.utility_button_fill()
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = UI_COLORS.utility_button_edge()
	normal.corner_radius_top_left = 28
	normal.corner_radius_top_right = 28
	normal.corner_radius_bottom_right = 28
	normal.corner_radius_bottom_left = 28
	normal.shadow_color = Color(0.02, 0.05, 0.12, 0.22)
	normal.shadow_size = 12
	normal.anti_aliasing = true
	normal.anti_aliasing_size = 1.2

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = UI_COLORS.utility_button_fill().lightened(0.08)
	hover.border_color = UI_COLORS.ACCENT_COLOR.lightened(0.08)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = UI_COLORS.utility_button_fill().darkened(0.06)
	pressed.border_color = UI_COLORS.PRIMARY_COLOR.lightened(0.12)
	pressed.shadow_size = 6

	var disabled_style: StyleBoxFlat = normal.duplicate()
	disabled_style.bg_color = UI_COLORS.utility_button_fill().darkened(0.06)
	disabled_style.border_color = UI_COLORS.utility_button_edge().darkened(0.12)
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
	mat.set_shader_parameter("glow_color", UI_COLORS.GLOW_COLOR)
	mat.set_shader_parameter("edge_mix", 0.9)
	_glow_layer.material = mat
	add_child(_glow_layer)
	move_child(_glow_layer, 0)

func _apply_icon() -> void:
	if _icon_rect == null:
		return
	_icon_rect.texture = icon_texture

func _sync_icon_state() -> void:
	if _icon_rect == null:
		return
	var intensity: float = glow_intensity
	if disabled:
		_icon_rect.modulate = Color(1.0, 1.0, 1.0, 0.46)
		intensity *= 0.4
	elif button_pressed:
		_icon_rect.modulate = UI_COLORS.ACCENT_COLOR.lightened(0.08)
		intensity *= 1.2
	elif is_hovered():
		_icon_rect.modulate = Color(1.0, 0.95, 0.86, 1.0)
		intensity *= 1.34
	else:
		_icon_rect.modulate = Color(0.94, 0.97, 1.0, 1.0)

	if _glow_layer:
		var mat := _glow_layer.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("intensity", intensity)

func _on_button_down() -> void:
	_animate_scale(_base_scale * 0.96, 0.08)
	_sync_icon_state()

func _on_button_up() -> void:
	var target_scale := _base_scale * (1.03 if is_hovered() else 1.0)
	_animate_scale(target_scale, 0.11)
	_sync_icon_state()

func _animate_scale(target: Vector2, duration: float) -> void:
	if is_instance_valid(_press_tween):
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(self, "scale", target, duration)
