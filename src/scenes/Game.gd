extends Control

@onready var board: BoardView = $BoardView
@onready var top_bar_bg: Control = $UI/TopBarBg
@onready var top_bar: Control = $UI/TopBar
@onready var top_right_bar: Control = $UI/TopRightBar
@onready var score_box: VBoxContainer = $UI/TopBar/ScoreBox
@onready var powerups_row: Control = $UI/Powerups
@onready var pause_button: Button = $UI/TopBar/Pause
@onready var audio_button: Button = $UI/TopRightBar/Audio
@onready var score_caption_label: Label = $UI/TopBar/ScoreBox/ScoreCaption
@onready var score_value_label: Label = $UI/TopBar/ScoreBox/ScoreValue
@onready var undo_button: Button = $UI/Powerups/Undo
@onready var remove_color_button: Button = $UI/Powerups/RemoveColor
@onready var shuffle_button: Button = $UI/Powerups/Shuffle
@onready var undo_badge_panel: PanelContainer = $UI/Powerups/Undo/Badge
@onready var prism_badge_panel: PanelContainer = $UI/Powerups/RemoveColor/Badge
@onready var shuffle_badge_panel: PanelContainer = $UI/Powerups/Shuffle/Badge
@onready var undo_badge: Label = $UI/Powerups/Undo/Badge/Value
@onready var prism_badge: Label = $UI/Powerups/RemoveColor/Badge/Value
@onready var shuffle_badge: Label = $UI/Powerups/Shuffle/Badge/Value
@onready var board_frame: ColorRect = $UI/BoardFrame
@onready var board_glow: ColorRect = $UI/BoardGlow
@onready var powerup_flash: ColorRect = $UI/PowerupFlash

var score := 0
var combo := 0
const HIGH_COMBO_THRESHOLD := 4
var _run_finished: bool = false
var _ending_transition_started: bool = false
var _undo_charges: int = 0
var _remove_color_charges: int = 0
var _shuffle_charges: int = 0
var _undo_stack: Array[Dictionary] = []
var _pending_powerup_refill_type: String = ""
var _powerup_coin_costs := {"undo": 120, "prism": 180, "shuffle": 140}
var _powerup_usage := {"undo": 0, "prism": 0, "shuffle": 0}
var _run_started_at_unix := 0
var _run_powerups_used_total: int = 0
var _run_coins_spent: int = 0
var _open_tip_shown_this_run: bool = false
var _pending_open_tip_powerup_type: String = ""
var _pause_overlay: Control
var _tutorial_overlay: Control
var _tutorial_panel: Panel
var _tutorial_title: Label
var _tutorial_message: Label
var _tutorial_next_button: Button
var _tutorial_skip_button: Button
var _tutorial_highlights: Array[Control] = []
var _tutorial_motion_tween: Tween
var _tutorial_focus_tween: Tween
var _tutorial_focus_target: Control
var _tutorial_step: int = 0
var _prism_picker_overlay: Control
var _pause_overlap_factor: float = 0.5
var _audio_overlay: AudioTrackOverlay
var _round_time_left: float = 90.0
var _board_anchor_pos: Vector2 = Vector2.ZERO
var _scene_opened_msec: int = Time.get_ticks_msec()
var _combo_label: Label
var _timer_chip: PanelContainer
var _timer_caption_label: Label
var _timer_label: Label
var _near_miss_label: Label
var _shake_strength: float = 0.0
var _shake_time_left: float = 0.0

const ICON_UNDO: Texture2D = preload("res://assets/ui/icons/atlas/powerup_undo.tres")
const ICON_PRISM: Texture2D = preload("res://assets/ui/icons/atlas/powerup_prism.tres")
const ICON_SHUFFLE: Texture2D = preload("res://assets/ui/icons/atlas/powerup_shuffle.tres")
const ICON_LOADING: Texture2D = preload("res://assets/ui/icons/atlas/powerup_loading.tres")
const AUDIO_TRACK_OVERLAY_SCENE := preload("res://src/scenes/AudioTrackOverlay.tscn")
const ICON_MUSIC_ON: Texture2D = preload("res://assets/ui/icons/atlas/music_on.tres")
const ICON_MUSIC_OFF: Texture2D = preload("res://assets/ui/icons/atlas/music_off.tres")
const TUTORIAL_TIP_SCENE := preload("res://addons/arcade_core/ui/TutorialTipModal.tscn")
const TUTORIAL_TEMPLATE := preload("res://addons/arcade_core/ui/ArcadeTutorialTemplate.gd")
const PRISM_COLOR_PICKER_SCRIPT := preload("res://src/scenes/PrismColorPicker.gd")
const HUD_MAX_WIDTH: float = 760.0
const POWERUPS_MAX_WIDTH: float = 700.0
const BADGE_BG_COLOR: Color = Color(0.96, 0.22, 0.24, 1.0)
const BADGE_BORDER_COLOR: Color = Color(1.0, 0.9, 0.92, 0.96)
const ROUND_LIMIT_SECONDS := 84.0
const TUTORIAL_STEP_COUNT := 6
const TUTORIAL_STEP_UNDO := 2
const TUTORIAL_STEP_PRISM := 3
const TUTORIAL_STEP_SHUFFLE := 4
const TUTORIAL_STEP_DONE := 5

func _ready() -> void:
	_run_started_at_unix = Time.get_unix_time_from_system()
	_round_time_left = ROUND_LIMIT_SECONDS
	NakamaService.track_client_event("gameplay.run_started", {
		"streak_days": StreakManager.get_streak_days(),
		"track_id": MusicManager.get_current_track_id(),
		"is_authenticated": NakamaService.get_is_authenticated(),
	}, true)
	var stale_overlay: Node = get_node_or_null("RunEndOverlay")
	if stale_overlay:
		stale_overlay.queue_free()
	stale_overlay = get_node_or_null("RunEnterOverlay")
	if stale_overlay:
		stale_overlay.queue_free()
	modulate = Color(1, 1, 1, 1)
	$BoardView.modulate = Color(1, 1, 1, 1)
	$UI.modulate = Color(1, 1, 1, 1)
	Typography.style_game(self)
	ThemeManager.apply_to_scene(self)
	BackgroundMood.register_controller($BackgroundController)
	_update_gameplay_mood_from_matches(0.0)
	BackgroundMood.reset_starfield_emission_taper()
	MusicManager.set_gameplay()
	VisualTestMode.apply_if_enabled($BackgroundController, $BackgroundController)
	board.connect("match_made", Callable(self, "_on_match_made"))
	board.connect("move_committed", Callable(self, "_on_move_committed"))
	board.connect("no_moves", Callable(self, "_on_no_moves"))
	if not AdManager.is_connected("rewarded_powerup_earned", Callable(self, "_on_powerup_rewarded_earned")):
		AdManager.connect("rewarded_powerup_earned", Callable(self, "_on_powerup_rewarded_earned"))
	if not AdManager.is_connected("rewarded_closed", Callable(self, "_on_powerup_rewarded_closed")):
		AdManager.connect("rewarded_closed", Callable(self, "_on_powerup_rewarded_closed"))
	var use_feature_flag_fallback: bool = not bool(ProjectSettings.get_setting("color_crunch/nakama_enable_client", true))
	_set_powerup_charges_from_inventory(SaveStore.get_owned_powerups(), use_feature_flag_fallback)
	if board_frame:
		board_frame.visible = false
	if board_glow:
		board_glow.visible = false
	for badge in [undo_badge, prism_badge, shuffle_badge]:
		badge.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 1.0))
		badge.add_theme_color_override("font_outline_color", Color(0.3, 0.0, 0.05, 0.95))
		badge.add_theme_constant_override("outline_size", 3)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for badge_panel in [undo_badge_panel, prism_badge_panel, shuffle_badge_panel]:
		_style_badge_panel(badge_panel)
	undo_button.tooltip_text = "Undo"
	remove_color_button.tooltip_text = "Prism"
	shuffle_button.tooltip_text = "Shuffle"
	for button in [undo_button, remove_color_button, shuffle_button]:
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.clip_contents = false
	_refresh_audio_icon()
	powerup_flash.visible = false
	_setup_dynamic_overlays()
	_update_score()
	_update_powerup_buttons()

	var wallet_result: Dictionary = await NakamaService.refresh_wallet(false)
	var wallet_shop: Dictionary = NakamaService.get_shop_state()
	if wallet_result.get("ok", false):
		if not wallet_shop.is_empty():
			ThemeManager.apply_from_shop_state(wallet_shop)
			ThemeManager.apply_to_scene(self)

	_center_board()
	call_deferred("_refresh_button_pivots")
	_play_enter_transition()
	Telemetry.mark_scene_loaded("game", _scene_opened_msec)
	_maybe_show_micro_tutorial()

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		Typography.style_game(self)
		_center_board()
		call_deferred("_refresh_button_pivots")
		if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
			_layout_tutorial_overlay()

