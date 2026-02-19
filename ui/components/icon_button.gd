extends Button

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

@onready var _icon_rect: TextureRect = $Center/Icon

func _ready() -> void:
	text = ""
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	_apply_styles()
	_apply_icon()
	tooltip_text = tooltip_text_override
	accessibility_name = accessibility_name_override
	mouse_entered.connect(_sync_icon_state)
	mouse_exited.connect(_sync_icon_state)
	button_down.connect(_sync_icon_state)
	button_up.connect(_sync_icon_state)
	_sync_icon_state()

func _apply_styles() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.16, 0.32, 0.44)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.9, 0.96, 1.0, 0.58)
	normal.corner_radius_top_left = 24
	normal.corner_radius_top_right = 24
	normal.corner_radius_bottom_right = 24
	normal.corner_radius_bottom_left = 24
	normal.anti_aliasing = true
	normal.anti_aliasing_size = 1.2

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.14, 0.21, 0.39, 0.58)
	hover.border_color = Color(0.95, 0.99, 1.0, 0.76)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.08, 0.13, 0.27, 0.62)
	pressed.border_color = Color(0.82, 0.9, 1.0, 0.66)

	var disabled_style: StyleBoxFlat = normal.duplicate()
	disabled_style.bg_color = Color(0.14, 0.18, 0.28, 0.24)
	disabled_style.border_color = Color(0.78, 0.86, 0.95, 0.35)

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("focus", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("disabled", disabled_style)

func _apply_icon() -> void:
	if _icon_rect == null:
		return
	_icon_rect.texture = icon_texture

func _sync_icon_state() -> void:
	if _icon_rect == null:
		return
	if disabled:
		_icon_rect.modulate = Color(1.0, 1.0, 1.0, 0.46)
	elif button_pressed:
		_icon_rect.modulate = Color(0.86, 0.92, 1.0, 1.0)
	elif is_hovered():
		_icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		_icon_rect.modulate = Color(0.94, 0.97, 1.0, 1.0)
