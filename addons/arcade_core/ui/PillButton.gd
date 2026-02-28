extends Button
class_name PillButton

@export var tint: Color = Color(0.95, 0.97, 1.0, 0.20)
@export var edge_highlight: Color = Color(1.0, 1.0, 1.0, 0.44)
@export var blur: float = 2.8
@export var warp_intensity: float = 0.24
@export var corner_radius: float = 0.48

var _press_tween: Tween
var _base_scale := Vector2.ONE

func _ready() -> void:
    clip_contents = true
    focus_mode = Control.FOCUS_NONE
    _refresh_center_pivot()
    call_deferred("_refresh_center_pivot")
    _base_scale = scale
    _apply_style_overrides()
    _ensure_glass_layer()
    button_down.connect(_on_button_down)
    button_up.connect(_on_button_up)
    mouse_entered.connect(_sync_glass_state)
    mouse_exited.connect(_sync_glass_state)
    toggled.connect(_sync_glass_state)
    _sync_glass_state()

func _process(_delta: float) -> void:
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
    normal.bg_color = Color(0.08, 0.12, 0.22, 0.35)
    normal.border_width_left = 1
    normal.border_width_top = 1
    normal.border_width_right = 1
    normal.border_width_bottom = 1
    normal.border_color = Color(0.88, 0.95, 1.0, 0.55)
    normal.corner_radius_top_left = 999
    normal.corner_radius_top_right = 999
    normal.corner_radius_bottom_left = 999
    normal.corner_radius_bottom_right = 999

    var hover := normal.duplicate()
    hover.bg_color = Color(0.10, 0.15, 0.27, 0.46)
    hover.border_color = Color(0.95, 0.99, 1.0, 0.72)

    var pressed := normal.duplicate()
    pressed.bg_color = Color(0.07, 0.10, 0.20, 0.58)

    add_theme_stylebox_override("normal", normal)
    add_theme_stylebox_override("hover", hover)
    add_theme_stylebox_override("pressed", pressed)
    add_theme_stylebox_override("focus", normal)

    add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 1.0))
    add_theme_color_override("font_pressed_color", Color(0.98, 0.99, 1.0, 1.0))
    add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
    add_theme_color_override("font_outline_color", Color(0.03, 0.06, 0.12, 0.9))
    add_theme_constant_override("outline_size", 2)

func _ensure_glass_layer() -> void:
    var layer := get_node_or_null("LiquidGlassLayer") as ColorRect
    if layer == null:
        layer = ColorRect.new()
        layer.name = "LiquidGlassLayer"
        layer.anchor_right = 1.0
        layer.anchor_bottom = 1.0
        layer.color = Color.WHITE
        layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        layer.show_behind_parent = true
        add_child(layer)
        move_child(layer, 0)

    var mat := ShaderMaterial.new()
    mat.shader = preload("res://addons/arcade_core/ui/LiquidGlass.gdshader")
    layer.material = mat

func _sync_glass_state() -> void:
    var layer := get_node_or_null("LiquidGlassLayer") as ColorRect
    if layer == null:
        return
    var mat := layer.material as ShaderMaterial
    if mat == null:
        return

    var target_tint := tint
    var target_edge := edge_highlight
    var blur_mul := 1.0
    var warp_mul := 1.0

    if disabled:
        target_tint = Color(0.72, 0.76, 0.88, 0.18)
        target_edge = Color(0.86, 0.90, 0.98, 0.24)
        blur_mul = 0.9
        warp_mul = 0.8
    elif button_pressed:
        target_tint = tint.lightened(0.12)
        target_edge = edge_highlight.lightened(0.08)
        blur_mul = 1.08
        warp_mul = 0.86
    elif is_hovered():
        target_tint = tint.lightened(0.06)
        blur_mul = 1.04
        warp_mul = 1.05

    mat.set_shader_parameter("tint", target_tint)
    mat.set_shader_parameter("edge_highlight", target_edge)
    mat.set_shader_parameter("blur", blur * blur_mul)
    mat.set_shader_parameter("warp_intensity", warp_intensity * warp_mul)
    mat.set_shader_parameter("corner_radius", corner_radius)

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