func _process(delta: float) -> void:
	if _run_finished or _ending_transition_started:
		return
	_round_time_left = max(0.0, _round_time_left - delta)
	_update_timer_label()
	if _round_time_left <= 0.0:
		_finish_run(true)
		return
	if _shake_time_left > 0.0:
		_shake_time_left = max(0.0, _shake_time_left - delta)
		var amp: float = max(0.0, _shake_strength * (_shake_time_left / 0.12))
		board.position = _board_anchor_pos + Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
	elif board and board.position != _board_anchor_pos:
		board.position = _board_anchor_pos

func _on_match_made(group: Array) -> void:
	var gained: int = board.consume_last_move_score()
	if gained <= 0:
		return
	combo += max(1, group.size())
	score += gained
	_update_score()
	UiFx.pop(score_value_label, 1.05, 0.15)
	_show_combo_feedback()
	_kick_screen_shake(min(10.0, 2.0 + combo * 0.4))
	_update_gameplay_mood_from_matches()
	BackgroundMood.reset_starfield_emission_taper()
	BackgroundMood.pulse_starfield()
	MusicManager.on_match_made()
	if combo >= HIGH_COMBO_THRESHOLD:
		MusicManager.maybe_trigger_high_combo_fx()
	_apply_difficulty_curve()

func _on_move_committed(_group: Array, snapshot: Array) -> void:
	_push_undo(snapshot, score, combo)
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay) and _tutorial_step <= 1:
		_advance_tutorial_step()

func _update_score() -> void:
	score_value_label.text = "%d" % score

func _on_pause_pressed() -> void:
	_close_audio_overlay()
	_hide_tutorial_for_overlay()
	if board and board.has_method("set_hints_enabled"):
		board.call("set_hints_enabled", false)
	var pause := preload("res://src/scenes/PauseOverlay.tscn").instantiate()
	_pause_overlay = pause
	pause.z_index = 1000
	add_child(pause)
	pause.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause.tree_exited.connect(func() -> void:
		if _pause_overlay == pause:
			_pause_overlay = null
	)
	get_tree().paused = true
	pause.connect("resume", Callable(self, "_on_resume"))
	pause.connect("quit", Callable(self, "_on_quit"))
	pause.connect("tutorial_requested", Callable(self, "_on_tutorial_requested"))

func _on_resume() -> void:
	get_tree().paused = false
	if board and board.has_method("set_hints_enabled"):
		board.call("set_hints_enabled", true)

func _on_quit() -> void:
	get_tree().paused = false
	if board and board.has_method("set_hints_enabled"):
		board.call("set_hints_enabled", true)
	_finish_run(false)

func _on_tutorial_requested() -> void:
	get_tree().paused = false
	if board and board.has_method("set_hints_enabled"):
		board.call("set_hints_enabled", true)
	SaveStore.set_tutorial_seen(false)
	call_deferred("_show_tutorial", true)

func _on_undo_pressed() -> void:
	if _undo_stack.is_empty():
		return
	if _ending_transition_started:
		return
	if _maybe_gate_powerup_opt_out("undo"):
		return
	if _undo_charges <= 0:
		var purchased := await _try_purchase_powerup_with_coins("undo")
		if not purchased:
			_request_powerup_refill("undo")
			return
	var state: Dictionary = _undo_stack.pop_back()
	board.restore_snapshot(state["grid"] as Array)
	score = int(state["score"])
	combo = int(state["combo"])
	_undo_charges -= 1
	_record_powerup_use("undo")
	call_deferred("_consume_powerup_server", "undo")
	_update_score()
	_update_gameplay_mood_from_matches(0.3)
	_update_powerup_buttons()
	_play_powerup_juice(Color(0.72, 0.9, 1.0, FeatureFlags.powerup_flash_alpha()))

func _on_remove_color_pressed() -> void:
	if _ending_transition_started:
		return
	if is_instance_valid(_prism_picker_overlay):
		return
	if _maybe_gate_powerup_opt_out("prism"):
		return
	if _remove_color_charges <= 0:
		var purchased := await _try_purchase_powerup_with_coins("prism")
		if not purchased:
			_request_powerup_refill("prism")
			return
	var choices: Array[Dictionary] = _prism_color_choices()
	if choices.is_empty():
		return
	_show_prism_color_picker(choices)

func _apply_prism_to_color(level: int) -> void:
	if _ending_transition_started:
		return
	if _remove_color_charges <= 0:
		_update_powerup_buttons()
		return
	var snapshot: Array = board.capture_snapshot()
	var score_before: int = score
	var combo_before: int = combo
	var result: Dictionary = await board.apply_remove_color_powerup(level)
	var removed: int = int(result.get("removed", 0))
	if removed <= 0:
		_update_powerup_buttons()
		return
	_push_undo(snapshot, score_before, combo_before)
	_remove_color_charges -= 1
	_record_powerup_use("prism")
	call_deferred("_consume_powerup_server", "prism")
	combo += 1
	_round_time_left = min(ROUND_LIMIT_SECONDS + 12.0, _round_time_left + min(8.0, float(removed) * 0.6))
	_update_score()
	_update_timer_label()
	_update_gameplay_mood_from_matches(0.3)
	_update_powerup_buttons()
	MusicManager.on_match_made()
	_play_powerup_juice(Color(1.0, 0.92, 0.7, FeatureFlags.powerup_flash_alpha()))

func _prism_color_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if board == null or board.board == null:
		return choices
	var counts: Dictionary = {}
	for y in range(board.height):
		for x in range(board.width):
			var level: int = int(board.board.grid[y][x])
			if level <= 0:
				continue
			counts[level] = int(counts.get(level, 0)) + 1
	var levels: Array = counts.keys()
	levels.sort()
	for level_variant in levels:
		var level: int = int(level_variant)
		choices.append({
			"level": level,
			"label": board._label_for_level(level),
			"count": int(counts[level]),
			"color": board._color_from_level(level),
			"font_color": board._font_color_for_level(level),
		})
	return choices

func _show_prism_color_picker(choices: Array[Dictionary]) -> void:
	if choices.is_empty() or is_instance_valid(_prism_picker_overlay):
		return
	_hide_tutorial_for_overlay()
	if board:
		board.set_process_input(false)
	var picker: Control = PRISM_COLOR_PICKER_SCRIPT.new() as Control
	picker.name = "PrismColorPicker"
	picker.configure(choices)
	picker.color_selected.connect(Callable(self, "_on_prism_color_selected"))
	picker.closed.connect(Callable(self, "_on_prism_picker_closed"))
	_prism_picker_overlay = picker
	add_child(picker)

func _on_prism_color_selected(level: int) -> void:
	call_deferred("_apply_prism_to_color", level)

func _on_prism_picker_closed() -> void:
	_prism_picker_overlay = null
	if board and not _ending_transition_started:
		board.set_process_input(true)

func _dismiss_prism_color_picker() -> void:
	if not is_instance_valid(_prism_picker_overlay):
		_prism_picker_overlay = null
		return
	_prism_picker_overlay.queue_free()
	_prism_picker_overlay = null

