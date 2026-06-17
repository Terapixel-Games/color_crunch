extends RefCounted
class_name ArcadeTutorialTemplate

const DEFAULT_TEMPLATE := {
	"panel_margin": Vector2(28.0, 24.0),
	"panel_min_width": 340.0,
	"panel_max_width": 700.0,
	"panel_min_height": 216.0,
	"panel_screen_margin": 18.0,
	"title_font_size": 28.0,
	"message_font_size": 22.0,
	"button_font_size": 16.0,
	"secondary_button_font_size": 15.0,
	"title_font_weight": 700,
	"message_font_weight": 400,
	"button_font_weight": 700,
	"secondary_button_font_weight": 600,
	"button_height": 56.0,
	"primary_button_width": 136.0,
	"secondary_button_width": 166.0,
	"highlight_growth": 12.0,
	"title_message_gap": 18.0,
	"message_button_gap": 24.0,
	"message_line_spacing": 7.0,
}

static func merged_template(overrides: Dictionary = {}) -> Dictionary:
	var template := DEFAULT_TEMPLATE.duplicate(true)
	for key in overrides.keys():
		template[key] = overrides[key]
	return template

static func style_panel(panel: Panel, template: Dictionary = {}) -> void:
	if panel == null:
		return
	template = merged_template(template)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.88, 0.98, 1.0, 0.92)
	style.border_color = Color(0.26, 0.82, 1.0, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.0, 0.18, 0.34, 0.24)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", style)

static func style_label(label: Label, is_title: bool, template: Dictionary = {}) -> void:
	if label == null:
		return
	template = merged_template(template)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not is_title:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.add_theme_constant_override("line_spacing", _font_px(float(template["message_line_spacing"])))
	label.add_theme_font_override("font", _font_for_role(not is_title, int(template["message_font_weight"] if not is_title else template["title_font_weight"])))
	label.add_theme_font_size_override("font_size", _font_px(float(template["title_font_size"] if is_title else template["message_font_size"])))
	label.add_theme_color_override("font_color", Color(0.05, 0.12, 0.22, 1.0) if is_title else Color(0.08, 0.18, 0.30, 0.98))

