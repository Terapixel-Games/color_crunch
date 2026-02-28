extends ColorRect

@export var tint := Color(0.12, 0.18, 0.30, 0.48)
@export var edge := Color(0.90, 0.97, 1.0, 0.30)
@export var blur := 3.0
@export var corner_radius := 0.16

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var mat := ShaderMaterial.new()
    mat.shader = preload("res://addons/arcade_core/ui/LiquidGlass.gdshader")
    mat.set_shader_parameter("tint", tint)
    mat.set_shader_parameter("edge_highlight", edge)
    mat.set_shader_parameter("blur", blur)
    mat.set_shader_parameter("corner_radius", corner_radius)
    material = mat
    color = Color.WHITE