func _on_shuffle_pressed() -> void:
	if _ending_transition_started:
		return
	if _maybe_gate_powerup_opt_out("shuffle"):
		return
	if _shuffle_charges <= 0:
		var purchased := await _try_purchase_powerup_with_coins("shuffle")
		if not purchased:
			_request_powerup_refill("shuffle")
			return
	var snapshot: Array = board.capture_snapshot()
	var score_before: int = score
	var combo_before: int = combo
	var changed: bool = await board.apply_shuffle_powerup()
	if not changed:
		return
	_push_undo(snapshot, score_before, combo_before)
	_shuffle_charges -= 1
	_record_powerup_use("shuffle")
	call_deferred("_consume_powerup_server", "shuffle")
	_round_time_left = min(ROUND_LIMIT_SECONDS + 12.0, _round_time_left + 6.0)
	combo = max(0, combo - 1)
	_update_score()
	_update_timer_label()
	_update_gameplay_mood_from_matches(0.3)
	_update_powerup_buttons()
	_play_powerup_juice(Color(0.8, 0.86, 1.0, FeatureFlags.powerup_flash_alpha()))

func _update_gameplay_mood_from_matches(fade_seconds: float = -1.0) -> void:
	var matches_left: int = board.board.count_available_matches()
	var n: float = FeatureFlags.gameplay_matches_normalizer()
	var max_calm_weight: float = FeatureFlags.gameplay_matches_max_calm_weight()
	var raw_calm_weight: float = 1.0 - clamp(float(matches_left) / n, 0.0, 1.0)
	var calm_weight: float = raw_calm_weight * max_calm_weight
	var fade: float = fade_seconds if fade_seconds >= 0.0 else FeatureFlags.gameplay_matches_mood_fade_seconds()
	BackgroundMood.set_mood_mix(calm_weight, fade)
	if matches_left <= 2:
		_show_near_miss_warning(matches_left)

func _update_powerup_buttons() -> void:
	undo_button.icon = _powerup_button_icon(ICON_UNDO, "undo")
	remove_color_button.icon = _powerup_button_icon(ICON_PRISM, "prism")
	shuffle_button.icon = _powerup_button_icon(ICON_SHUFFLE, "shuffle")
	_update_badge(undo_badge_panel, undo_badge, _undo_charges, _pending_powerup_refill_type == "undo")
	_update_badge(prism_badge_panel, prism_badge, _remove_color_charges, _pending_powerup_refill_type == "prism")
	_update_badge(shuffle_badge_panel, shuffle_badge, _shuffle_charges, _pending_powerup_refill_type == "shuffle")
	undo_button.disabled = (_undo_charges > 0 and _undo_stack.is_empty()) or _is_other_refill_pending("undo")
	remove_color_button.disabled = _is_other_refill_pending("prism")
	shuffle_button.disabled = _is_other_refill_pending("shuffle")
	undo_button.tooltip_text = "Undo"
	remove_color_button.tooltip_text = "Prism"
	shuffle_button.tooltip_text = "Shuffle"

func _push_undo(snapshot: Array, score_snapshot: int, combo_snapshot: int) -> void:
	_undo_stack.append({
		"grid": snapshot.duplicate(true),
		"score": score_snapshot,
		"combo": combo_snapshot,
	})
	if _undo_stack.size() > 6:
		_undo_stack.pop_front()
	_update_powerup_buttons()

