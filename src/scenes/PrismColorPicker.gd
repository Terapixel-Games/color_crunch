extends Control
class_name PrismColorPicker

signal color_selected(level: int)
signal closed

const MODAL_LAYER_Z_INDEX := 1000

var _choices: Array = []
var _closing: bool = false
var _backdrop: ColorRect
var _center: CenterContainer
var _panel: Panel
var _content_margin: MarginContainer
var _box: VBoxContainer
var _top_inset: Control
var _title_label: Label
var _message_label: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _buttons_row: HBoxContainer
var _cancel_button: Button
var _close_button: Button
var _bottom_inset: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	z_index = MODAL_LAYER_Z_INDEX
	z_as_relative = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process_unhandled_input(true)
	_build_tree()
	_apply_mouse_filters()
	_style_controls()
	_refresh_choices()
	_layout_modal()
	call_deferred("_layout_modal")

func configure(choices: Array) -> void:
	_choices = choices.duplicate(true)
	if _grid:
		_refresh_choices()
		_layout_modal()

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_style_controls()
		_layout_modal()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _build_tree() -> void:
	if _panel != null:
		return

	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.03, 0.03, 0.12, 0.46)
	_backdrop.gui_input.connect(Callable(self, "_on_backdrop_gui_input"))
	add_child(_backdrop)

	_center = CenterContainer.new()
	_center.name = "Center"
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_center)

	_panel = Panel.new()
	_panel.name = "Panel"
	_center.add_child(_panel)

	_close_button = Button.new()
	_close_button.name = "Close"
	_close_button.text = "X"
	_close_button.pressed.connect(Callable(self, "_on_close_pressed"))
	_panel.add_child(_close_button)

	_content_margin = MarginContainer.new()
	_content_margin.name = "ContentMargin"
	_content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_content_margin)

	_box = VBoxContainer.new()
	_box.name = "VBox"
	_box.add_theme_constant_override("separation", 14)
	_content_margin.add_child(_box)

	_top_inset = Control.new()
	_top_inset.name = "TopInset"
	_box.add_child(_top_inset)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "Choose Prism Color"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_title_label)

	_message_label = Label.new()
	_message_label.name = "Message"
	_message_label.text = "Pick the color tier Prism should clear."
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_message_label)

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_scroll.add_child(_grid)

	_buttons_row = HBoxContainer.new()
	_buttons_row.name = "Buttons"
	_buttons_row.alignment = BoxContainer.ALIGNMENT_END
	_buttons_row.add_theme_constant_override("separation", 12)
	_box.add_child(_buttons_row)

	_cancel_button = Button.new()
	_cancel_button.name = "Cancel"
	_cancel_button.text = "Close"
	_cancel_button.pressed.connect(Callable(self, "_on_close_pressed"))
	_buttons_row.add_child(_cancel_button)

	_bottom_inset = Control.new()
	_bottom_inset.name = "BottomInset"
	_box.add_child(_bottom_inset)

func _apply_mouse_filters() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	if _backdrop:
		_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	if _center:
		_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _panel:
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _content_margin:
		_content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _box:
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _scroll:
		_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _grid:
		_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _buttons_row:
		_buttons_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _cancel_button:
		_cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if _close_button:
		_close_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _style_controls() -> void:
	if _panel:
		_panel.add_theme_stylebox_override("panel", _panel_style())
	if _title_label:
		_title_label.clip_text = false
		_title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		_title_label.add_theme_font_override("font", Typography.interface_font(Typography.WEIGHT_BOLD))
		_title_label.add_theme_font_size_override("font_size", Typography.px(28.0))
		_title_label.add_theme_color_override("font_color", Color(0.04, 0.10, 0.18, 1.0))
	if _message_label:
		_message_label.clip_text = false
		_message_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		_message_label.add_theme_font_override("font", Typography.body_font(Typography.WEIGHT_MEDIUM))
		_message_label.add_theme_font_size_override("font_size", Typography.px(17.0))
		_message_label.add_theme_color_override("font_color", Color(0.08, 0.17, 0.28, 0.98))
		_message_label.add_theme_constant_override("line_spacing", Typography.px(4.0))
	if _close_button:
		_style_close_button(_close_button)
	if _cancel_button:
		_style_action_button(_cancel_button)

