extends Control

signal start_requested(track_id: String, track_name: String)

const FALLBACK_TRACKS := [
	{"id": "track_01", "title": "TRACK 01", "name": "Nebula Run"},
	{"id": "track_02", "title": "TRACK 02", "name": "Photon Drift"},
	{"id": "track_03", "title": "TRACK 03", "name": "Crystal Pulse"},
]

@onready var center_panel: MarginContainer = $CenterPanel
@onready var footer_hint: Label = $FooterHint
@onready var track_prev_button: Button = $CenterPanel/PanelContent/ContentVBox/TrackSelectorRow/TrackPrevButton
@onready var track_next_button: Button = $CenterPanel/PanelContent/ContentVBox/TrackSelectorRow/TrackNextButton
@onready var track_info: VBoxContainer = $CenterPanel/PanelContent/ContentVBox/TrackSelectorRow/TrackInfoHost/TrackInfo
@onready var track_title_label: Label = $CenterPanel/PanelContent/ContentVBox/TrackSelectorRow/TrackInfoHost/TrackInfo/TrackTitleLabel
@onready var track_name_label: Label = $CenterPanel/PanelContent/ContentVBox/TrackSelectorRow/TrackInfoHost/TrackInfo/TrackNameLabel
@onready var start_button: Button = $CenterPanel/PanelContent/ContentVBox/StartButton

var _track_index: int = 0
var _tracks: Array[Dictionary] = []
var _track_info_base_position: Vector2 = Vector2.ZERO
var _track_info_tween: Tween
var _intro_tween: Tween
var _start_idle_tween: Tween
var _button_tweens: Dictionary = {}
var _button_hovered: Dictionary = {}
var _button_pressed: Dictionary = {}

func _ready() -> void:
	_wire_button_signals()
	_capture_layout_bases()
	_populate_track_options()
	_apply_default_button_state()
	call_deferred("_capture_layout_bases")
	_play_intro_animation()
	_start_idle_pulse()
	resized.connect(_on_menu_resized)

func _wire_button_signals() -> void:
	track_prev_button.pressed.connect(_on_track_prev_pressed)
	track_next_button.pressed.connect(_on_track_next_pressed)
	start_button.pressed.connect(_on_start_pressed)

	for button_variant in _all_buttons():
		var button: Button = button_variant as Button
		if button == null:
			continue
		_button_hovered[button] = false
		_button_pressed[button] = false
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
		button.button_down.connect(_on_button_down.bind(button))
		button.button_up.connect(_on_button_up.bind(button))
		button.focus_entered.connect(_on_button_focus_entered.bind(button))
		button.focus_exited.connect(_on_button_focus_exited.bind(button))

func _all_buttons() -> Array:
	return [track_prev_button, track_next_button, start_button]

func _capture_layout_bases() -> void:
	_track_info_base_position = track_info.position
	center_panel.pivot_offset = center_panel.size * 0.5
	track_info.pivot_offset = track_info.size * 0.5
	for button_variant in _all_buttons():
		var button: Button = button_variant as Button
		if button == null:
			continue
		button.pivot_offset = button.size * 0.5

func _apply_default_button_state() -> void:
	for button_variant in _all_buttons():
		var button: Button = button_variant as Button
		if button == null:
			continue
		button.scale = Vector2.ONE
		button.modulate = _button_idle_color(button)