func _play_powerup_juice(flash_color: Color) -> void:
	powerup_flash.visible = true
	powerup_flash.color = flash_color
	var board_scale_start: Vector2 = board.scale
	var board_scale_peak: Vector2 = board_scale_start * Vector2(1.03, 1.03)
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.tween_method(Callable(self, "_set_board_scale_centered"), board_scale_start, board_scale_peak, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(powerup_flash, "color:a", FeatureFlags.powerup_flash_alpha(), 0.08)
	t.chain().tween_method(Callable(self, "_set_board_scale_centered"), board_scale_peak, board_scale_start, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(powerup_flash, "color:a", 0.0, FeatureFlags.powerup_flash_seconds())
	t.finished.connect(func() -> void:
		powerup_flash.visible = false
	)

func _set_board_scale_centered(target_scale: Vector2) -> void:
	var board_center_local: Vector2 = Vector2(
		float(board.width) * board.tile_size * 0.5,
		float(board.height) * board.tile_size * 0.5
	)
	var center_before: Vector2 = board.to_global(board_center_local)
	board.scale = target_scale
	var center_after: Vector2 = board.to_global(board_center_local)
	board.global_position += center_before - center_after

func _grant_bonus_powerup(powerup_type: String) -> void:
	match powerup_type:
		"undo":
			_undo_charges += 1
		"prism":
			_remove_color_charges += 1
		"shuffle":
			_shuffle_charges += 1
	_update_powerup_buttons()
	_play_powerup_juice(Color(1.0, 0.94, 0.58, 0.28))
	Input.vibrate_handheld(38, 0.65)

func _on_powerup_rewarded_earned() -> void:
	if _pending_powerup_refill_type.is_empty():
		return
	var powerup_type: String = _pending_powerup_refill_type
	_pending_powerup_refill_type = ""
	_grant_bonus_powerup(powerup_type)

func _on_powerup_rewarded_closed() -> void:
	if not _pending_powerup_refill_type.is_empty():
		_pending_powerup_refill_type = ""
		_update_powerup_buttons()

func _request_powerup_refill(powerup_type: String) -> void:
	if _ending_transition_started:
		return
	if not _pending_powerup_refill_type.is_empty():
		return
	_pending_powerup_refill_type = powerup_type
	_update_powerup_buttons()
	if not AdManager.show_rewarded_for_powerup():
		_pending_powerup_refill_type = ""
		_update_powerup_buttons()

func _try_purchase_powerup_with_coins(powerup_type: String) -> bool:
	var cost: int = int(_powerup_coin_costs.get(powerup_type, 0))
	if cost <= 0:
		return false
	var purchase_id := "%s_%d" % [powerup_type, Time.get_unix_time_from_system()]
	var result: Dictionary = await NakamaService.purchase_powerup(powerup_type, 1, cost, purchase_id)
	if not result.get("ok", false):
		return false
	match powerup_type:
		"undo":
			_undo_charges += 1
		"prism":
			_remove_color_charges += 1
		"shuffle":
			_shuffle_charges += 1
	_run_coins_spent += cost
	_update_powerup_buttons()
	return true

func _consume_powerup_server(powerup_type: String) -> void:
	await NakamaService.consume_powerup(powerup_type, 1)

func _powerup_button_icon(base_icon: Texture2D, powerup_type: String) -> Texture2D:
	if _pending_powerup_refill_type == powerup_type:
		return ICON_LOADING
	return base_icon

func _set_powerup_charges_from_inventory(powerups_value: Variant, allow_feature_flag_fallback: bool) -> void:
	var powerups: Dictionary = _sanitize_powerup_inventory(powerups_value)
	if allow_feature_flag_fallback and _is_powerup_inventory_empty(powerups):
		_undo_charges = FeatureFlags.powerup_undo_charges()
		_remove_color_charges = FeatureFlags.powerup_remove_color_charges()
		_shuffle_charges = FeatureFlags.powerup_shuffle_charges()
		return
	_undo_charges = int(powerups.get("undo", 0))
	_remove_color_charges = int(powerups.get("prism", 0))
	_shuffle_charges = int(powerups.get("shuffle", 0))

func _sanitize_powerup_inventory(powerups_value: Variant) -> Dictionary:
	if typeof(powerups_value) != TYPE_DICTIONARY:
		return {"undo": 0, "prism": 0, "shuffle": 0}
	var input: Dictionary = powerups_value as Dictionary
	return {
		"undo": max(0, int(input.get("undo", 0))),
		"prism": max(0, int(input.get("prism", 0))),
		"shuffle": max(0, int(input.get("shuffle", 0))),
	}

func _is_powerup_inventory_empty(powerups: Dictionary) -> bool:
	return int(powerups.get("undo", 0)) <= 0 \
		and int(powerups.get("prism", 0)) <= 0 \
		and int(powerups.get("shuffle", 0)) <= 0

func _update_badge(panel: PanelContainer, label: Label, charges: int, is_loading: bool) -> void:
	if label == null:
		return
	_style_badge_panel(panel)
	label.visible = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if is_loading:
		label.text = "..."
		label.modulate = Color(1.0, 0.98, 1.0, 0.94)
	elif charges > 0:
		label.text = "x%d" % charges
		label.modulate = Color(0.98, 0.99, 1.0, 0.98)
	else:
		label.text = "0"
		label.modulate = Color(0.98, 0.99, 1.0, 0.88)
	_set_badge_top_right(panel)
	_fit_badge_font_size(label)

func _set_badge_top_right(panel: PanelContainer) -> void:
	if panel == null:
		return
	var row_height: float = 110.0
	if powerups_row and powerups_row.size.y > 0.0:
		row_height = powerups_row.size.y
	var radius: float = clamp(row_height * 0.17, 15.0, 22.0)
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -radius
	panel.offset_top = -radius
	panel.offset_right = radius
	panel.offset_bottom = radius
	panel.z_index = 10
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END

func _fit_badge_font_size(label: Label) -> void:
	var font: Font = label.get_theme_font("font")
	if font == null:
		return
	if label.size.x <= 0.0:
		return
	var max_width: float = max(24.0, label.size.x - 10.0)
	var size: int = max(12, label.get_theme_font_size("font_size"))
	while size > 12:
		var measured_width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		if measured_width <= max_width:
			break
		size -= 1
	label.add_theme_font_size_override("font_size", size)

func _style_badge_panel(panel: PanelContainer) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = BADGE_BG_COLOR
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = BADGE_BORDER_COLOR
	style.corner_radius_top_left = 128
	style.corner_radius_top_right = 128
	style.corner_radius_bottom_left = 128
	style.corner_radius_bottom_right = 128
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.2
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _is_other_refill_pending(powerup_type: String) -> bool:
	return not _pending_powerup_refill_type.is_empty() and _pending_powerup_refill_type != powerup_type

func _on_no_moves() -> void:
	_finish_run(true)

func _finish_run(completed_by_gameplay: bool) -> void:
	if _run_finished:
		return
	if _ending_transition_started:
		return
	get_tree().paused = false
	_dismiss_prism_color_picker()
	_ending_transition_started = true
	await _play_end_transition()
	_run_finished = true
	var elapsed : int = max(0, Time.get_unix_time_from_system() - _run_started_at_unix)
	NakamaService.track_client_event("gameplay.run_finished", {
		"score": score,
		"combo": combo,
		"completed_by_gameplay": completed_by_gameplay,
		"elapsed_seconds": elapsed,
		"powerup_undo_used": int(_powerup_usage.get("undo", 0)),
		"powerup_prism_used": int(_powerup_usage.get("prism", 0)),
		"powerup_shuffle_used": int(_powerup_usage.get("shuffle", 0)),
	}, true)
	RunManager.set_run_leaderboard_context(_run_powerups_used_total, _run_coins_spent, _powerup_usage)
	RunManager.end_game(score, completed_by_gameplay)

func _record_powerup_use(powerup_type: String) -> void:
	if not _powerup_usage.has(powerup_type):
		_powerup_usage[powerup_type] = 0
	_powerup_usage[powerup_type] = int(_powerup_usage[powerup_type]) + 1
	_run_powerups_used_total += 1
	RunManager.set_run_leaderboard_context(_run_powerups_used_total, _run_coins_spent, _powerup_usage)
	Telemetry.mark_powerup_used(powerup_type, "OPEN", _remaining_powerup_charges(powerup_type))
	NakamaService.track_client_event("gameplay.powerup_used", {
		"powerup_type": powerup_type,
		"remaining": _remaining_powerup_charges(powerup_type),
	}, true)

func _maybe_gate_powerup_opt_out(powerup_type: String) -> bool:
	if _run_powerups_used_total > 0 or _open_tip_shown_this_run:
		return false
	if not SaveStore.should_show_tip(SaveStore.TIP_OPEN_LEADERBOARD_FIRST_POWERUP, true):
		_open_tip_shown_this_run = true
		return false
	if not _pending_open_tip_powerup_type.is_empty():
		return true
	_pending_open_tip_powerup_type = powerup_type
	_show_open_mode_tip()
	return true

func _show_open_mode_tip() -> void:
	if _open_tip_shown_this_run:
		return
	_hide_tutorial_for_overlay()
	var modal := TUTORIAL_TIP_SCENE.instantiate()
	if modal.has_method("configure"):
		modal.configure({
			"title": "Open Run",
			"message": "Power-ups opt this run out of Pure. This score posts to Open; no-powerup runs stay Pure.",
			"confirm_text": "Got it",
			"cancel_text": "Close",
			"show_cancel": false,
			"checkbox_text": "Don't show again",
			"show_checkbox": true,
		})
	if modal.has_signal("confirmed"):
		modal.confirmed.connect(_on_open_mode_tip_confirmed)
	if modal.has_signal("canceled"):
		modal.canceled.connect(_on_open_mode_tip_canceled)
	add_child(modal)

func _on_open_mode_tip_confirmed(do_not_show_again: bool) -> void:
	if do_not_show_again:
		SaveStore.set_tip_dismissed(SaveStore.TIP_OPEN_LEADERBOARD_FIRST_POWERUP, true)
	var powerup_type := _pending_open_tip_powerup_type
	_pending_open_tip_powerup_type = ""
	_open_tip_shown_this_run = true
	match powerup_type:
		"undo":
			call_deferred("_on_undo_pressed")
		"prism":
			call_deferred("_on_remove_color_pressed")
		"shuffle":
			call_deferred("_on_shuffle_pressed")

func _on_open_mode_tip_canceled(_do_not_show_again: bool) -> void:
	_pending_open_tip_powerup_type = ""

func _on_audio_pressed() -> void:
	_hide_tutorial_for_overlay()
	if is_instance_valid(_audio_overlay):
		_close_audio_overlay()
		return
	var tracks: Array[Dictionary] = _music_tracks()
	if tracks.is_empty():
		return
	var overlay := AUDIO_TRACK_OVERLAY_SCENE.instantiate() as AudioTrackOverlay
	if overlay == null:
		return
	add_child(overlay)
	_audio_overlay = overlay
	overlay.setup(_track_names_from_tracks(tracks), _selected_track_index_for_current(tracks))
	overlay.track_selected.connect(_on_audio_overlay_track_selected)
	overlay.closed.connect(_on_audio_overlay_closed)

func _on_audio_overlay_track_selected(_track_name: String, index: int) -> void:
	_apply_audio_track_index(index)

func _on_audio_overlay_closed() -> void:
	_audio_overlay = null

func _close_audio_overlay() -> void:
	if not is_instance_valid(_audio_overlay):
		_audio_overlay = null
		return
	_audio_overlay.queue_free()
	_audio_overlay = null

func _music_tracks() -> Array[Dictionary]:
	return MusicManager.get_available_tracks()

func _track_names_from_tracks(tracks: Array[Dictionary]) -> Array[String]:
	var names: Array[String] = []
	for track in tracks:
		names.append(str(track.get("name", "Track")))
	return names

func _selected_track_index_for_current(tracks: Array[Dictionary]) -> int:
	if tracks.is_empty():
		return 0
	var current_id: String = str(MusicManager.get_current_track_id())
	for i in range(tracks.size()):
		if str(tracks[i].get("id", "")) == current_id:
			return i
	return 0

func _apply_audio_track_index(index: int) -> void:
	var tracks: Array[Dictionary] = _music_tracks()
	if tracks.is_empty():
		return
	var selected: int = clampi(index, 0, tracks.size() - 1)
	var track_id: String = str(tracks[selected].get("id", ""))
	if track_id.is_empty():
		return
	MusicManager.set_track(track_id, true)
	_sync_audio_overlay_selection()
	_refresh_audio_icon()

func _sync_audio_overlay_selection() -> void:
	if not is_instance_valid(_audio_overlay):
		return
	var tracks: Array[Dictionary] = _music_tracks()
	_audio_overlay.set_selected_index(_selected_track_index_for_current(tracks))

static func is_muted_track(track_id: String) -> bool:
	return track_id.strip_edges().to_lower() == "off"

func _refresh_audio_icon() -> void:
	if audio_button == null:
		return
	var muted: bool = is_muted_track(str(MusicManager.get_current_track_id()))
	audio_button.set("icon_texture", ICON_MUSIC_OFF if muted else ICON_MUSIC_ON)
	var label: String = "Audio Off" if muted else "Audio"
	audio_button.set("tooltip_text_override", label)
	audio_button.set("accessibility_name_override", label)

func _remaining_powerup_charges(powerup_type: String) -> int:
	match powerup_type:
		"undo":
			return _undo_charges
		"prism":
			return _remove_color_charges
		"shuffle":
			return _shuffle_charges
	return 0

func _play_end_transition() -> void:
	set_process_input(false)
	MusicManager.fade_out_hype_layers(0.5)
	# End transition should always drive the background fully calm before white-out.
	BackgroundMood.set_mood(BackgroundMood.Mood.CALM, 0.45)
	var overlay := ColorRect.new()
	overlay.name = "RunEndOverlay"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.set_parallel(true)
	fade.tween_property($BoardView, "modulate:a", 0.0, 0.45)
	fade.tween_property($UI, "modulate:a", 0.0, 0.35)
	fade.tween_property(overlay, "color:a", 0.95, 0.45)
	await fade.finished

func _play_enter_transition() -> void:
	board.set_process_input(false)
	set_process_input(false)
	var overlay := ColorRect.new()
	overlay.name = "RunEnterOverlay"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(1.0, 1.0, 1.0, 1.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(overlay, "color:a", 0.0, 0.35)
	t.finished.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
		board.set_process_input(true)
		set_process_input(true)
	)

func _center_board() -> void:
	if board == null:
		return
	var view_size: Vector2 = get_viewport_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return

	var outer_margin: float = clamp(view_size.x * 0.04, 14.0, 44.0)
	var max_column_width: float = max(260.0, min(HUD_MAX_WIDTH, view_size.x - 8.0))
	var min_column_width: float = min(340.0, max_column_width)
	var content_width: float = clamp(view_size.x - (outer_margin * 2.0), min_column_width, max_column_width)
	var content_left: float = (view_size.x - content_width) * 0.5
	var is_landscape: bool = view_size.x >= view_size.y

	_layout_top_bar(view_size, content_left, content_width)
	_layout_top_right(view_size)

	var powerup_row_height: float = clamp(view_size.y * (0.13 if is_landscape else 0.16), 72.0 if is_landscape else 96.0, 108.0 if is_landscape else 122.0)
	var max_row_width: float = max(280.0, min(POWERUPS_MAX_WIDTH, content_width))
	var min_row_width: float = min(320.0, max_row_width)
	var powerup_row_width: float = clamp(content_width, min_row_width, max_row_width)
	_layout_powerups(view_size, powerup_row_width, powerup_row_height)
	_apply_responsive_hud_typography(content_width, top_bar_bg.size.y, powerup_row_height)

	var vertical_gap: float = clamp(view_size.y * 0.022, 14.0, 26.0)
	var top_limit: float = view_size.y * 0.14
	if top_bar_bg and top_bar_bg.size.y > 0.0:
		top_limit = top_bar_bg.position.y + top_bar_bg.size.y + vertical_gap
	var bottom_limit: float = view_size.y * 0.81
	if powerups_row and powerups_row.size.y > 0.0:
		bottom_limit = powerups_row.position.y - vertical_gap
	var available_width: float = max(120.0, content_width)
	var available_height: float = max(120.0, bottom_limit - top_limit)
	var fit_w: float = floor(available_width / float(board.width))
	var fit_h: float = floor(available_height / float(board.height))
	var min_tile_size: float = 54.0 if is_landscape or view_size.y < 760.0 else 72.0
	var target_tile_size: float = clamp(min(fit_w, fit_h), min_tile_size, 188.0)
	board.set_tile_size(target_tile_size)
	var board_size: Vector2 = Vector2(board.width * board.tile_size, board.height * board.tile_size)
	board.position = Vector2(
		(view_size.x - board_size.x) * 0.5,
		top_limit + ((available_height - board_size.y) * 0.5)
	)
	_board_anchor_pos = board.position

	powerup_row_width = clamp(board_size.x + max(84.0, board.tile_size * 0.8), min_row_width, max_row_width)
	_layout_powerups(view_size, powerup_row_width, powerup_row_height)
	_apply_responsive_hud_typography(content_width, top_bar_bg.size.y, powerup_row_height)
	_refresh_button_pivots()
	_layout_dynamic_overlays(view_size)

	if board_frame:
		var frame_padding: float = clamp(board.tile_size * 0.18, 12.0, 24.0)
		board_frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
		board_frame.position = board.position - Vector2(frame_padding, frame_padding)
		board_frame.size = board_size + Vector2(frame_padding * 2.0, frame_padding * 2.0)
	if board_glow:
		var glow_padding: float = clamp(board.tile_size * 0.28, 18.0, 36.0)
		board_glow.set_anchors_preset(Control.PRESET_TOP_LEFT)
		board_glow.position = board.position - Vector2(glow_padding, glow_padding)
		board_glow.size = board_size + Vector2(glow_padding * 2.0, glow_padding * 2.0)

func _layout_top_bar(view_size: Vector2, content_left: float, content_width: float) -> void:
	if top_bar_bg == null or top_bar == null:
		return
	var is_landscape: bool = view_size.x >= view_size.y
	var top_margin: float = clamp(view_size.y * 0.03, 14.0, 30.0)
	var bar_height: float = clamp(view_size.y * (0.13 if is_landscape else 0.16), 72.0 if is_landscape else 92.0, 116.0 if is_landscape else 132.0)
	top_bar_bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_bar_bg.position = Vector2(content_left, top_margin)
	top_bar_bg.size = Vector2(content_width, bar_height)

	var content_inset_x: float = clamp(content_width * 0.055, 14.0, 34.0)
	var content_inset_y: float = clamp(bar_height * 0.09, 8.0, 14.0)
	var right_reserve: float = clamp(content_width * 0.03, 12.0, 28.0)
	var vertical_lift: float = clamp(bar_height * 0.06, 4.0, 8.0)
	top_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_bar.position = Vector2(content_left + content_inset_x, top_margin + content_inset_y - vertical_lift)
	top_bar.size = Vector2(
		max(220.0, content_width - (content_inset_x * 2.0) - right_reserve),
		max(56.0, bar_height - (content_inset_y * 2.0))
	)
	top_bar.add_theme_constant_override("separation", int(round(clamp(content_width * 0.016, 10.0, 20.0))))
	if score_box:
		score_box.add_theme_constant_override("separation", int(round(clamp(bar_height * 0.035, 4.0, 8.0))))
	if pause_button:
		var pause_size: float = clamp(top_bar.size.y * 0.74, 52.0, 82.0)
		pause_button.custom_minimum_size = Vector2(pause_size, pause_size)
		pause_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pause_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		_pause_overlap_factor = _pause_overlap_factor_for_viewport(view_size)
		_queue_pause_button_overlap_position()

func _layout_top_right(view_size: Vector2) -> void:
	if top_right_bar == null or audio_button == null:
		return
	var is_landscape: bool = view_size.x >= view_size.y
	var margin: float = clamp(min(view_size.x, view_size.y) * 0.045, 12.0, 32.0)
	var icon_size: float = clamp(min(view_size.x, view_size.y) * (0.1 if is_landscape else 0.12), 56.0 if is_landscape else 68.0, 82.0 if is_landscape else 92.0)
	top_right_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_right_bar.position = Vector2(view_size.x - margin - icon_size, margin)
	top_right_bar.size = Vector2(icon_size, icon_size)
	audio_button.custom_minimum_size = Vector2(icon_size, icon_size)

func _apply_responsive_hud_typography(content_width: float, bar_height: float, powerup_row_height: float) -> void:
	var caption_size: int = int(round(clamp(bar_height * 0.25, 14.0, 30.0)))
	var value_size: int = int(round(clamp(bar_height * 0.54, 26.0, 68.0)))
	if content_width < 520.0:
		caption_size = min(caption_size, 22)
		value_size = min(value_size, 48)
	if score_caption_label:
		score_caption_label.add_theme_font_size_override("font_size", caption_size)
	if score_value_label:
		score_value_label.add_theme_font_size_override("font_size", value_size)
		score_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		score_value_label.custom_minimum_size.y = clamp(bar_height * 0.5, 40.0, 72.0)

	var badge_font_size: int = int(round(clamp(powerup_row_height * 0.27, 15.0, 28.0)))
	for badge in [undo_badge, prism_badge, shuffle_badge]:
		if badge:
			badge.add_theme_font_size_override("font_size", badge_font_size)
			_fit_badge_font_size(badge)

func _layout_powerups(view_size: Vector2, row_width: float, row_height: float) -> void:
	if powerups_row == null:
		return
	var is_landscape: bool = view_size.x >= view_size.y
	var bottom_margin: float = clamp(view_size.y * (0.025 if is_landscape else 0.035), 10.0 if is_landscape else 14.0, 24.0 if is_landscape else 28.0)
	powerups_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	powerups_row.position = Vector2((view_size.x - row_width) * 0.5, view_size.y - bottom_margin - row_height)
	powerups_row.size = Vector2(row_width, row_height)
	powerups_row.add_theme_constant_override("separation", int(round(clamp(row_width * 0.03, 12.0, 22.0))))
	for button in [undo_button, remove_color_button, shuffle_button]:
		if button:
			button.custom_minimum_size = Vector2(0.0, row_height)

func _refresh_button_pivots() -> void:
	for button_variant in [pause_button, audio_button, undo_button, remove_color_button, shuffle_button]:
		var button: Control = button_variant as Control
		if button == null:
			continue
		if button.size.x <= 0.0 or button.size.y <= 0.0:
			continue
		button.pivot_offset = button.size * 0.5

func _position_pause_button_overlap() -> void:
	if pause_button == null or top_bar == null:
		return
	if pause_button.size.y <= 0.0:
		return
	var centered_y: float = floor((top_bar.size.y - pause_button.size.y) * 0.5)
	pause_button.position.y = centered_y - (pause_button.size.y * _pause_overlap_factor)

func _pause_overlap_factor_for_viewport(view_size: Vector2) -> float:
	if view_size.y <= 0.0:
		return 0.5
	var aspect: float = view_size.x / view_size.y
	# Portrait needs slightly less overlap to keep pause visually aligned with the bar.
	return 0.42 if aspect < 0.9 else 0.5

func _queue_pause_button_overlap_position() -> void:
	call_deferred("_queue_pause_button_overlap_position_deferred")

func _queue_pause_button_overlap_position_deferred() -> void:
	call_deferred("_position_pause_button_overlap")

func _setup_dynamic_overlays() -> void:
	if _combo_label == null:
		_combo_label = Label.new()
		_combo_label.name = "ComboChain"
		_combo_label.visible = false
		_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_combo_label.add_theme_font_size_override("font_size", 32)
		_combo_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.56, 0.98))
		_combo_label.add_theme_color_override("font_outline_color", Color(0.06, 0.1, 0.2, 0.95))
		_combo_label.add_theme_constant_override("outline_size", 2)
		_combo_label.anchor_left = 0.5
		_combo_label.anchor_right = 0.5
		_combo_label.anchor_top = 0.0
		_combo_label.anchor_bottom = 0.0
		_combo_label.offset_left = -180.0
		_combo_label.offset_right = 180.0
		_combo_label.offset_top = 86.0
		_combo_label.offset_bottom = 130.0
		$UI.add_child(_combo_label)
	if _timer_chip == null:
		_timer_chip = PanelContainer.new()
		_timer_chip.name = "RoundTimerChip"
		_timer_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_timer_chip.size_flags_horizontal = Control.SIZE_SHRINK_END
		_timer_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top_bar_bg.add_child(_timer_chip)
		var timer_margin := MarginContainer.new()
		timer_margin.name = "Margin"
		timer_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_timer_chip.add_child(timer_margin)
		var timer_box := VBoxContainer.new()
		timer_box.name = "VBox"
		timer_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		timer_box.alignment = BoxContainer.ALIGNMENT_CENTER
		timer_box.add_theme_constant_override("separation", -2)
		timer_margin.add_child(timer_box)
		_timer_caption_label = Label.new()
		_timer_caption_label.name = "Caption"
		_timer_caption_label.text = "TIME"
		_timer_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_timer_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_timer_caption_label.clip_text = false
		_timer_caption_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		timer_box.add_child(_timer_caption_label)
		_timer_label = Label.new()
		_timer_label.name = "Value"
		_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_timer_label.clip_text = false
		_timer_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		timer_box.add_child(_timer_label)
	if _near_miss_label == null:
		_near_miss_label = Label.new()
		_near_miss_label.name = "NearMissLabel"
		_near_miss_label.visible = false
		_near_miss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_near_miss_label.add_theme_font_size_override("font_size", 24)
		_near_miss_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.42, 0.98))
		_near_miss_label.add_theme_color_override("font_outline_color", Color(0.14, 0.08, 0.06, 0.95))
		_near_miss_label.add_theme_constant_override("outline_size", 2)
		_near_miss_label.anchor_left = 0.0
		_near_miss_label.anchor_right = 1.0
		_near_miss_label.anchor_top = 0.0
		_near_miss_label.anchor_bottom = 0.0
		_near_miss_label.offset_left = 24.0
		_near_miss_label.offset_right = -24.0
		_near_miss_label.offset_top = 64.0
		_near_miss_label.offset_bottom = 102.0
		$UI.add_child(_near_miss_label)
	_update_timer_label()

