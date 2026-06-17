extends Control

signal dismissed(do_not_show_again: bool)
signal confirmed(do_not_show_again: bool)
signal canceled(do_not_show_again: bool)

const MODAL_LAYER_Z_INDEX := 1000

@onready var dim: ColorRect = $Dim
@onready var center_layer: Control = $Center
@onready var panel: Panel = $Center/Panel
@onready var close_button: Button = $Center/Panel/Close
@onready var content_margin: MarginContainer = $Center/Panel/ContentMargin
@onready var content_box: VBoxContainer = $Center/Panel/ContentMargin/VBox
@onready var title_label: Label = $Center/Panel/ContentMargin/VBox/Title
@onready var message_label: Label = $Center/Panel/ContentMargin/VBox/Message
@onready var do_not_show_toggle: CheckButton = $Center/Panel/ContentMargin/VBox/DoNotShow
@onready var buttons_row: HBoxContainer = $Center/Panel/ContentMargin/VBox/Buttons
@onready var cancel_button: Button = $Center/Panel/ContentMargin/VBox/Buttons/Cancel
@onready var confirm_button: Button = $Center/Panel/ContentMargin/VBox/Buttons/Confirm

var _pending_config: Dictionary = {}
var _target_rect: Rect2 = Rect2()
var _avoid_rect: Rect2 = Rect2()
var _bottom_offset: float = 112.0
var _target_highlight: Panel
var _pointer: Polygon2D
var _entry_tween: Tween
var _target_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	z_index = MODAL_LAYER_Z_INDEX
	z_as_relative = false
	set_process_unhandled_input(true)
	_build_effect_nodes()
	if not _pending_config.is_empty():
		_apply_config(_pending_config)
	_style_controls()
	_layout_tip()
	_play_entry_motion()

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_style_controls()
		_layout_tip()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_cancel_and_close()
		get_viewport().set_input_as_handled()

func configure(config: Dictionary) -> void:
	_pending_config = config.duplicate(true)
	_apply_config(_pending_config)

func _apply_config(config: Dictionary) -> void:
	_bottom_offset = float(config.get("bottom_offset", _bottom_offset))
	_target_rect = config.get("target_rect", Rect2()) as Rect2
	_avoid_rect = config.get("avoid_rect", Rect2()) as Rect2
	if title_label:
		title_label.text = str(config.get("title", "Tip"))
	if message_label:
		message_label.text = str(config.get("message", ""))
	if confirm_button:
		confirm_button.text = str(config.get("confirm_text", "Got it"))
	if cancel_button:
		cancel_button.text = str(config.get("cancel_text", "Cancel"))
		cancel_button.visible = bool(config.get("show_cancel", false))
	if do_not_show_toggle:
		do_not_show_toggle.text = str(config.get("checkbox_text", "Don't show this again"))
		do_not_show_toggle.visible = bool(config.get("show_checkbox", true))
		do_not_show_toggle.button_pressed = false
	_layout_tip()

func _on_confirm_pressed() -> void:
	_confirm_and_close()

func _on_cancel_pressed() -> void:
	_cancel_and_close()

func _on_close_pressed() -> void:
	_cancel_and_close()

func _on_dim_gui_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touch: bool = event is InputEventScreenTouch and event.pressed
	if click or touch:
		_cancel_and_close()

func _emit_and_close() -> void:
	_confirm_and_close()

func _confirm_and_close() -> void:
	_close_with_result(true)

func _cancel_and_close() -> void:
	_close_with_result(false)

func _close_with_result(accepted: bool) -> void:
	_stop_motion()
	var do_not_show_again := false
	if do_not_show_toggle and do_not_show_toggle.visible:
		do_not_show_again = do_not_show_toggle.button_pressed
	if accepted:
		confirmed.emit(do_not_show_again)
	else:
		canceled.emit(do_not_show_again)
	dismissed.emit(do_not_show_again)
	queue_free()

func _build_effect_nodes() -> void:
	if center_layer == null:
		return
	_pointer = Polygon2D.new()
	_pointer.name = "Pointer"
	_pointer.color = Color(0.88, 0.98, 1.0, 0.96)
	center_layer.add_child(_pointer)
	_target_highlight = Panel.new()
	_target_highlight.name = "TargetHighlight"
	_target_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_target_highlight(_target_highlight)
	center_layer.add_child(_target_highlight)

