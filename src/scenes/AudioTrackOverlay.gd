extends Control
class_name AudioTrackOverlay

signal track_selected(track_name: String, index: int)
signal closed

@onready var backdrop: ColorRect = $Backdrop
@onready var center: CenterContainer = $Center
@onready var panel: ColorRect = $Center/Panel
@onready var panel_margin: MarginContainer = $Center/Panel/Margin
@onready var vbox: VBoxContainer = $Center/Panel/Margin/VBox
@onready var top_inset: Control = $Center/Panel/Margin/VBox/TopInset
@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var track_selector: TrackSelectorControl = $Center/Panel/Margin/VBox/TrackSelector
@onready var close_button: Button = $Center/Panel/Margin/VBox/Close
@onready var bottom_inset: Control = $Center/Panel/Margin/VBox/BottomInset

var _closing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_mouse_filters()
	Typography.style_label(title_label, 28.0, Typography.WEIGHT_BOLD)
	Typography.style_button(close_button, 18.0, Typography.WEIGHT_SEMIBOLD)
	_layout_modal()
	call_deferred("_layout_modal")
	_refresh_panel_pivot()
	call_deferred("_refresh_panel_pivot")

func setup(track_names: Array[String], selected_index: int) -> void:
	track_selector.tracks = track_names
	if track_names.is_empty():
		track_selector.current_index = 0
	else:
		track_selector.current_index = clampi(selected_index, 0, track_names.size() - 1)
	track_selector.set_expanded(true)

func set_selected_index(selected_index: int) -> void:
	var tracks: Array[String] = track_selector.tracks
	if tracks.is_empty():
		track_selector.current_index = 0
		return
	track_selector.current_index = clampi(selected_index, 0, tracks.size() - 1)

func _on_track_selector_track_changed(track_name: String, index: int) -> void:
	emit_signal("track_selected", track_name, index)

func _on_close_pressed() -> void:
	_close()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_close()

func _close() -> void:
	if _closing:
		return
	_closing = true
	emit_signal("closed")
	queue_free()

func _apply_mouse_filters() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_layout_modal()
		_refresh_panel_pivot()

func _layout_modal() -> void:
	if panel == null or panel_margin == null or vbox == null:
		return
	if top_inset == null or title_label == null or track_selector == null or close_button == null or bottom_inset == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var outer_margin: float = clamp(min(viewport_size.x, viewport_size.y) * 0.04, 16.0, 28.0)
	var panel_width: float = clamp(viewport_size.x - (outer_margin * 2.0), 320.0, 680.0)
	var max_panel_height: float = clamp(viewport_size.y - (outer_margin * 2.0), 220.0, 420.0)
	var content_inset: float = clamp(panel_width * 0.06, 16.0, 30.0)
	var selector_height: float = clamp(viewport_size.y * 0.095, 86.0, 108.0)
	var button_height: float = clamp(viewport_size.y * 0.085, 70.0, 96.0)

	panel.custom_minimum_size.x = panel_width
	track_selector.custom_minimum_size.y = selector_height
	close_button.custom_minimum_size.y = button_height
	top_inset.custom_minimum_size.y = content_inset
	bottom_inset.custom_minimum_size.y = content_inset

	panel_margin.add_theme_constant_override("margin_left", int(round(content_inset)))
	panel_margin.add_theme_constant_override("margin_top", int(round(content_inset)))
	panel_margin.add_theme_constant_override("margin_right", int(round(content_inset)))
	panel_margin.add_theme_constant_override("margin_bottom", int(round(content_inset)))

	var content_height: float = (
		top_inset.custom_minimum_size.y
		+ title_label.get_combined_minimum_size().y
		+ track_selector.custom_minimum_size.y
		+ close_button.custom_minimum_size.y
		+ bottom_inset.custom_minimum_size.y
	)
	var gap_count: int = 4
	content_height += float(vbox.get_theme_constant("separation")) * float(gap_count)
	panel.custom_minimum_size.y = min(max_panel_height, max(240.0, content_height + (content_inset * 2.0)))

func _refresh_panel_pivot() -> void:
	if panel == null:
		return
	if panel.size.x <= 0.0 or panel.size.y <= 0.0:
		return
	panel.pivot_offset = panel.size * 0.5