func _layout_dynamic_overlays(view_size: Vector2) -> void:
	if _timer_chip:
		var top_height: float = top_bar_bg.size.y if top_bar_bg else clamp(view_size.y * 0.12, 72.0, 120.0)
		var chip_width: float = clamp(top_bar_bg.size.x * 0.17, 74.0, 118.0) if top_bar_bg else clamp(view_size.x * 0.14, 74.0, 118.0)
		var chip_height: float = clamp(top_height * 0.54, 36.0, 56.0)
		var pause_width: float = pause_button.custom_minimum_size.x if pause_button != null else 62.0
		var right_inset: float = clamp(top_bar_bg.size.x * 0.045, 14.0, 24.0) if top_bar_bg else 18.0
		var gap_to_pause: float = clamp(top_height * 0.22, 18.0, 30.0)
		var chip_x: float = max(right_inset, top_bar_bg.size.x - right_inset - pause_width - gap_to_pause - chip_width) if top_bar_bg else 0.0
		var chip_y: float = max(4.0, (top_height - chip_height) * 0.5)
		_timer_chip.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_timer_chip.position = Vector2(chip_x, chip_y)
		_timer_chip.size = Vector2(chip_width, chip_height)
		_timer_chip.custom_minimum_size = Vector2(chip_width, chip_height)
		_timer_chip.size_flags_horizontal = Control.SIZE_SHRINK_END
		_timer_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_timer_chip.pivot_offset = _timer_chip.size * 0.5
		_style_timer_chip(_round_time_left <= 15.0)
		var timer_margin: MarginContainer = _timer_chip.get_node("Margin") as MarginContainer
		if timer_margin:
			var margin_x: int = int(round(clamp(chip_width * 0.12, 10.0, 16.0)))
			var margin_y: int = int(round(clamp(chip_height * 0.08, 4.0, 8.0)))
			timer_margin.add_theme_constant_override("margin_left", margin_x)
			timer_margin.add_theme_constant_override("margin_top", margin_y)
			timer_margin.add_theme_constant_override("margin_right", margin_x)
			timer_margin.add_theme_constant_override("margin_bottom", margin_y)
	if _combo_label:
		_combo_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_combo_label.position = Vector2((view_size.x - 360.0) * 0.5, clamp(view_size.y * 0.055, 46.0, 86.0))
		_combo_label.size = Vector2(360.0, 44.0)
	if _near_miss_label:
		_near_miss_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_near_miss_label.position = Vector2(24.0, clamp(view_size.y * 0.06, 54.0, 86.0))
		_near_miss_label.size = Vector2(max(120.0, view_size.x - 48.0), 38.0)

