extends Button
class_name LiquidGlassButton

@export var tint: Color = Color(0.95, 0.97, 1.0, 0.22)
@export var edge_highlight: Color = Color(1.0, 1.0, 1.0, 0.48)
@export var blur: float = 2.8
@export var warp_intensity: float = 0.26
@export var strength_x: float = 11.0
@export var strength_y: float = 11.0
@export var offset_x: float = 0.0
@export var offset_y: float = 0.0
@export var corner_radius: float = 0.3
@export var edge_smoothness: float = 1.05
@export var edge_width: float = 1.35
@export var chromatic_strength: float = 1.2
var _last_disabled: bool = false
var _press_tween: Tween
var _base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	flat = false
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	_refresh_center_pivot()
	call_deferred("_refresh_center_pivot")
	_base_scale = scale
	_apply_style_overrides()
	_ensure_glass_layer()
	mouse_entered.connect(_sync_glass_state)
	mouse_exited.connect(_sync_glass_state)
	pressed.connect(_sync_glass_state)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	toggled.connect(_sync_glass_state)
	_last_disabled = disabled
	_sync_glass_state()

func _can_use_glass_shader() -> bool:
	# Headless test runs can crash in some environments when creating UI shaders.
	return DisplayServer.get_name() != "headless"

func _process(_delta: float) -> void:
	if _last_disabled != disabled:
		_last_disabled = disabled
		_sync_glass_state()

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_refresh_center_pivot()

func _refresh_center_pivot() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	pivot_offset = size * 0.5

func _apply_style_overrides() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.16, 0.32, 0.38)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.88, 0.95, 1.0, 0.55)
	normal.corner_radius_top_left = 20
	normal.corner_radius_top_right = 20
	normal.corner_radius_bottom_right = 20
	normal.corner_radius_bottom_left = 20
	normal.shadow_size = 0
	normal.anti_aliasing = true
	normal.anti_aliasing_size = 1.1

	var hover := normal.duplicate()
	hover.bg_color = Color(0.13, 0.2, 0.38, 0.5)
	hover.border_color = Color(0.95, 0.99, 1.0, 0.7)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.08, 0.13, 0.27, 0.58)
	pressed.border_color = Color(0.82, 0.92, 1.0, 0.65)
	var disabled_style := normal.duplicate()
	disabled_style.bg_color = Color(0.14, 0.18, 0.28, 0.24)
	disabled_style.border_color = Color(0.78, 0.86, 0.95, 0.35)

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", normal)
	add_theme_stylebox_override("disabled", disabled_style)

	add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 1.0))
	add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	add_theme_color_override("font_pressed_color", Color(0.98, 0.99, 1.0, 1.0))
	add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
	add_theme_color_override("font_disabled_color", Color(0.84, 0.86, 0.92, 0.82))
	add_theme_color_override("font_outline_color", Color(0.03, 0.06, 0.12, 0.9))
	add_theme_constant_override("outline_size", 2)

func _ensure_glass_layer() -> void:
	if not _can_use_glass_shader():
		var existing: ColorRect = get_node_or_null("LiquidGlassLayer") as ColorRect
		if existing:
			existing.queue_free()
		return
	var layer: ColorRect = get_node_or_null("LiquidGlassLayer") as ColorRect
	if layer == null:
		layer = ColorRect.new()
		layer.name = "LiquidGlassLayer"
		layer.anchor_right = 1.0
		layer.anchor_bottom = 1.0
		layer.color = Color(1, 1, 1, 1)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.show_behind_parent = true
		layer.z_index = 0
		add_child(layer)
		move_child(layer, 0)
	var mat: ShaderMaterial = layer.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = preload("res://src/ui/LiquidGlassButton.gdshader")
		layer.material = mat
	_apply_shader_profile(mat, tint, edge_highlight, 1.0, 1.0)

func _sync_glass_state() -> void:
	var layer: ColorRect = get_node_or_null("LiquidGlassLayer") as ColorRect
	if layer == null:
		return
	var mat: ShaderMaterial = layer.material as ShaderMaterial
	if mat == null:
		return
	var target_tint: Color = tint
	var target_edge: Color = edge_highlight
	var blur_mul: float = 1.0
	var warp_mul: float = 1.0
	if disabled:
		target_tint = Color(0.72, 0.76, 0.88, 0.2)
		target_edge = Color(0.86, 0.9, 0.98, 0.22)
		blur_mul = 0.9
		warp_mul = 0.75
	elif button_pressed:
		target_tint = tint.lightened(0.14)
		target_edge = edge_highlight.lightened(0.1)
		blur_mul = 1.08
		warp_mul = 0.86
	elif is_hovered():
		target_tint = tint.lightened(0.08)
		blur_mul = 1.05
		warp_mul = 1.08
	_apply_shader_profile(mat, target_tint, target_edge, blur_mul, warp_mul)

func _apply_shader_profile(mat: ShaderMaterial, target_tint: Color, target_edge: Color, blur_mul: float, warp_mul: float) -> void:
	mat.set_shader_parameter("tint", target_tint)
	mat.set_shader_parameter("edge_highlight", target_edge)
	mat.set_shader_parameter("blur", blur * blur_mul)
	mat.set_shader_parameter("warp_intensity", warp_intensity * warp_mul)
	mat.set_shader_parameter("strength_x", strength_x)
	mat.set_shader_parameter("strength_y", strength_y)
	mat.set_shader_parameter("offset_x", offset_x)
	mat.set_shader_parameter("offset_y", offset_y)
	mat.set_shader_parameter("corner_radius", corner_radius)
	mat.set_shader_parameter("edge_smoothness", edge_smoothness)
	mat.set_shader_parameter("edge_width", edge_width)
	mat.set_shader_parameter("chromatic_strength", chromatic_strength)

func _on_button_down() -> void:
	_animate_scale(_base_scale * Vector2(0.98, 0.98), 0.08)

func _on_button_up() -> void:
	_animate_scale(_base_scale, 0.12)

func _animate_scale(target: Vector2, duration: float) -> void:
	if is_instance_valid(_press_tween):
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(self, "scale", target, duration)
