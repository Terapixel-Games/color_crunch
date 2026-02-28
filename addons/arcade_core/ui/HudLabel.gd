extends Label
class_name HudLabel

@export var glow_color := Color(0.0, 0.92, 1.0, 0.50)
@export var glow_size := 4

func _ready() -> void:
    add_theme_color_override("font_color", Color(0.93, 0.97, 1.0, 0.98))
    add_theme_color_override("font_outline_color", glow_color)
    add_theme_constant_override("outline_size", glow_size)