func _update_timer_label() -> void:
	if _timer_label == null:
		return
	var seconds_left := int(ceil(_round_time_left))
	_timer_label.text = "%02d" % max(0, seconds_left)
	var danger := _round_time_left <= 15.0
	_style_timer_chip(danger)

func _style_timer_chip(danger: bool) -> void:
	if _timer_chip == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.23, 0.24, 0.26) if danger else Color(0.70, 0.92, 1.0, 0.16)
	style.border_color = Color(1.0, 0.62, 0.58, 0.78) if danger else Color(0.86, 0.97, 1.0, 0.42)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0.02, 0.05, 0.16, 0.26)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	_timer_chip.add_theme_stylebox_override("panel", style)
	var label_color: Color = Color(1.0, 0.35, 0.31, 1.0) if danger else Color(0.93, 0.98, 1.0, 1.0)
	var caption_color: Color = Color(1.0, 0.76, 0.70, 0.95) if danger else Color(0.74, 0.92, 1.0, 0.88)
	if _timer_caption_label:
		_timer_caption_label.add_theme_font_override("font", Typography.interface_font(Typography.WEIGHT_SEMIBOLD))
		_timer_caption_label.add_theme_font_size_override("font_size", int(round(clamp(_timer_chip.custom_minimum_size.y * 0.22, 11.0, 15.0))))
		_timer_caption_label.add_theme_color_override("font_color", caption_color)
		_timer_caption_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.12, 0.86))
		_timer_caption_label.add_theme_constant_override("outline_size", 1)
	if _timer_label:
		_timer_label.add_theme_font_override("font", Typography.interface_font(Typography.WEIGHT_BOLD))
		_timer_label.add_theme_font_size_override("font_size", int(round(clamp(_timer_chip.custom_minimum_size.y * 0.52, 24.0, 40.0))))
		_timer_label.add_theme_color_override("font_color", label_color)
		_timer_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.12, 0.92))
		_timer_label.add_theme_constant_override("outline_size", 2)

