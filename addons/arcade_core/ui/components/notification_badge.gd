extends PanelContainer

@export var value: String = "0":
	set(next_value):
		value = next_value
		if _value_label:
			_value_label.text = value

@onready var _value_label: Label = $Value

var _t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_style()
	_value_label.text = value

func _process(delta: float) -> void:
	_t += delta
	var pulse := 1.0 + sin(_t * TAU * 0.85) * 0.05
	scale = Vector2.ONE * pulse

func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.70, 0.30, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 0.94, 0.82, 0.96)
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_right = 999
	style.corner_radius_bottom_left = 999
	style.shadow_color = Color(0.48, 0.22, 0.02, 0.34)
	style.shadow_size = 8
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.2
	add_theme_stylebox_override("panel", style)
	_value_label.add_theme_color_override("font_color", Color(0.22, 0.10, 0.02, 1.0))
	_value_label.add_theme_color_override("font_outline_color", Color(1.0, 0.94, 0.82, 0.55))
	_value_label.add_theme_constant_override("outline_size", 2)