func _style_controls() -> void:
	if dim:
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if center_layer:
		center_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_panel(panel)
	if close_button:
		_style_close_button(close_button)
	if content_margin:
		content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inset := 26
		content_margin.add_theme_constant_override("margin_left", inset)
		content_margin.add_theme_constant_override("margin_top", inset)
		content_margin.add_theme_constant_override("margin_right", inset)
		content_margin.add_theme_constant_override("margin_bottom", inset)
	if content_box:
		content_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_box.add_theme_constant_override("separation", 16)
	if title_label:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		title_label.add_theme_font_override("font", _font_for_role(false, 700))
		title_label.add_theme_font_size_override("font_size", _font_px(30.0))
		title_label.add_theme_color_override("font_color", Color(0.04, 0.10, 0.18, 1.0))
	if message_label:
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		message_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message_label.add_theme_font_override("font", _font_for_role(true, 420))
		message_label.add_theme_font_size_override("font_size", _font_px(21.0))
		message_label.add_theme_color_override("font_color", Color(0.08, 0.17, 0.28, 0.98))
		message_label.add_theme_constant_override("line_spacing", _font_px(7.0))
	if do_not_show_toggle:
		do_not_show_toggle.focus_mode = Control.FOCUS_NONE
		do_not_show_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
		do_not_show_toggle.clip_text = false
		do_not_show_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		do_not_show_toggle.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		do_not_show_toggle.custom_minimum_size.y = 42.0
		do_not_show_toggle.add_theme_font_size_override("font_size", _font_px(16.0))
		do_not_show_toggle.add_theme_color_override("font_color", Color(0.08, 0.18, 0.28, 1.0))
		do_not_show_toggle.add_theme_color_override("font_hover_color", Color(0.04, 0.12, 0.20, 1.0))
		do_not_show_toggle.add_theme_color_override("font_pressed_color", Color(0.04, 0.12, 0.20, 1.0))
	if buttons_row:
		buttons_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buttons_row.add_theme_constant_override("separation", 12)
		buttons_row.custom_minimum_size.y = 58.0
	if cancel_button:
		_style_button(cancel_button, false)
	if confirm_button:
		_style_button(confirm_button, true)

func _layout_tip() -> void:
	if panel == null or content_margin == null:
		return
	var view_size: Vector2 = get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = size
	if view_size == Vector2.ZERO:
		return
	var margin: float = clamp(min(view_size.x, view_size.y) * 0.032, 16.0, 34.0)
	var aspect: float = view_size.x / max(1.0, view_size.y)
	var is_wide: bool = aspect >= 1.30 and view_size.x >= 780.0
	var max_panel_width: float = max(260.0, view_size.x - (margin * 2.0))
	var min_panel_width: float = min(340.0, max_panel_width)
	var panel_width: float = clamp(view_size.x * (0.56 if is_wide else 0.84), min_panel_width, min(760.0, max_panel_width))
	var inset: int = int(round(clamp(panel_width * 0.052, 18.0, 28.0)))
	var close_size: float = clamp(panel_width * 0.082, 38.0, 48.0)
	var close_reserve: int = int(ceil(close_size + 16.0))
	var bottom_inset: int = inset + int(round(clamp(panel_width * 0.024, 12.0, 18.0)))
	if content_margin:
		content_margin.add_theme_constant_override("margin_left", inset)
		content_margin.add_theme_constant_override("margin_top", inset)
		content_margin.add_theme_constant_override("margin_right", inset + close_reserve)
		content_margin.add_theme_constant_override("margin_bottom", bottom_inset)
	var content_width: float = max(160.0, panel_width - float(inset * 2 + close_reserve))
	_prepare_wrapped_content_sizes(content_width)
	var max_panel_height: float = max(180.0, view_size.y - (margin * 2.0))
	var min_panel_height: float = min(330.0, max_panel_height)
	var panel_height: float = clamp(_required_panel_height(float(inset), float(bottom_inset)), min_panel_height, max_panel_height)
	var panel_x: float = (view_size.x - panel_width) * 0.5
	var panel_y: float = view_size.y - _bottom_offset - panel_height
	if _target_rect.size != Vector2.ZERO:
		panel_y = _target_rect.position.y - panel_height - 28.0
		if panel_y < margin:
			panel_y = _target_rect.position.y + _target_rect.size.y + 28.0
	if _avoid_rect.size != Vector2.ZERO and Rect2(Vector2(panel_x, panel_y), Vector2(panel_width, panel_height)).intersects(_avoid_rect):
		panel_y = _avoid_rect.position.y - panel_height - margin
	panel_x = clamp(panel_x, margin, max(margin, view_size.x - panel_width - margin))
	panel_y = clamp(panel_y, margin, max(margin, view_size.y - panel_height - margin))
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(panel_x, panel_y)
	panel.size = Vector2(panel_width, panel_height)
	panel.pivot_offset = panel.size * 0.5
	if close_button:
		close_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		close_button.position = Vector2(panel_width - close_size - 12.0, 12.0)
		close_button.size = Vector2(close_size, close_size)
		close_button.custom_minimum_size = Vector2(close_size, close_size)
		close_button.pivot_offset = close_button.size * 0.5
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layout_pointer()
	_layout_target_highlight()
	if confirm_button:
		confirm_button.pivot_offset = confirm_button.size * 0.5
	if cancel_button:
		cancel_button.pivot_offset = cancel_button.size * 0.5

