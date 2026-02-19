extends Control
class_name TrackSelectorControl

signal track_changed(track_name: String, index: int)
signal expanded_changed(is_expanded: bool)

@export var tracks: Array[String] = []:
	set(value):
		_set_tracks(value)
	get:
		return _tracks

@export var current_index: int = 0:
	set(value):
		_set_current_index(value, false)
	get:
		return _current_index

@export var collapsed_text: String = "Track":
	set(value):
		_collapsed_text = value
		_refresh_track_text()
	get:
		return _collapsed_text

@export var marquee_speed_px_per_sec: float = 60.0:
	set(value):
		_marquee_speed_px_per_sec = max(1.0, value)
	get:
		return _marquee_speed_px_per_sec

@export var marquee_gap_px: float = 40.0:
	set(value):
		_marquee_gap_px = max(0.0, value)
		_queue_recompute_marquee()
	get:
		return _marquee_gap_px

var _tracks: Array[String] = []
var _current_index: int = 0
var _collapsed_text: String = "Track"
var _marquee_speed_px_per_sec: float = 60.0
var _marquee_gap_px: float = 40.0
var _is_expanded: bool = false
var _marquee_active: bool = false
var _marquee_cycle_width: float = 0.0
var _marquee_y: float = 0.0
var _marquee_recompute_queued: bool = false
var _is_ready: bool = false

@onready var _collapsed_pill: Button = $VBox/CollapsedPill
@onready var _expanded_pill: PanelContainer = $VBox/ExpandedPill
@onready var _left_arrow_button: Button = $VBox/ExpandedPill/ExpandedRow/LeftArrowButton
@onready var _name_toggle_button: Button = $VBox/ExpandedPill/ExpandedRow/NameToggleButton
@onready var _name_clip: Control = $VBox/ExpandedPill/ExpandedRow/NameToggleButton/NameClip
@onready var _marquee_root: Control = $VBox/ExpandedPill/ExpandedRow/NameToggleButton/NameClip/MarqueeRoot
@onready var _marquee_row: HBoxContainer = $VBox/ExpandedPill/ExpandedRow/NameToggleButton/NameClip/MarqueeRoot/MarqueeRow
@onready var _name_label_a: Label = $VBox/ExpandedPill/ExpandedRow/NameToggleButton/NameClip/MarqueeRoot/MarqueeRow/NameLabelA
@onready var _gap: Control = $VBox/ExpandedPill/ExpandedRow/NameToggleButton/NameClip/MarqueeRoot/MarqueeRow/Gap
@onready var _name_label_b: Label = $VBox/ExpandedPill/ExpandedRow/NameToggleButton/NameClip/MarqueeRoot/MarqueeRow/NameLabelB
@onready var _right_arrow_button: Button = $VBox/ExpandedPill/ExpandedRow/RightArrowButton

func _ready() -> void:
	_apply_styles()
	_collapsed_pill.pressed.connect(_on_collapsed_pill_pressed)
	_name_toggle_button.pressed.connect(_on_name_toggle_pressed)
	_left_arrow_button.pressed.connect(_on_left_arrow_pressed)
	_right_arrow_button.pressed.connect(_on_right_arrow_pressed)
	_name_clip.resized.connect(_queue_recompute_marquee)
	_is_ready = true
	_refresh_all()
	call_deferred("_queue_recompute_marquee")

func _process(delta: float) -> void:
	if not _marquee_active:
		return
	_marquee_root.position.x -= _marquee_speed_px_per_sec * delta
	if -_marquee_root.position.x >= _marquee_cycle_width:
		_marquee_root.position.x = 0.0
	_marquee_root.position.y = _marquee_y

func _set_tracks(value: Array[String]) -> void:
	_tracks = value.duplicate()
	_set_current_index(_current_index, false)
	_refresh_all()

func _set_current_index(value: int, emit_change: bool) -> void:
	if _tracks.is_empty():
		_current_index = 0
	else:
		_current_index = clampi(value, 0, _tracks.size() - 1)
	_refresh_track_text()
	if emit_change and not _tracks.is_empty():
		emit_signal("track_changed", _tracks[_current_index], _current_index)

func set_expanded(expanded: bool) -> void:
	if _is_expanded == expanded:
		return
	_is_expanded = expanded
	_collapsed_pill.visible = not _is_expanded
	_expanded_pill.visible = _is_expanded
	emit_signal("expanded_changed", _is_expanded)
	_queue_recompute_marquee()

func is_expanded() -> bool:
	return _is_expanded

func cycle_track(step: int) -> void:
	if _tracks.is_empty():
		return
	_set_current_index(wrapped_index(_current_index, step, _tracks.size()), true)

func is_marquee_active() -> bool:
	return _marquee_active

func current_track_name() -> String:
	if _tracks.is_empty():
		return "Off"
	return _tracks[_current_index]

static func wrapped_index(index: int, step: int, count: int) -> int:
	if count <= 0:
		return 0
	return posmod(index + step, count)

