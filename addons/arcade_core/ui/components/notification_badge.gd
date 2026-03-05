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
	style.bg_color = Color(0.98, 0.24, 0.24, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 0.92, 0.92, 0.95)
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_right = 999
	style.corner_radius_bottom_left = 999
	style.shadow_color = Color(0.65, 0.06, 0.06, 0.45)
	style.shadow_size = 6
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.2
	add_theme_stylebox_override("panel", style)
	_value_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_value_label.add_theme_color_override("font_outline_color", Color(0.3, 0.02, 0.02, 0.95))
	_value_label.add_theme_constant_override("outline_size", 2)