func _prepare_wrapped_content_sizes(content_width: float) -> void:
	var title_size: int = _font_px(30.0)
	var message_size: int = _font_px(21.0)
	var line_spacing: int = _font_px(7.0)
	if title_label:
		title_label.custom_minimum_size = Vector2(content_width, _estimate_wrapped_text_height(title_label.text, title_size, content_width, 0.58, 4.0, 1))
	if message_label:
		message_label.custom_minimum_size = Vector2(content_width, _estimate_wrapped_text_height(message_label.text, message_size, content_width, 0.53, float(line_spacing), 2))
	if do_not_show_toggle:
		do_not_show_toggle.custom_minimum_size = Vector2(min(content_width, 320.0), 42.0)
	if buttons_row:
		buttons_row.custom_minimum_size = Vector2(content_width, 58.0)

func _required_panel_height(top_inset: float, bottom_inset: float) -> float:
	var separation: float = float(content_box.get_theme_constant("separation")) if content_box else 16.0
	var blocks: int = 0
	var content_height: float = 0.0
	if title_label and title_label.visible:
		blocks += 1
		content_height += title_label.custom_minimum_size.y
	if message_label and message_label.visible:
		blocks += 1
		content_height += message_label.custom_minimum_size.y
	if do_not_show_toggle and do_not_show_toggle.visible:
		blocks += 1
		content_height += max(38.0, do_not_show_toggle.custom_minimum_size.y)
	if buttons_row and buttons_row.visible:
		blocks += 1
		content_height += max(58.0, buttons_row.custom_minimum_size.y)
	content_height += separation * float(max(0, blocks - 1))
	return ceil(top_inset + bottom_inset + content_height)

func _estimate_wrapped_text_height(text: String, font_size: int, width: float, average_width_factor: float, line_spacing: float, min_lines: int) -> float:
	var chars_per_line: int = max(8, int(floor(width / max(1.0, float(font_size) * average_width_factor))))
	var lines: int = max(min_lines, int(ceil(float(max(1, text.length())) / float(chars_per_line))))
	return float(lines * font_size) + (float(max(0, lines - 1)) * line_spacing)

func _layout_pointer() -> void:
	if _pointer == null:
		return
	var has_target := _target_rect.size != Vector2.ZERO
	_pointer.visible = has_target
	if not has_target:
		return
	var panel_rect := Rect2(panel.global_position, panel.size)
	var target_center := _target_rect.get_center()
	var tip_x: float = clamp(target_center.x, panel_rect.position.x + 52.0, panel_rect.end.x - 52.0)
	if panel_rect.position.y > target_center.y:
		_pointer.polygon = PackedVector2Array([
			Vector2(tip_x - 22.0, panel_rect.position.y + 1.0),
			Vector2(tip_x + 22.0, panel_rect.position.y + 1.0),
			target_center,
		])
	else:
		_pointer.polygon = PackedVector2Array([
			Vector2(tip_x - 22.0, panel_rect.end.y - 1.0),
			Vector2(tip_x + 22.0, panel_rect.end.y - 1.0),
			target_center,
		])