func _show_combo_feedback() -> void:
	if _combo_label == null or combo < 2:
		return
	_combo_label.visible = true
	_combo_label.text = "Chain x%d" % combo
	_combo_label.modulate.a = 1.0
	_combo_label.position.y = 86.0
	var tween := create_tween()
	tween.tween_property(_combo_label, "position:y", 66.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_combo_label, "modulate:a", 0.0, 0.34)
	tween.finished.connect(func() -> void:
		if _combo_label:
			_combo_label.visible = false
	)

func _show_near_miss_warning(matches_left: int) -> void:
	if _near_miss_label == null:
		return
	_near_miss_label.visible = true
	_near_miss_label.text = "Near miss: only %d moves left" % max(0, matches_left)
	_near_miss_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_near_miss_label, "modulate:a", 0.0, 0.42)
	tween.finished.connect(func() -> void:
		if _near_miss_label:
			_near_miss_label.visible = false
	)
	_kick_screen_shake(6.0)

func _kick_screen_shake(strength: float) -> void:
	_shake_strength = max(_shake_strength, strength)
	_shake_time_left = 0.12

func _maybe_show_micro_tutorial() -> void:
	if SaveStore.is_tutorial_seen():
		return
	call_deferred("_show_tutorial", false)

func _show_tutorial(force: bool = false) -> void:
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_layout_tutorial_overlay()
		return
	if not force and SaveStore.is_tutorial_seen():
		return
	if get_tree().paused or is_instance_valid(_audio_overlay):
		return
	_close_tutorial(false)
	_tutorial_step = 0
	_tutorial_overlay = Control.new()
	_tutorial_overlay.name = "TutorialOverlay"
	_tutorial_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_overlay.z_index = 80
	_tutorial_overlay.gui_input.connect(Callable(self, "_on_tutorial_gui_input"))
	$UI.add_child(_tutorial_overlay)

	_tutorial_panel = Panel.new()
	_tutorial_panel.name = "Panel"
	_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_panel.gui_input.connect(Callable(self, "_on_tutorial_gui_input"))
	TUTORIAL_TEMPLATE.style_panel(_tutorial_panel)
	_tutorial_overlay.add_child(_tutorial_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TUTORIAL_TEMPLATE.apply_margins(margin)
	_tutorial_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "VBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	_tutorial_title = Label.new()
	_tutorial_title.name = "Title"
	TUTORIAL_TEMPLATE.style_label(_tutorial_title, true)
	box.add_child(_tutorial_title)
	_tutorial_message = Label.new()
	_tutorial_message.name = "Message"
	TUTORIAL_TEMPLATE.style_label(_tutorial_message, false)
	box.add_child(_tutorial_message)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_theme_constant_override("separation", 14)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	_tutorial_skip_button = Button.new()
	_tutorial_skip_button.name = "Skip"
	_tutorial_skip_button.text = "Skip Tutorial"
	TUTORIAL_TEMPLATE.style_button(_tutorial_skip_button, false)
	_tutorial_skip_button.pressed.connect(Callable(self, "_on_tutorial_skip_pressed"))
	buttons.add_child(_tutorial_skip_button)
	_tutorial_next_button = Button.new()
	_tutorial_next_button.name = "Next"
	_tutorial_next_button.text = "Next"
	TUTORIAL_TEMPLATE.style_button(_tutorial_next_button, true)
	_tutorial_next_button.pressed.connect(Callable(self, "_on_tutorial_next_pressed"))
	buttons.add_child(_tutorial_next_button)
	_update_tutorial_step()
	_layout_tutorial_overlay()
	_play_tutorial_step_motion()

func _on_tutorial_next_pressed() -> void:
	_advance_tutorial_step()

func _on_tutorial_gui_input(event: InputEvent) -> void:
	if not _is_tutorial_click_to_continue_step():
		return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touch: bool = event is InputEventScreenTouch and event.pressed
	if not click and not touch:
		return
	get_viewport().set_input_as_handled()
	_advance_tutorial_step()

func _advance_tutorial_step() -> void:
	if _tutorial_step >= TUTORIAL_STEP_COUNT - 1:
		_close_tutorial(true)
		return
	_tutorial_step += 1
	_update_tutorial_step()
	_layout_tutorial_overlay()
	_play_tutorial_step_motion()

func _on_tutorial_skip_pressed() -> void:
	_close_tutorial(true)

func _hide_tutorial_for_overlay() -> void:
	if _tutorial_overlay == null or not is_instance_valid(_tutorial_overlay):
		return
	_close_tutorial(false)

func _close_tutorial(mark_seen: bool) -> void:
	_clear_tutorial_highlights()
	if _tutorial_motion_tween:
		_tutorial_motion_tween.kill()
	if _tutorial_focus_tween:
		_tutorial_focus_tween.kill()
	if _tutorial_focus_target and is_instance_valid(_tutorial_focus_target):
		_tutorial_focus_target.scale = Vector2.ONE
	_tutorial_motion_tween = null
	_tutorial_focus_tween = null
	_tutorial_focus_target = null
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.queue_free()
	_tutorial_overlay = null
	_tutorial_panel = null
	_tutorial_title = null
	_tutorial_message = null
	_tutorial_next_button = null
	_tutorial_skip_button = null
	if powerups_row:
		powerups_row.visible = true
	if mark_seen:
		SaveStore.set_tutorial_seen(true)

func _update_tutorial_step() -> void:
	if _tutorial_title == null or _tutorial_message == null or _tutorial_next_button == null:
		return
	var title := ""
	var message := ""
	match _tutorial_step:
		0:
			title = "Swipe to Crunch"
			message = "Swipe any direction. Matching color tiers slide together and climb the ladder.\nThis lesson advances after your first move."
		1:
			title = "Read the Colors"
			message = "The word on each brick is its color tier. Mint looks mint, Sky looks sky, and Solar glows warm."
		TUTORIAL_STEP_UNDO:
			title = "Undo"
			message = "Undo rewinds your last swipe when the board turns against you."
		TUTORIAL_STEP_PRISM:
			title = "Prism"
			message = "Prism clears one color tier and gives the board breathing room."
		TUTORIAL_STEP_SHUFFLE:
			title = "Shuffle"
			message = "Shuffle rearranges the board when the next merge is hard to see."
		TUTORIAL_STEP_DONE:
			title = "You're Set"
			message = "Swipe fast, keep chains alive, and replay this from Pause any time."
	_tutorial_title.text = title
	_tutorial_message.text = message
	if _tutorial_step >= TUTORIAL_STEP_COUNT - 1:
		_tutorial_next_button.text = "Done"
	elif _is_tutorial_click_to_continue_step():
		_tutorial_next_button.text = "Tap Anywhere"
	else:
		_tutorial_next_button.text = "Next"
	_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if _is_tutorial_click_to_continue_step() else Control.MOUSE_FILTER_IGNORE
	if powerups_row:
		powerups_row.visible = _tutorial_step >= TUTORIAL_STEP_UNDO
	_refresh_tutorial_highlights()

func _layout_tutorial_overlay() -> void:
	if _tutorial_panel == null:
		return
	var view_size: Vector2 = get_viewport_rect().size
	var top_limit: float = _tutorial_top_limit()
	var bottom_limit: float = view_size.y - 18.0
	if powerups_row and powerups_row.visible:
		bottom_limit = min(bottom_limit, powerups_row.global_position.y - 18.0)
	var board_rect := Rect2()
	if board:
		board_rect = Rect2(
			board.global_position,
			Vector2(float(board.width) * board.tile_size, float(board.height) * board.tile_size)
		)
	var layout: Dictionary = TUTORIAL_TEMPLATE.layout_panel({
		"view_size": view_size,
		"board_rect": board_rect,
		"top_limit": top_limit,
		"bottom_limit": bottom_limit,
		"early_step": _tutorial_step <= 1,
		"powerup_step": _is_tutorial_powerup_step(),
		"message": _tutorial_message.text if _tutorial_message else "",
	})
	_tutorial_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tutorial_panel.position = layout["position"]
	_tutorial_panel.size = layout["size"]
	_tutorial_panel.pivot_offset = _tutorial_panel.size * 0.5
	if _tutorial_next_button:
		_tutorial_next_button.pivot_offset = _tutorial_next_button.size * 0.5
	if _tutorial_skip_button:
		_tutorial_skip_button.pivot_offset = _tutorial_skip_button.size * 0.5
	_refresh_tutorial_highlights()

func _tutorial_top_limit() -> float:
	var top_limit: float = 18.0
	if top_bar_bg:
		top_limit = max(top_limit, top_bar_bg.global_position.y + top_bar_bg.size.y + 14.0)
	return top_limit

func _refresh_tutorial_highlights() -> void:
	_clear_tutorial_highlights()
	if _tutorial_overlay == null:
		return
	if _tutorial_step <= 1:
		_set_tutorial_focus_target(null)
		_add_board_merge_highlights()
	else:
		var target: Control = _tutorial_powerup_target()
		_set_tutorial_focus_target(target)
		if target:
			_add_control_highlight(target)
	if _tutorial_panel and is_instance_valid(_tutorial_panel):
		_tutorial_overlay.move_child(_tutorial_panel, _tutorial_overlay.get_child_count() - 1)

func _add_board_merge_highlights() -> void:
	if board == null or board.board == null:
		return
	var group: Array = _tutorial_merge_cells()
	var limit: int = min(group.size(), 4)
	for i in range(limit):
		var cell: Vector2i = group[i]
		var origin: Vector2 = board.global_position + (Vector2(float(cell.x), float(cell.y)) * board.tile_size)
		_add_highlight_rect(Rect2(origin + Vector2(2, 2), Vector2(board.tile_size - 4, board.tile_size - 4)), i + 1)

func _tutorial_merge_cells() -> Array:
	if board == null or board.board == null:
		return []
	for y in range(board.height):
		for x in range(board.width):
			var level: int = int(board.board.grid[y][x])
			if level <= 0:
				continue
			if x + 1 < board.width and int(board.board.grid[y][x + 1]) == level:
				return [Vector2i(x, y), Vector2i(x + 1, y)]
			if y + 1 < board.height and int(board.board.grid[y + 1][x]) == level:
				return [Vector2i(x, y), Vector2i(x, y + 1)]
	return []

func _add_control_highlight(control: Control) -> void:
	if control == null:
		return
	_add_highlight_rect(control.get_global_rect().grow(10.0), 0)

func _play_tutorial_step_motion() -> void:
	if _tutorial_panel == null or not is_instance_valid(_tutorial_panel):
		return
	if _tutorial_motion_tween:
		_tutorial_motion_tween.kill()
	_tutorial_panel.pivot_offset = _tutorial_panel.size * 0.5
	_tutorial_panel.scale = Vector2(0.96, 0.96)
	_tutorial_panel.modulate = Color(1, 1, 1, 0.92)
	_tutorial_motion_tween = _tutorial_panel.create_tween()
	_tutorial_motion_tween.set_parallel(true)
	_tutorial_motion_tween.tween_property(_tutorial_panel, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tutorial_motion_tween.tween_property(_tutorial_panel, "modulate:a", 1.0, 0.08)
	_tutorial_motion_tween.chain().tween_property(_tutorial_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_tutorial_focus_target(target: Control) -> void:
	if _tutorial_focus_tween:
		_tutorial_focus_tween.kill()
	if _tutorial_focus_target and is_instance_valid(_tutorial_focus_target):
		_tutorial_focus_target.scale = Vector2.ONE
	_tutorial_focus_target = target
	if target == null or not is_instance_valid(target):
		_tutorial_focus_tween = null
		return
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2.ONE
	_tutorial_focus_tween = target.create_tween()
	_tutorial_focus_tween.set_loops()
	_tutorial_focus_tween.tween_property(target, "scale", Vector2(1.10, 1.10), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tutorial_focus_tween.tween_property(target, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _is_tutorial_powerup_step() -> bool:
	return _tutorial_step == TUTORIAL_STEP_UNDO or _tutorial_step == TUTORIAL_STEP_PRISM or _tutorial_step == TUTORIAL_STEP_SHUFFLE

func _is_tutorial_click_to_continue_step() -> bool:
	return _tutorial_step >= TUTORIAL_STEP_UNDO

func _tutorial_powerup_target() -> Control:
	match _tutorial_step:
		TUTORIAL_STEP_UNDO:
			return undo_button
		TUTORIAL_STEP_PRISM:
			return remove_color_button
		TUTORIAL_STEP_SHUFFLE:
			return shuffle_button
	return null

func _add_highlight_rect(rect: Rect2, index: int) -> void:
	var highlight := Panel.new()
	highlight.name = "Highlight"
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TUTORIAL_TEMPLATE.style_highlight(highlight)
	highlight.set_anchors_preset(Control.PRESET_TOP_LEFT)
	highlight.global_position = rect.position
	highlight.size = rect.size
	highlight.pivot_offset = highlight.size * 0.5
	_tutorial_overlay.add_child(highlight)
	_tutorial_highlights.append(highlight)
	_pulse_tutorial_highlight(highlight, index)
	if index <= 0:
		return
	var marker := Label.new()
	marker.text = str(index)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", Typography.px(22.0))
	marker.add_theme_color_override("font_color", Color(0.04, 0.12, 0.18, 1.0))
	marker.set_anchors_preset(Control.PRESET_TOP_LEFT)
	marker.global_position = rect.position + Vector2(6, 6)
	marker.size = Vector2(34, 34)
	marker.pivot_offset = marker.size * 0.5
	_tutorial_overlay.add_child(marker)
	_tutorial_highlights.append(marker)

func _pulse_tutorial_highlight(highlight: Control, index: int) -> void:
	if _tutorial_overlay == null or not is_instance_valid(_tutorial_overlay):
		return
	highlight.scale = Vector2(0.94, 0.94)
	var pulse := highlight.create_tween()
	pulse.set_loops()
	var delay: float = float(max(index, 0)) * 0.04
	if delay > 0.0:
		pulse.tween_interval(delay)
	pulse.tween_property(highlight, "scale", Vector2(1.08, 1.08), 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(highlight, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _clear_tutorial_highlights() -> void:
	for node in _tutorial_highlights:
		if node and is_instance_valid(node):
			node.queue_free()
	_tutorial_highlights.clear()

func _apply_difficulty_curve() -> void:
	# Gentle curve: higher score trims remaining time cushion and keeps pressure up.
	var curve: float = clamp(float(score) / 2200.0, 0.0, 1.0)
	var max_time: float = ROUND_LIMIT_SECONDS + lerp(12.0, 6.0, curve)
	_round_time_left = min(_round_time_left, max_time)