func _refresh_choices() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		child.queue_free()
	for choice in _choices:
		var level: int = int(choice.get("level", 0))
		if level <= 0:
			continue
		var button := Button.new()
		button.name = "Level%d" % level
		button.text = "%s\nx%d" % [str(choice.get("label", "COLOR")), int(choice.get("count", 0))]
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		button.set("text_overrun_behavior", TextServer.OVERRUN_NO_TRIMMING)
		var tile_color: Color = choice.get("color", Color(0.72, 0.96, 1.0, 0.96)) as Color
		var font_color: Color = choice.get("font_color", Color(0.04, 0.10, 0.18, 1.0)) as Color
		_style_choice_button(button, tile_color, font_color)
		button.pressed.connect(Callable(self, "_on_choice_pressed").bind(level))
		_grid.add_child(button)
	_apply_mouse_filters()

func _layout_modal() -> void:
	_layout_modal_for_size(get_viewport_rect().size)

func _layout_modal_for_size(viewport_size: Vector2) -> void:
	if _panel == null or _content_margin == null or _grid == null:
		return
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1080.0, 1920.0)

	var outer_margin: float = clamp(min(viewport_size.x, viewport_size.y) * 0.045, 16.0, 36.0)
	var max_panel_width: float = max(280.0, viewport_size.x - (outer_margin * 2.0))
	var panel_width: float = clamp(viewport_size.x * (0.50 if viewport_size.x > viewport_size.y else 0.88), min(320.0, max_panel_width), min(760.0, max_panel_width))
	var max_panel_height: float = max(260.0, viewport_size.y - (outer_margin * 2.0))
	var inset: float = clamp(panel_width * 0.055, 18.0, 30.0)
	var close_size: float = clamp(panel_width * 0.078, 38.0, 50.0)
	var close_reserve: float = close_size + 16.0
	var is_wide: bool = viewport_size.x >= viewport_size.y * 1.15
	var columns: int = 4 if is_wide else 2
	if viewport_size.x < 430.0:
		columns = 1
	columns = clampi(columns, 1, max(1, min(4, _choices.size())))
	_grid.columns = columns

	var choice_height: float = clamp(viewport_size.y * (0.105 if not is_wide else 0.13), 76.0, 110.0)
	for child in _grid.get_children():
		var control := child as Control
		if control:
			control.custom_minimum_size = Vector2(0.0, choice_height)
			control.pivot_offset = control.size * 0.5

	var row_count: int = max(1, int(ceil(float(max(1, _choices.size())) / float(columns))))
	var grid_gap: float = float(_grid.get_theme_constant("v_separation"))
	var full_grid_height: float = (float(row_count) * choice_height) + (float(max(0, row_count - 1)) * grid_gap)
	var title_height: float = _estimate_wrapped_height(_title_label.text, Typography.px(28.0), panel_width - inset - close_reserve, 0.55, 4.0, 1)
	var message_height: float = _estimate_wrapped_height(_message_label.text, Typography.px(17.0), panel_width - (inset * 2.0), 0.53, float(Typography.px(4.0)), 1)
	_title_label.custom_minimum_size = Vector2(max(120.0, panel_width - inset - close_reserve), title_height)
	_message_label.custom_minimum_size = Vector2(max(120.0, panel_width - (inset * 2.0)), message_height)
	_cancel_button.custom_minimum_size = Vector2(clamp(panel_width * 0.32, 142.0, 190.0), clamp(viewport_size.y * 0.064, 56.0, 72.0))
	_top_inset.custom_minimum_size.y = max(4.0, inset * 0.16)
	_bottom_inset.custom_minimum_size.y = max(4.0, inset * 0.16)

	var separation: float = float(_box.get_theme_constant("separation"))
	var fixed_height: float = (
		_top_inset.custom_minimum_size.y
		+ title_height
		+ message_height
		+ _cancel_button.custom_minimum_size.y
		+ _bottom_inset.custom_minimum_size.y
		+ (separation * 5.0)
		+ (inset * 2.0)
	)
	var scroll_height: float = clamp(full_grid_height, min(choice_height, max_panel_height * 0.22), max(110.0, max_panel_height - fixed_height))
	_scroll.custom_minimum_size = Vector2(max(120.0, panel_width - (inset * 2.0)), scroll_height)
	_panel.custom_minimum_size = Vector2(panel_width, min(max_panel_height, fixed_height + scroll_height))

	_content_margin.add_theme_constant_override("margin_left", int(round(inset)))
	_content_margin.add_theme_constant_override("margin_top", int(round(inset)))
	_content_margin.add_theme_constant_override("margin_right", int(round(inset)))
	_content_margin.add_theme_constant_override("margin_bottom", int(round(inset)))
	_close_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_close_button.position = Vector2(panel_width - close_size - 12.0, 12.0)
	_close_button.size = Vector2(close_size, close_size)
	_close_button.custom_minimum_size = Vector2(close_size, close_size)
	_close_button.pivot_offset = _close_button.size * 0.5
	_panel.pivot_offset = _panel.custom_minimum_size * 0.5