func _layout_target_highlight() -> void:
	if _target_highlight == null:
		return
	var has_target := _target_rect.size != Vector2.ZERO
	_target_highlight.visible = has_target
	if not has_target:
		return
	var grown := _target_rect.grow(clamp(min(_target_rect.size.x, _target_rect.size.y) * 0.12, 7.0, 14.0))
	_target_highlight.global_position = grown.position
	_target_highlight.size = grown.size
	_target_highlight.pivot_offset = grown.size * 0.5
	if _target_tween == null:
		_target_tween = _target_highlight.create_tween()
		_target_tween.set_loops()
		_target_tween.tween_property(_target_highlight, "scale", Vector2(1.08, 1.08), 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_target_tween.tween_property(_target_highlight, "scale", Vector2.ONE, 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _play_entry_motion() -> void:
	if panel == null:
		return
	if _entry_tween:
		_entry_tween.kill()
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.96, 0.96)
	panel.modulate = Color(1, 1, 1, 0.0)
	_entry_tween = panel.create_tween()
	_entry_tween.set_parallel(true)
	_entry_tween.tween_property(panel, "scale", Vector2(1.025, 1.025), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entry_tween.tween_property(panel, "modulate:a", 1.0, 0.10)
	_entry_tween.chain().tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _stop_motion() -> void:
	if _entry_tween:
		_entry_tween.kill()
	if _target_tween:
		_target_tween.kill()
	_entry_tween = null
	_target_tween = null

func _style_panel(target: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.88, 0.98, 1.0, 0.94)
	style.border_color = Color(0.18, 0.78, 1.0, 0.88)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(0.0, 0.16, 0.28, 0.28)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	target.add_theme_stylebox_override("panel", style)

func _style_target_highlight(target: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.56, 0.95, 0.86, 0.18)
	style.border_color = Color(0.08, 0.82, 1.0, 0.95)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.0, 0.72, 1.0, 0.34)
	style.shadow_size = 20
	target.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, primary: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = false
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size.y = 56.0
	button.add_theme_font_override("font", _font_for_role(false, 700 if primary else 600))
	button.add_theme_font_size_override("font_size", _font_px(17.0 if primary else 16.0))
	button.add_theme_color_override("font_color", Color(0.03, 0.09, 0.14, 1.0) if primary else Color(0.06, 0.18, 0.28, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(
		Color(0.56, 0.95, 0.86, 0.96) if primary else Color(0.90, 0.97, 1.0, 0.72),
		Color(0.18, 0.76, 0.96, 0.84) if primary else Color(0.38, 0.78, 0.96, 0.48)
	))
	button.add_theme_stylebox_override("hover", _button_style(
		Color(0.70, 1.0, 0.90, 1.0) if primary else Color(0.82, 0.95, 1.0, 0.88),
		Color(0.12, 0.90, 1.0, 0.94)
	))
	button.add_theme_stylebox_override("pressed", _button_style(
		Color(0.40, 0.86, 0.76, 1.0) if primary else Color(0.72, 0.88, 0.96, 0.9),
		Color(0.06, 0.60, 0.82, 0.95)
	))

func _style_close_button(button: Button) -> void:
	button.text = "X"
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = false
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", _font_for_role(false, 700))
	button.add_theme_font_size_override("font_size", _font_px(17.0))
	button.add_theme_color_override("font_color", Color(0.04, 0.12, 0.20, 0.92))
	button.add_theme_color_override("font_hover_color", Color(0.02, 0.08, 0.14, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.02, 0.08, 0.14, 1.0))
	button.add_theme_stylebox_override("normal", _close_button_style(Color(0.95, 1.0, 1.0, 0.66), Color(0.20, 0.72, 0.94, 0.42)))
	button.add_theme_stylebox_override("hover", _close_button_style(Color(0.82, 0.97, 1.0, 0.94), Color(0.10, 0.86, 1.0, 0.82)))
	button.add_theme_stylebox_override("pressed", _close_button_style(Color(0.70, 0.90, 0.98, 0.96), Color(0.04, 0.62, 0.86, 0.90)))

func _close_button_style(fill: Color, border: Color) -> StyleBoxFlat:
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
	style.shadow_color = Color(0.0, 0.16, 0.28, 0.14)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
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
	style.shadow_color = Color(0.0, 0.16, 0.28, 0.18)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	return style

func _font_px(value: float) -> int:
	var typography := get_node_or_null("/root/Typography")
	if typography and typography.has_method("px"):
		return int(typography.call("px", value))
	return int(round(value))

func _font_for_role(is_body: bool, weight: int) -> Font:
	var typography := get_node_or_null("/root/Typography")
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
