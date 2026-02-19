extends ColorRect
class_name GlassPanel

@export var blur_radius := 8.0
@export var tint := Color(0.12, 0.18, 0.32, 0.52)
@export var edge := Color(0.9, 0.96, 1.0, 0.34)
@export var corner_radius := 0.16
@export var edge_smoothness := 1.2
@export var edge_width := 1.4
@export var warp_intensity := 0.18
@export var strength_x := 10.0
@export var strength_y := 10.0
@export var offset_x := 0.0
@export var offset_y := 0.0
@export var chromatic_strength := 0.5

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		# Keep tests stable on headless runners by skipping shader setup.
		material = null
		color = tint
		return
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/ui/LiquidGlassButton.gdshader")
	mat.set_shader_parameter("blur", blur_radius)
	mat.set_shader_parameter("warp_intensity", warp_intensity)
	mat.set_shader_parameter("strength_x", strength_x)
	mat.set_shader_parameter("strength_y", strength_y)
	mat.set_shader_parameter("offset_x", offset_x)
	mat.set_shader_parameter("offset_y", offset_y)
	mat.set_shader_parameter("corner_radius", corner_radius)
	mat.set_shader_parameter("edge_smoothness", edge_smoothness)
	mat.set_shader_parameter("edge_width", edge_width)
	mat.set_shader_parameter("chromatic_strength", chromatic_strength)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("edge_highlight", edge)
	material = mat
	color = tint