func _play_intro_animation() -> void:
	if is_instance_valid(_intro_tween):
		_intro_tween.kill()
	var target_position: Vector2 = center_panel.position
	center_panel.position = target_position + Vector2(0.0, 20.0)
	center_panel.scale = Vector2(0.98, 0.98)
	center_panel.modulate.a = 0.0
	footer_hint.modulate.a = 0.0
	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	_intro_tween.tween_property(center_panel, "position", target_position, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(center_panel, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(center_panel, "modulate:a", 1.0, 0.28)
	_intro_tween.tween_property(footer_hint, "modulate:a", 0.86, 0.26).set_delay(0.12)

func _start_idle_pulse() -> void:
	if _is_start_interacting():
		return
	if is_instance_valid(_start_idle_tween):
		_start_idle_tween.kill()
	_start_idle_tween = create_tween()
	_start_idle_tween.set_loops()
	_start_idle_tween.tween_property(start_button, "scale", Vector2(1.01, 1.01), 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_start_idle_tween.tween_property(start_button, "scale", Vector2.ONE, 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_idle_pulse(reset_scale: bool) -> void:
	if is_instance_valid(_start_idle_tween):
		_start_idle_tween.kill()
	_start_idle_tween = null
	if reset_scale and not _is_start_interacting():
		start_button.scale = Vector2.ONE

func _is_start_interacting() -> bool:
	return bool(_button_hovered.get(start_button, false)) or bool(_button_pressed.get(start_button, false))

func _on_track_prev_pressed() -> void:
	_cycle_track(-1)

func _on_track_next_pressed() -> void:
	_cycle_track(1)

func _cycle_track(step: int) -> void:
	if _tracks.is_empty():
		return
	_track_index = posmod(_track_index + step, _tracks.size())
	_apply_track_selection(str(_tracks[_track_index].get("id", "")))
	_refresh_track_info(true, step)

func _refresh_track_info(animated: bool, direction: int = 1) -> void:
	if _tracks.is_empty():
		track_title_label.text = "TRACK --"
		track_name_label.text = "No tracks available"
		return
	var selected: Dictionary = _tracks[_track_index]
	track_title_label.text = str(selected.get("title", "TRACK"))
	track_name_label.text = str(selected.get("name", "Untitled"))
	if not animated:
		track_info.position = _track_info_base_position
		track_info.modulate = Color(1, 1, 1, 1)
		track_info.scale = Vector2.ONE
		return
	if is_instance_valid(_track_info_tween):
		_track_info_tween.kill()
	var dir_sign: float = float(sign(direction))
	if dir_sign == 0.0:
		dir_sign = 1.0
	track_info.position = _track_info_base_position + Vector2(18.0 * dir_sign, 0.0)
	track_info.modulate = Color(1, 1, 1, 0.0)
	track_info.scale = Vector2(0.985, 0.985)
	_track_info_tween = create_tween()
	_track_info_tween.set_parallel(true)
	_track_info_tween.tween_property(track_info, "position", _track_info_base_position, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_track_info_tween.tween_property(track_info, "modulate:a", 1.0, 0.2)
	_track_info_tween.tween_property(track_info, "scale", Vector2.ONE, 0.2)

func _on_start_pressed() -> void:
	if _tracks.is_empty():
		print("MainMenu start pressed: no tracks configured")
		return
	var selected: Dictionary = _tracks[_track_index]
	var track_id: String = str(selected.get("id", ""))
	var track_name: String = str(selected.get("name", "Untitled"))
	print("MainMenu start pressed: track_id=%s (%s)" % [track_id, track_name])
	emit_signal("start_requested", track_id, track_name)

func _on_button_mouse_entered(button: Button) -> void:
	_button_hovered[button] = true
	if button == start_button:
		_stop_idle_pulse(false)
	if bool(_button_pressed.get(button, false)):
		return
	_tween_button_state(button, 1.02, _button_hover_color(button), 0.12)

func _on_button_mouse_exited(button: Button) -> void:
	_button_hovered[button] = false
	if bool(_button_pressed.get(button, false)):
		return
	_tween_button_state(button, 1.0, _button_idle_color(button), 0.14)
	if button == start_button:
		_start_idle_pulse()

func _on_button_focus_entered(button: Button) -> void:
	_on_button_mouse_entered(button)

func _on_button_focus_exited(button: Button) -> void:
	_on_button_mouse_exited(button)

func _on_button_down(button: Button) -> void:
	_button_pressed[button] = true
	if button == start_button:
		_stop_idle_pulse(false)
	_tween_button_state(button, 0.98, _button_pressed_color(button), 0.08)

func _on_button_up(button: Button) -> void:
	_button_pressed[button] = false
	var hovered: bool = bool(_button_hovered.get(button, false))
	if hovered:
		_tween_button_state(button, 1.02, _button_hover_color(button), 0.1)
	else:
		_tween_button_state(button, 1.0, _button_idle_color(button), 0.12)
	if button == start_button and not hovered:
		_start_idle_pulse()

func _button_idle_color(button: Button) -> Color:
	return Color(0.96, 0.98, 1.0, 1.0) if button == start_button else Color(0.93, 0.96, 1.0, 0.98)

func _button_hover_color(button: Button) -> Color:
	return Color(1.0, 1.0, 1.0, 1.0) if button == start_button else Color(0.98, 1.0, 1.0, 1.0)

func _button_pressed_color(button: Button) -> Color:
	return Color(0.9, 0.94, 1.0, 1.0) if button == start_button else Color(0.86, 0.9, 0.98, 1.0)

func _tween_button_state(
	button: Button,
	target_scale: float,
	target_modulate: Color,
	duration: float
) -> void:
	if button == null:
		return
	var prior_tween: Tween = _button_tweens.get(button) as Tween
	if is_instance_valid(prior_tween):
		prior_tween.kill()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(button, "scale", Vector2(target_scale, target_scale), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", target_modulate, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_button_tweens[button] = tween

func _on_menu_resized() -> void:
	call_deferred("_capture_layout_bases")

func _populate_track_options() -> void:
	_tracks = _resolve_tracks()
	if _tracks.is_empty():
		_tracks = FALLBACK_TRACKS.duplicate(true)
	var current_id: String = _current_track_id()
	_track_index = _selected_index_for_id(current_id, _tracks)
	var can_cycle: bool = _tracks.size() > 1
	track_prev_button.disabled = not can_cycle
	track_next_button.disabled = not can_cycle
	_refresh_track_info(false)

func _resolve_tracks() -> Array[Dictionary]:
	var music_manager: Node = _music_manager()
	if music_manager and music_manager.has_method("get_available_tracks"):
		var available: Array = music_manager.get_available_tracks()
		var mapped: Array[Dictionary] = []
		var track_number: int = 1
		for item in available:
			if not (item is Dictionary):
				continue
			var entry: Dictionary = item as Dictionary
			var track_id: String = str(entry.get("id", ""))
			if track_id.is_empty():
				continue
			var track_name: String = str(entry.get("name", track_id.capitalize()))
			var title: String = "TRACK %02d" % track_number
			if track_id == "off":
				title = "MUTED"
				track_name = "Music Off"
			mapped.append({
				"id": track_id,
				"title": title,
				"name": track_name,
			})
			track_number += 1
		return mapped
	return []

func _current_track_id() -> String:
	var music_manager: Node = _music_manager()
	if music_manager and music_manager.has_method("get_current_track_id"):
		return str(music_manager.get_current_track_id())
	return ""

func _selected_index_for_id(track_id: String, tracks: Array[Dictionary]) -> int:
	if track_id.is_empty():
		return 0
	for i in range(tracks.size()):
		if str(tracks[i].get("id", "")) == track_id:
			return i
	return 0

func _apply_track_selection(track_id: String) -> void:
	if track_id.is_empty():
		return
	var music_manager: Node = _music_manager()
	if music_manager and music_manager.has_method("set_track"):
		music_manager.set_track(track_id, true)

func _music_manager() -> Node:
	return get_node_or_null("/root/MusicManager")