func _estimate_wrapped_height(text: String, font_size: int, width: float, width_factor: float, line_spacing: float, min_lines: int) -> float:
	var chars_per_line: int = max(8, int(floor(width / max(7.0, float(font_size) * width_factor))))
	var lines: int = 0
	for line in text.split("\n"):
		lines += max(1, int(ceil(float(line.length()) / float(chars_per_line))))
	lines = max(min_lines, lines)
	return float(lines) * (float(font_size) + line_spacing + 4.0)

func _on_backdrop_gui_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touch: bool = event is InputEventScreenTouch and event.pressed
	if click or touch:
		_close()

func _on_close_pressed() -> void:
	_close()

func _on_choice_pressed(level: int) -> void:
	if _closing:
		return
	color_selected.emit(level)
	_close()

func _close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	queue_free()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.90, 0.98, 1.0, 0.93)
	style.border_color = Color(0.22, 0.82, 1.0, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(0.0, 0.12, 0.32, 0.28)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	return style

func _style_choice_button(button: Button, fill: Color, font_color: Color) -> void:
	var normal_fill := Color(fill.r, fill.g, fill.b, clamp(fill.a + 0.08, 0.88, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(normal_fill, Color(1.0, 1.0, 1.0, 0.52), 14))
	button.add_theme_stylebox_override("hover", _button_style(normal_fill.lightened(0.08), Color(0.12, 0.90, 1.0, 0.88), 14))
	button.add_theme_stylebox_override("pressed", _button_style(normal_fill.darkened(0.08), Color(0.04, 0.56, 0.80, 0.92), 14))
	button.add_theme_font_override("font", Typography.interface_font(Typography.WEIGHT_BOLD))
	button.add_theme_font_size_override("font_size", Typography.px(17.0))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_outline_color", Color(0.96, 1.0, 1.0, 0.40))
	button.add_theme_constant_override("outline_size", 1)

func _style_action_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = false
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.set("text_overrun_behavior", TextServer.OVERRUN_NO_TRIMMING)
	button.add_theme_font_override("font", Typography.interface_font(Typography.WEIGHT_SEMIBOLD))
	button.add_theme_font_size_override("font_size", Typography.px(16.0))
	button.add_theme_color_override("font_color", Color(0.05, 0.14, 0.22, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.02, 0.10, 0.18, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.02, 0.10, 0.18, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.90, 0.97, 1.0, 0.76), Color(0.28, 0.76, 0.96, 0.58), 14))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.78, 0.95, 1.0, 0.90), Color(0.12, 0.82, 1.0, 0.82), 14))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.64, 0.86, 0.94, 0.92), Color(0.08, 0.58, 0.80, 0.88), 14))

func _style_close_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = false
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.set("text_overrun_behavior", TextServer.OVERRUN_NO_TRIMMING)
	button.add_theme_font_override("font", Typography.interface_font(Typography.WEIGHT_BOLD))
	button.add_theme_font_size_override("font_size", Typography.px(14.0))
	button.add_theme_color_override("font_color", Color(0.06, 0.16, 0.24, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.02, 0.10, 0.18, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.82, 0.95, 1.0, 0.72), Color(0.20, 0.78, 1.0, 0.62), 100))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.70, 1.0, 0.90, 0.94), Color(0.08, 0.86, 1.0, 0.90), 100))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.55, 0.86, 0.82, 0.98), Color(0.04, 0.58, 0.74, 0.94), 100))

func _button_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.16, 0.30, 0.20)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style
