extends ColorRect

const GLASS_SHADER := preload("res://addons/arcade_core/ui/LiquidGlass.gdshader")
const GLOW_SHADER := preload("res://addons/arcade_core/ui/shaders/glow.gdshader")
const UI_COLORS := preload("res://addons/arcade_core/ui/theme/UIColors.gd")

@export var panel_tint: Color = UI_COLORS.PANEL_BACKGROUND
@export var panel_edge: Color = UI_COLORS.PANEL_EDGE
@export var panel_glow: Color = UI_COLORS.GLOW_COLOR
@export var corner_radius: float = 0.12
@export var blur_radius: float = 4.8
@export var drop_shadow_alpha: float = 0.28

var _glow_layer: ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_apply_glass_material()
	_ensure_glow_layer()

func _apply_glass_material() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = GLASS_SHADER
	mat.set_shader_parameter("tint", panel_tint)
	mat.set_shader_parameter("edge_highlight", panel_edge)
	mat.set_shader_parameter("blur", blur_radius)
	mat.set_shader_parameter("corner_radius", corner_radius)
	mat.set_shader_parameter("edge_width", 1.4)
	material = mat

func _ensure_glow_layer() -> void:
	if _glow_layer != null:
		return
	_glow_layer = ColorRect.new()
	_glow_layer.name = "PanelGlow"
	_glow_layer.anchor_right = 1.0
	_glow_layer.anchor_bottom = 1.0
	_glow_layer.color = Color(1.0, 1.0, 1.0, 1.0)
	_glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_layer.show_behind_parent = true
	_glow_layer.z_index = -1
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	mat.set_shader_parameter("glow_color", panel_glow)
	mat.set_shader_parameter("intensity", 0.58)
	mat.set_shader_parameter("edge_mix", 0.92)
	_glow_layer.material = mat
	add_child(_glow_layer)
	move_child(_glow_layer, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_color = Color(0.0, 0.03, 0.12, drop_shadow_alpha)
	style.shadow_size = 14
	style.corner_radius_top_left = 26
	style.corner_radius_top_right = 26
	style.corner_radius_bottom_right = 26
	style.corner_radius_bottom_left = 26
	add_theme_stylebox_override("panel", style)