static func should_run_marquee(is_expanded: bool, label_width: float, available_width: float, track_count: int) -> bool:
	return is_expanded and track_count > 0 and label_width > (available_width + 0.5)

func _on_collapsed_pill_pressed() -> void:
	set_expanded(not _is_expanded)

func _on_name_toggle_pressed() -> void:
	set_expanded(false)

func _on_left_arrow_pressed() -> void:
	cycle_track(-1)

func _on_right_arrow_pressed() -> void:
	cycle_track(1)

func _refresh_all() -> void:
	if not _is_ready:
		return
	_refresh_track_buttons()
	_refresh_track_text()
	set_expanded(_is_expanded)
	_queue_recompute_marquee()

func _refresh_track_buttons() -> void:
	var can_cycle: bool = _tracks.size() > 1
	_left_arrow_button.disabled = not can_cycle
	_right_arrow_button.disabled = not can_cycle

func _refresh_track_text() -> void:
	if not _is_ready:
		return
	var name: String = current_track_name()
	_collapsed_pill.text = "%s\n%s" % [_collapsed_text, name]
	_name_label_a.text = name
	_name_label_b.text = name
	_queue_recompute_marquee()

func _queue_recompute_marquee() -> void:
	if not _is_ready or _marquee_recompute_queued:
		return
	_marquee_recompute_queued = true
	call_deferred("_recompute_marquee")

func _recompute_marquee() -> void:
	_marquee_recompute_queued = false
	if not _is_ready:
		return

	_gap.custom_minimum_size.x = _marquee_gap_px
	var label_width: float = _measure_label_width(_name_label_a)
	var available_width: float = _name_clip.size.x
	var run_marquee: bool = should_run_marquee(_is_expanded, label_width, available_width, _tracks.size())

	_name_label_b.visible = run_marquee
	_gap.visible = run_marquee
	_marquee_row.position = Vector2.ZERO
	_marquee_row.size = _marquee_row.get_combined_minimum_size()
	_marquee_y = floor((max(0.0, _name_clip.size.y - _marquee_row.size.y)) * 0.5)
	_marquee_row.position.y = _marquee_y

	if run_marquee:
		_marquee_cycle_width = label_width + _marquee_gap_px
		_marquee_root.position = Vector2(0.0, _marquee_y)
		_set_marquee_active(true)
	else:
		_set_marquee_active(false)
		_reset_marquee_position()

func _measure_label_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	if font == null:
		return label.get_combined_minimum_size().x
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func _set_marquee_active(active: bool) -> void:
	if _marquee_active == active:
		return
	_marquee_active = active
	set_process(_marquee_active)

func _reset_marquee_position() -> void:
	var row_size: Vector2 = _marquee_row.get_combined_minimum_size()
	var centered_x: float = floor(max(0.0, (_name_clip.size.x - row_size.x) * 0.5))
	_marquee_root.position = Vector2(centered_x, _marquee_y)

func _apply_styles() -> void:
	_collapsed_pill.focus_mode = Control.FOCUS_NONE
	_collapsed_pill.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collapsed_pill.custom_minimum_size.y = 92.0

	_name_toggle_button.focus_mode = Control.FOCUS_NONE
	_name_toggle_button.flat = true
	_name_toggle_button.custom_minimum_size.y = 92.0
	_left_arrow_button.focus_mode = Control.FOCUS_NONE
	_right_arrow_button.focus_mode = Control.FOCUS_NONE
	_left_arrow_button.flat = true
	_right_arrow_button.flat = true
	_left_arrow_button.custom_minimum_size = Vector2(74.0, 92.0)
	_right_arrow_button.custom_minimum_size = Vector2(74.0, 92.0)

	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color(0.1, 0.16, 0.32, 0.42)
	pill_style.border_width_left = 1
	pill_style.border_width_top = 1
	pill_style.border_width_right = 1
	pill_style.border_width_bottom = 1
	pill_style.border_color = Color(0.9, 0.96, 1.0, 0.52)
	pill_style.corner_radius_top_left = 42
	pill_style.corner_radius_top_right = 42
	pill_style.corner_radius_bottom_right = 42
	pill_style.corner_radius_bottom_left = 42
	pill_style.anti_aliasing = true
	pill_style.anti_aliasing_size = 1.2

	var pill_hover: StyleBoxFlat = pill_style.duplicate()
	pill_hover.bg_color = Color(0.14, 0.22, 0.4, 0.56)
	pill_hover.border_color = Color(0.95, 0.99, 1.0, 0.72)

	var pill_pressed: StyleBoxFlat = pill_style.duplicate()
	pill_pressed.bg_color = Color(0.08, 0.12, 0.24, 0.62)

	_collapsed_pill.add_theme_stylebox_override("normal", pill_style)
	_collapsed_pill.add_theme_stylebox_override("hover", pill_hover)
	_collapsed_pill.add_theme_stylebox_override("focus", pill_hover)
	_collapsed_pill.add_theme_stylebox_override("pressed", pill_pressed)

	_expanded_pill.add_theme_stylebox_override("panel", pill_style.duplicate())