static func style_button(button: Button, primary: bool, template: Dictionary = {}) -> void:
	if button == null:
		return
	template = merged_template(template)
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = false
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = Vector2(
		float(template["primary_button_width"] if primary else template["secondary_button_width"]),
		float(template["button_height"])
	)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END if primary else Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_override("font", _font_for_role(false, int(template["button_font_weight"] if primary else template["secondary_button_font_weight"])))
	button.add_theme_font_size_override("font_size", _font_px(float(template["button_font_size"] if primary else template["secondary_button_font_size"])))
	button.add_theme_color_override("font_color", Color(0.03, 0.09, 0.14, 1.0) if primary else Color(0.06, 0.18, 0.28, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.01, 0.06, 0.10, 1.0) if primary else Color(0.02, 0.12, 0.20, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(
		Color(0.56, 0.95, 0.86, 0.96) if primary else Color(0.90, 0.97, 1.0, 0.72),
		Color(0.18, 0.76, 0.96, 0.84) if primary else Color(0.38, 0.78, 0.96, 0.48)
	))
	button.add_theme_stylebox_override("hover", _button_style(
		Color(0.70, 1.0, 0.90, 1.0) if primary else Color(0.82, 0.95, 1.0, 0.88),
		Color(0.12, 0.90, 1.0, 0.94) if primary else Color(0.18, 0.80, 1.0, 0.76)
	))
	button.add_theme_stylebox_override("pressed", _button_style(
		Color(0.40, 0.86, 0.76, 1.0) if primary else Color(0.72, 0.88, 0.96, 0.9),
		Color(0.06, 0.60, 0.82, 0.95)
	))

static func apply_margins(margin: MarginContainer, template: Dictionary = {}) -> void:
	if margin == null:
		return
	template = merged_template(template)
	var panel_margin: Vector2 = template["panel_margin"]
	margin.add_theme_constant_override("margin_left", int(round(panel_margin.x)))
	margin.add_theme_constant_override("margin_top", int(round(panel_margin.y)))
	margin.add_theme_constant_override("margin_right", int(round(panel_margin.x)))
	margin.add_theme_constant_override("margin_bottom", int(round(panel_margin.y)))

static func calculate_text_height(message: String, panel_width: float, base_height: float, view_size: Vector2, top_limit: float, template: Dictionary = {}) -> float:
	template = merged_template(template)
	var panel_margin: Vector2 = template["panel_margin"]
	var inner_width: float = max(180.0, panel_width - (panel_margin.x * 2.0))
	var message_size: float = float(_font_px(float(template["message_font_size"])))
	var chars_per_line: int = max(20, int(floor(inner_width / max(8.0, message_size * 0.52))))
	var line_count: int = 0
	for line in message.split("\n"):
		line_count += max(1, int(ceil(float(line.length()) / float(chars_per_line))))
	line_count = max(1, line_count)
	var title_height: float = float(_font_px(float(template["title_font_size"]) + 6.0))
	var message_line_height: float = float(_font_px(float(template["message_font_size"]) + float(template["message_line_spacing"]) + 4.0))
	var message_height: float = float(line_count) * message_line_height
	var required_height: float = (
		(panel_margin.y * 2.0)
		+ title_height
		+ float(template["title_message_gap"])
		+ message_height
		+ float(template["message_button_gap"])
		+ float(template["button_height"])
	)
	var max_height: float = max(float(template["panel_min_height"]), view_size.y - top_limit - (float(template["panel_screen_margin"]) * 2.0))
	return clamp(max(base_height, required_height), float(template["panel_min_height"]), max_height)

static func layout_panel(context: Dictionary, template: Dictionary = {}) -> Dictionary:
	template = merged_template(template)
	var view_size: Vector2 = context.get("view_size", Vector2(1080, 1920))
	var board_rect: Rect2 = context.get("board_rect", Rect2())
	var top_limit: float = float(context.get("top_limit", float(template["panel_screen_margin"])))
	var bottom_limit: float = float(context.get("bottom_limit", view_size.y - float(template["panel_screen_margin"])))
	var early_step: bool = bool(context.get("early_step", false))
	var powerup_step: bool = bool(context.get("powerup_step", false))
	var message: String = str(context.get("message", ""))
	var margin: float = float(template["panel_screen_margin"])
	var is_landscape: bool = view_size.x >= view_size.y
	var panel_width: float = clamp(
		view_size.x * (0.54 if is_landscape else (0.74 if early_step else 0.66)),
		min(float(template["panel_min_width"]), view_size.x - (margin * 2.0)),
		min(float(template["panel_max_width"]), view_size.x - (margin * 2.0))
	)
	var panel_height: float = clamp(view_size.y * (0.34 if is_landscape else (0.25 if early_step else 0.22)), 216.0, 318.0)
	panel_height = calculate_text_height(message, panel_width, panel_height, view_size, top_limit, template)
	var panel_x: float = (view_size.x - panel_width) * 0.5
	var panel_y: float = view_size.y - panel_height - clamp(view_size.y * (0.08 if is_landscape else 0.16), 54.0, 170.0)
	var max_panel_y: float = max(top_limit, bottom_limit - panel_height)
	if early_step and board_rect.size != Vector2.ZERO:
		panel_y = board_rect.position.y - panel_height - clamp(view_size.y * 0.025, 16.0, 34.0)
		if panel_y < top_limit:
			panel_y = min(max_panel_y, board_rect.position.y + board_rect.size.y + 16.0)
	elif powerup_step:
		panel_y = max_panel_y
	panel_x = clamp(panel_x, margin, max(margin, view_size.x - panel_width - margin))
	panel_y = clamp(panel_y, top_limit, max_panel_y)
	return {
		"position": Vector2(panel_x, panel_y),
		"size": Vector2(panel_width, panel_height),
	}

static func style_highlight(highlight: Panel) -> void:
	if highlight == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.56, 0.95, 0.86, 0.16)
	style.border_color = Color(0.12, 0.82, 1.0, 0.96)
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 5
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.0, 0.70, 1.0, 0.34)
	style.shadow_size = 22
	highlight.add_theme_stylebox_override("panel", style)

static func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.0, 0.20, 0.32, 0.22)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style

static func _font_px(value: float) -> int:
	var typography := _typography()
	if typography and typography.has_method("px"):
		return int(typography.call("px", value))
	return int(round(value))

static func _font_for_role(is_body: bool, weight: int) -> Font:
	var typography := _typography()
	var method := "body_font" if is_body else "interface_font"
	if typography and typography.has_method(method):
		var role_font: Variant = typography.call(method, weight)
		if role_font is Font:
			return role_font as Font
	var path := "res://assets/fonts/Chivo.ttf" if is_body else "res://assets/fonts/SpaceGrotesk.ttf"
	var loaded: Resource = load(path)
	if loaded is Font:
		var variation := FontVariation.new()
		variation.base_font = loaded as Font
		variation.variation_opentype = {"wght": weight}
		return variation
	return ThemeDB.fallback_font

static func _typography() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("/root/Typography")
	return null
