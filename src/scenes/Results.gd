extends Control

const AUDIO_TRACK_OVERLAY_SCENE := preload("res://src/scenes/AudioTrackOverlay.tscn")
const ICON_MUSIC_ON: Texture2D = preload("res://assets/ui/icons/atlas/music_on.tres")
const ICON_MUSIC_OFF: Texture2D = preload("res://assets/ui/icons/atlas/music_off.tres")

@onready var kicker_label: Label = $UI/Panel/Scroll/VBox/Kicker
@onready var title_label: Label = $UI/Panel/Scroll/VBox/Title
@onready var ui_root: Control = $UI
@onready var top_right_bar: Control = $UI/TopRightBar
@onready var audio_button: Button = $UI/TopRightBar/Audio
@onready var stats_split: GridContainer = $UI/Panel/Scroll/VBox/StatsSplit
@onready var stats_left_column: VBoxContainer = $UI/Panel/Scroll/VBox/StatsSplit/LeftColumn
@onready var stats_right_column: VBoxContainer = $UI/Panel/Scroll/VBox/StatsSplit/RightColumn
@onready var score_label: Label = $UI/Panel/Scroll/VBox/StatsSplit/LeftColumn/Score
@onready var mode_badge_label: Label = $UI/Panel/Scroll/VBox/StatsSplit/LeftColumn/ModeBadge
@onready var best_label: Label = $UI/Panel/Scroll/VBox/StatsSplit/LeftColumn/Best
@onready var streak_label: Label = $UI/Panel/Scroll/VBox/StatsSplit/LeftColumn/Streak
@onready var online_status_label: Label = $UI/Panel/Scroll/VBox/StatsSplit/RightColumn/OnlineStatus
@onready var leaderboard_label: Label = $UI/Panel/Scroll/VBox/StatsSplit/RightColumn/Leaderboard
@onready var coins_earned_label: Label = $UI/Panel/Scroll/VBox/CoinsEarned
@onready var coin_balance_label: Label = $UI/Panel/Scroll/VBox/CoinBalance
@onready var double_reward_button: Button = $UI/Panel/Scroll/VBox/DoubleReward
@onready var panel: Control = $UI/Panel
@onready var scroll: ScrollContainer = $UI/Panel/Scroll
@onready var box: VBoxContainer = $UI/Panel/Scroll/VBox
@onready var play_again_button: Button = $UI/Panel/Scroll/VBox/PlayAgain
@onready var menu_button: Button = $UI/Panel/Scroll/VBox/Menu
@onready var spacer: Control = $UI/Panel/Scroll/VBox/Spacer

var _base_reward_claimed: bool = false
var _double_reward_pending: bool = false
var _base_reward_amount: int = 0
var _audio_overlay: AudioTrackOverlay
var _powerups_label: Label
var _encouragement_label: Label
var _unlock_progress: ProgressBar
var _dual_leaderboard_label: Label
var _weekly_ladder_label: Label
var _rival_target_label: Label
var _grade_label: Label
var _rival_progress: ProgressBar
var _reward_cards: GridContainer
var _best_reward_label: Label
var _coins_reward_label: Label
var _streak_reward_label: Label

func _ready() -> void:
	BackgroundMood.register_controller($BackgroundController)
	BackgroundMood.set_mood(BackgroundMood.Mood.CALM)
	MusicManager.fade_to_calm(0.6)
	VisualTestMode.apply_if_enabled($BackgroundController, $BackgroundController)
	Typography.style_results(self)
	ThemeManager.apply_to_scene(self)
	_ensure_dynamic_stats()
	_apply_results_copy()
	_apply_color_crunch_results_style()
	_refresh_audio_icon()
	_refresh_intro_pivots()
	_update_labels()
	_layout_results()
	call_deferred("_layout_results")
	_bind_online_signals()
	_sync_online_results()
	_sync_wallet_rewards()
	_play_intro()
	if StreakManager.is_streak_at_risk():
		var modal := preload("res://src/scenes/SaveStreakModal.tscn").instantiate()
		add_child(modal)
	if not AdManager.is_connected("rewarded_powerup_earned", Callable(self, "_on_double_reward_ad_earned")):
		AdManager.connect("rewarded_powerup_earned", Callable(self, "_on_double_reward_ad_earned"))
	Telemetry.mark_scene_loaded("results", Time.get_ticks_msec() - 1)

func _update_labels() -> void:
	score_label.text = "%d" % RunManager.last_score
	mode_badge_label.text = "%s MODE" % _mode_label().to_upper()
	var local_best: int = int(SaveStore.data["high_score"])
	var online_record: Dictionary = NakamaService.get_my_high_score()
	var online_best: int = int(online_record.get("score", 0))
	var online_rank: int = int(online_record.get("rank", 0))
	var best_value: int = max(local_best, online_best)
	if title_label:
		title_label.text = _results_title(best_value)
	if online_best > 0 and online_rank > 0:
		best_label.text = "Best %d  Global #%d" % [best_value, online_rank]
	else:
		best_label.text = "Best %d" % best_value
	streak_label.text = "Streak %d days" % StreakManager.get_streak_days()
	online_status_label.text = "Sync %s" % NakamaService.get_online_status()
	leaderboard_label.text = _format_leaderboard(NakamaService.get_leaderboard_records())
	if _powerups_label:
		_powerups_label.text = "Power-ups %d" % RunManager.last_run_powerups_used
	if _encouragement_label:
		_encouragement_label.text = _build_encouragement_text(local_best, best_value)
	if _unlock_progress:
		_unlock_progress.value = SaveStore.get_unlock_progress() * 100.0
	if _grade_label:
		_grade_label.text = _build_grade_text(best_value)
	if _rival_progress:
		_rival_progress.value = _rival_progress_value()
	if _dual_leaderboard_label:
		_dual_leaderboard_label.text = ""
	_refresh_reward_cards()
	_update_social_labels()
	coin_balance_label.text = "Vault %d" % NakamaService.get_coin_balance()
	if _base_reward_claimed:
		coins_earned_label.text = "Coins +%d" % _base_reward_amount
	else:
		coins_earned_label.text = "Coins pending"
	_layout_results()

func _results_title(best_value: int) -> String:
	if RunManager.last_score > 0 and RunManager.last_score >= best_value:
		return "New Best Run"
	return "Run Complete"

func _on_play_again_pressed() -> void:
	_close_audio_overlay()
	AdManager.maybe_show_interstitial()
	RunManager.start_game()

func _on_menu_pressed() -> void:
	_close_audio_overlay()
	AdManager.maybe_show_interstitial()
	RunManager.goto_menu()

func _play_intro() -> void:
	var ui: CanvasItem = $UI
	var panel_item: CanvasItem = $UI/Panel
	var box_item: CanvasItem = box
	var play_again: CanvasItem = play_again_button
	var menu: CanvasItem = menu_button
	ui.modulate.a = 0.0
	panel_item.scale = Vector2(0.9, 0.9)
	box_item.scale = Vector2(0.95, 0.95)
	play_again.modulate.a = 0.0
	if menu_button and menu_button.visible:
		menu.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(ui, "modulate:a", 1.0, 0.28)
	t.parallel().tween_property(panel_item, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(box_item, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(play_again, "modulate:a", 1.0, 0.16)
	if menu_button and menu_button.visible:
		t.tween_property(menu, "modulate:a", 1.0, 0.16)

func _refresh_intro_pivots() -> void:
	if panel:
		panel.pivot_offset = panel.size * 0.5
	if box:
		box.pivot_offset = box.size * 0.5

func _layout_results() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if ui_root != null and ui_root.size.x > 0.0 and ui_root.size.y > 0.0:
		viewport_size = Vector2(max(viewport_size.x, ui_root.size.x), max(viewport_size.y, ui_root.size.y))
	_layout_results_for_size(viewport_size)

func _layout_results_for_size(viewport_size: Vector2) -> void:
	if panel == null or scroll == null or box == null:
		return
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var viewport_aspect: float = viewport_size.x / max(1.0, viewport_size.y)
	var is_wide: bool = viewport_aspect >= 1.45
	var is_ultra_wide: bool = viewport_aspect >= 1.9
	var is_wide_short: bool = is_wide and viewport_size.y <= 760.0
	var outer_margin_x: float = clamp(viewport_size.x * 0.032, 12.0, 56.0)
	var outer_margin_y: float = clamp(viewport_size.y * 0.026, 10.0, 32.0)
	var max_panel_width: float = max(360.0, viewport_size.x - (outer_margin_x * 2.0))
	var min_panel_width: float = min(460.0, max_panel_width)
	var width_ratio: float = 0.84
	if is_ultra_wide:
		width_ratio = 0.74
	elif is_wide_short:
		width_ratio = 0.88
	elif is_wide:
		width_ratio = 0.84
	var target_panel_width: float = viewport_size.x * width_ratio
	var panel_width_cap: float = 2600.0 if is_wide else 1280.0
	var panel_width: float = clamp(target_panel_width, min_panel_width, min(panel_width_cap, max_panel_width))
	var max_panel_height: float = max(320.0, viewport_size.y - (outer_margin_y * 2.0))
	var min_panel_height: float = min(420.0 if is_wide else 560.0, max_panel_height)
	var height_ratio: float = 0.72
	if is_wide_short:
		height_ratio = 0.74
	elif is_wide:
		height_ratio = 0.78
	var target_panel_height: float = viewport_size.y * height_ratio
	var panel_height: float = clamp(target_panel_height, min_panel_height, max_panel_height)
	var panel_size: Vector2 = Vector2(panel_width, panel_height)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var panel_x: float = (viewport_size.x - panel_size.x) * 0.5
	var panel_y: float = (viewport_size.y - panel_size.y) * (0.50 if is_wide else 0.47)
	panel.position = Vector2(panel_x, panel_y)
	panel.size = panel_size
	_layout_top_right(viewport_size)

	var margin_x: float = clamp(panel_size.x * 0.044, 16.0, 38.0)
	var margin_y: float = clamp(panel_size.y * 0.035, 12.0, 30.0)
	var content_size: Vector2 = panel_size - Vector2(margin_x * 2.0, margin_y * 2.0)
	var use_split: bool = viewport_aspect >= 1.35 and content_size.x >= 620.0
	_configure_stats_split(content_size, use_split)
	var compact_mode: bool = is_wide_short
	_set_compact_optional_rows(compact_mode)
	if _reward_cards:
		_reward_cards.columns = 3 if content_size.x >= 620.0 else 1
		_reward_cards.add_theme_constant_override("h_separation", int(clamp(round(content_size.x * 0.018), 8.0, 18.0)))
		_reward_cards.add_theme_constant_override("v_separation", int(clamp(round(content_size.y * 0.012), 6.0, 12.0)))
	if spacer:
		spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var base_separation: float = clamp(round(content_size.y * 0.008), 5.0, 13.0)
	var compact_scale: float = 1.0
	for _i in range(8):
		var separation_min: float = 3.0 if compact_mode else 5.0
		var separation: int = int(clamp(round(base_separation * compact_scale), separation_min, 13.0))
		box.add_theme_constant_override("separation", separation)
		_apply_responsive_typography(content_size, viewport_aspect, use_split, compact_scale, compact_mode)

		var secondary_min: float = 44.0 if compact_mode else 50.0
		var primary_min: float = 54.0 if compact_mode else 62.0
		var secondary_button_height: float = clamp(content_size.y * (0.092 if is_wide else 0.066) * compact_scale, secondary_min, 124.0)
		var primary_button_height: float = clamp(content_size.y * (0.132 if is_wide else 0.094) * compact_scale, primary_min, 140.0)
		if double_reward_button:
			double_reward_button.custom_minimum_size.y = secondary_button_height
		if play_again_button:
			play_again_button.custom_minimum_size.y = primary_button_height
		if menu_button and menu_button.visible:
			menu_button.custom_minimum_size.y = clamp(primary_button_height * 0.92, secondary_min, 122.0)
		if spacer:
			spacer.custom_minimum_size.y = max(0.0, round(content_size.y * (0.004 if compact_mode else 0.010) * compact_scale))

		var required_height: float = box.get_combined_minimum_size().y
		if required_height <= content_size.y:
			break
		if not compact_mode:
			compact_mode = true
			_set_compact_optional_rows(compact_mode)
			compact_scale = min(compact_scale, 0.78)
			continue
		var fit_ratio: float = content_size.y / max(1.0, required_height)
		var next_scale: float = clamp(compact_scale * fit_ratio, 0.58, compact_scale)
		if absf(next_scale - compact_scale) < 0.01:
			break
		compact_scale = next_scale

	scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scroll.position = Vector2(margin_x, margin_y)
	scroll.size = content_size

	box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	box.position = Vector2.ZERO
	var content_min_height: float = box.get_combined_minimum_size().y
	box.size = Vector2(content_size.x, max(content_size.y, content_min_height))
	box.alignment = BoxContainer.ALIGNMENT_BEGIN if compact_mode else BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(content_size.x, max(content_size.y, content_min_height))
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

func _layout_top_right(viewport_size: Vector2) -> void:
	if top_right_bar == null or audio_button == null:
		return
	var insets: Dictionary = SafeArea.get_insets()
	var safe_top: float = float(insets.get("top", 0.0))
	var safe_right: float = float(insets.get("right", 0.0))
	var margin: float = clamp(min(viewport_size.x, viewport_size.y) * 0.045, 12.0, 32.0)
	var icon_size: float = clamp(min(viewport_size.x, viewport_size.y) * 0.12, 68.0, 92.0)
	var target_x: float = viewport_size.x - safe_right - margin - icon_size
	var target_y: float = safe_top + margin
	if panel != null and panel.size.x > 0.0 and panel.size.y > 0.0:
		target_x = panel.position.x + panel.size.x - (icon_size * 0.20)
		target_y = max(safe_top + margin, panel.position.y - (icon_size * 0.88))
	top_right_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_right_bar.position = Vector2(target_x, target_y)
	top_right_bar.size = Vector2(icon_size, icon_size)
	audio_button.custom_minimum_size = Vector2(icon_size, icon_size)

func _configure_stats_split(content_size: Vector2, use_split: bool) -> void:
	if stats_split == null:
		return
	var separation: int = int(clamp(round(content_size.x * 0.03), 12.0, 28.0))
	stats_split.add_theme_constant_override("h_separation", separation)
	stats_split.add_theme_constant_override("v_separation", int(clamp(round(content_size.y * 0.015), 8.0, 16.0)))
	stats_split.columns = 2 if use_split else 1
	var column_width: float = max(160.0, (content_size.x - float(separation)) * 0.5) if use_split else content_size.x
	if stats_left_column:
		stats_left_column.custom_minimum_size.x = column_width
	if stats_right_column:
		stats_right_column.custom_minimum_size.x = column_width if use_split else content_size.x
	var left_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT if use_split else HORIZONTAL_ALIGNMENT_CENTER
	var right_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT if use_split else HORIZONTAL_ALIGNMENT_CENTER
	if kicker_label:
		kicker_label.horizontal_alignment = left_alignment
	if title_label:
		title_label.horizontal_alignment = left_alignment
	for label in [score_label, mode_badge_label, best_label, streak_label]:
		if label:
			label.horizontal_alignment = left_alignment
	if online_status_label:
		online_status_label.horizontal_alignment = right_alignment
	if leaderboard_label:
		leaderboard_label.horizontal_alignment = right_alignment
	for label in [coins_earned_label, coin_balance_label, _powerups_label, _encouragement_label, _weekly_ladder_label, _rival_target_label, _dual_leaderboard_label, _grade_label]:
		if label:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _apply_responsive_typography(content_size: Vector2, viewport_aspect: float, use_split: bool, compact_scale: float = 1.0, compact_mode: bool = false) -> void:
	var is_wide: bool = viewport_aspect >= 1.45
	var headline_scale: float = compact_scale
	var action_scale: float = compact_scale
	var split_gap: float = 20.0
	if stats_split:
		split_gap = float(stats_split.get_theme_constant("h_separation"))
	var stat_column_width: float = max(220.0, (content_size.x - split_gap) * 0.5) if use_split else content_size.x
	var menu_title_px: int = Typography.px(Typography.SIZE_MENU_TITLE)
	var menu_button_px: int = Typography.px(Typography.SIZE_BUTTON)
	var kicker_min: float = 17.0 if compact_mode else 14.0
	var title_min: float = 40.0 if compact_mode else 36.0
	var score_min: float = 78.0 if compact_mode else 58.0
	var mode_min: float = 18.0 if compact_mode else 16.0
	var stat_min: float = 22.0 if compact_mode else 18.0
	var body_min: float = 20.0 if compact_mode else 15.0
	var coin_min: float = 20.0 if compact_mode else 15.0
	var reward_min: float = 20.0 if compact_mode else 16.0
	var primary_min: float = 24.0 if compact_mode else 20.0
	var compact_body_boost: float = 1.08 if compact_mode else 1.0
	var kicker_size: int = int(round(clamp(float(menu_button_px) * (0.48 if compact_mode else 0.38) * compact_scale, kicker_min, 30.0)))
	var title_size: int = int(round(clamp(float(menu_title_px) * (0.68 if compact_mode else 0.60) * headline_scale, title_min, 96.0)))
	var score_size: int = int(round(clamp(max(float(menu_title_px) * 0.84, stat_column_width * 0.16) * headline_scale, score_min, 138.0)))
	var mode_size: int = int(round(clamp(float(menu_button_px) * 0.56 * compact_scale * compact_body_boost, mode_min, 36.0)))
	var stat_size: int = int(round(clamp(float(menu_button_px) * 0.64 * compact_scale * compact_body_boost, stat_min, 44.0)))
	var body_size: int = int(round(clamp(float(menu_button_px) * 0.54 * compact_scale * compact_body_boost, body_min, 34.0)))
	var coin_size: int = int(round(clamp(float(menu_button_px) * 0.56 * compact_scale * compact_body_boost, coin_min, 36.0)))
	var reward_button_size: int = int(round(clamp(float(menu_button_px) * 0.58 * action_scale * compact_body_boost, reward_min, 36.0)))
	var primary_button_size: int = int(round(clamp(float(menu_button_px) * (0.68 if is_wide else 0.66) * action_scale * compact_body_boost, primary_min, 44.0)))

	if kicker_label:
		kicker_label.add_theme_font_size_override("font_size", kicker_size)
	if title_label:
		title_label.add_theme_font_size_override("font_size", title_size)
	if score_label:
		score_label.add_theme_font_size_override("font_size", score_size)
	if mode_badge_label:
		mode_badge_label.add_theme_font_size_override("font_size", mode_size)
	if best_label:
		best_label.add_theme_font_size_override("font_size", stat_size)
	if streak_label:
		streak_label.add_theme_font_size_override("font_size", stat_size)
	if online_status_label:
		online_status_label.add_theme_font_size_override("font_size", body_size)
	if leaderboard_label:
		leaderboard_label.add_theme_font_size_override("font_size", body_size)
		leaderboard_label.add_theme_constant_override("line_spacing", int(clamp(round(float(body_size) * 0.30), 4.0, 10.0)))
	if coins_earned_label:
		coins_earned_label.add_theme_font_size_override("font_size", coin_size)
	if coin_balance_label:
		coin_balance_label.add_theme_font_size_override("font_size", coin_size)
	if _powerups_label:
		_powerups_label.add_theme_font_size_override("font_size", body_size)
	if _encouragement_label:
		_encouragement_label.add_theme_font_size_override("font_size", body_size)
	if _dual_leaderboard_label:
		_dual_leaderboard_label.add_theme_font_size_override("font_size", int(round(body_size * 0.92)))
	if _weekly_ladder_label:
		_weekly_ladder_label.add_theme_font_size_override("font_size", int(round(body_size * 0.96)))
	if _rival_target_label:
		_rival_target_label.add_theme_font_size_override("font_size", int(round(body_size * 0.94)))
	if _grade_label:
		_grade_label.add_theme_font_size_override("font_size", int(round(body_size * 1.08)))
	if _rival_progress:
		_rival_progress.custom_minimum_size.y = clamp(content_size.y * 0.022 * compact_scale, 12.0, 22.0)
	for reward_label in [_best_reward_label, _coins_reward_label, _streak_reward_label]:
		if reward_label:
			reward_label.add_theme_font_size_override("font_size", int(round(body_size * (1.0 if compact_mode else 0.92))))
			var card_height: float = clamp(content_size.y * (0.13 if is_wide else 0.095) * compact_scale, 72.0, 118.0)
			reward_label.custom_minimum_size.y = card_height
	if double_reward_button:
		double_reward_button.add_theme_font_size_override("font_size", reward_button_size)
	if play_again_button:
		play_again_button.add_theme_font_size_override("font_size", primary_button_size)
	if menu_button and menu_button.visible:
		menu_button.add_theme_font_size_override("font_size", primary_button_size)

func _bind_online_signals() -> void:
	if not NakamaService.online_state_changed.is_connected(_on_online_state_changed):
		NakamaService.online_state_changed.connect(_on_online_state_changed)
	if not NakamaService.high_score_updated.is_connected(_on_high_score_updated):
		NakamaService.high_score_updated.connect(_on_high_score_updated)
	if not NakamaService.leaderboard_updated.is_connected(_on_leaderboard_updated):
		NakamaService.leaderboard_updated.connect(_on_leaderboard_updated)

func _on_online_state_changed(status: String) -> void:
	online_status_label.text = "Sync %s" % status

func _on_high_score_updated(_record: Dictionary) -> void:
	_update_labels()

func _on_leaderboard_updated(records: Array) -> void:
	leaderboard_label.text = _format_leaderboard(records)

func _sync_online_results() -> void:
	var mode: String = String(RunManager.last_run_leaderboard_mode).strip_edges().to_upper()
	if mode.is_empty():
		mode = "PURE"
	await LeaderboardService.submit_and_refresh(RunManager.last_score, {
		"source": "results_ready",
		"run_id": RunManager.last_run_id,
		"powerup_breakdown": RunManager.last_run_powerup_breakdown.duplicate(true),
	}, mode, RunManager.last_run_powerups_used, RunManager.last_run_coins_spent, RunManager.last_run_id, RunManager.last_run_duration_ms)
	var alternate_mode := "OPEN" if mode == "PURE" else "PURE"
	var alt_result := await NakamaService.refresh_leaderboard(3, alternate_mode)
	if _dual_leaderboard_label and alt_result.get("ok", false):
		_dual_leaderboard_label.text = _format_alt_mode_leaderboard(alternate_mode, NakamaService.get_leaderboard_records())
	await NakamaService.refresh_leaderboard(5, mode)

func _sync_wallet_rewards() -> void:
	await NakamaService.refresh_wallet(false)
	var run_id: String = RunManager.last_run_id
	if run_id.is_empty():
		run_id = "cc-run-fallback-%d" % Time.get_unix_time_from_system()
	var claim: Dictionary = await NakamaService.claim_run_reward(
		RunManager.last_score,
		StreakManager.get_streak_days(),
		RunManager.last_run_completed_by_gameplay,
		false,
		run_id
	)
	if claim.get("ok", false):
		var data: Dictionary = claim.get("data", {})
		_base_reward_claimed = bool(data.get("granted", false))
		_base_reward_amount = int(data.get("rewardCoins", 0))
	coin_balance_label.text = "Vault %d" % NakamaService.get_coin_balance()
	coins_earned_label.text = "Coins +%d" % _base_reward_amount
	double_reward_button.disabled = not RunManager.last_run_completed_by_gameplay
	_refresh_reward_cards()

func _on_double_reward_pressed() -> void:
	if not RunManager.last_run_completed_by_gameplay:
		return
	if _base_reward_amount <= 0:
		return
	_double_reward_pending = true
	double_reward_button.disabled = true
	double_reward_button.text = "Loading ad..."
	if not AdManager.show_rewarded_for_powerup():
		_double_reward_pending = false
		double_reward_button.disabled = false
		double_reward_button.text = "Double Coins"

func _on_double_reward_ad_earned() -> void:
	if not _double_reward_pending:
		return
	_double_reward_pending = false
	var claim: Dictionary = await NakamaService.claim_run_reward(
		RunManager.last_score,
		StreakManager.get_streak_days(),
		RunManager.last_run_completed_by_gameplay,
		false,
		RunManager.last_run_id + ":double"
	)
	if claim.get("ok", false):
		var data: Dictionary = claim.get("data", {})
		var extra: int = int(data.get("rewardCoins", 0))
		_base_reward_amount += extra
	coins_earned_label.text = "Coins +%d" % _base_reward_amount
	coin_balance_label.text = "Vault %d" % NakamaService.get_coin_balance()
	double_reward_button.text = "Coins Doubled"
	_refresh_reward_cards()

func _format_leaderboard(records: Array) -> String:
	var mode_label := _mode_label()
	if records.is_empty():
		return "%s leaderboard\nWaiting for records" % mode_label
	var lines: Array[String] = []
	var count: int = min(records.size(), 3)
	for i in range(count):
		var item: Variant = records[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		var rank: int = int(row.get("rank", i + 1))
		var username: String = str(row.get("username", "Player"))
		var score: int = int(row.get("score", 0))
		lines.append("%d. %s - %d" % [rank, username, score])
	return "%s leaderboard\n%s" % [mode_label, "\n".join(lines)]

func _mode_label() -> String:
	return "Pure" if String(RunManager.last_run_leaderboard_mode).to_upper() == "PURE" else "Open"

func _on_audio_pressed() -> void:
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

func _ensure_dynamic_stats() -> void:
	if box == null:
		return
	if _powerups_label == null:
		_powerups_label = Label.new()
		_powerups_label.name = "PowerupsUsed"
		_powerups_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_powerups_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(_powerups_label)
		_move_before_spacer(_powerups_label)
	if _encouragement_label == null:
		_encouragement_label = Label.new()
		_encouragement_label.name = "Encouragement"
		_encouragement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_encouragement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_encouragement_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 0.96))
		box.add_child(_encouragement_label)
		_move_before_spacer(_encouragement_label)
	if _unlock_progress == null:
		_unlock_progress = ProgressBar.new()
		_unlock_progress.name = "UnlockProgress"
		_unlock_progress.min_value = 0.0
		_unlock_progress.max_value = 100.0
		_unlock_progress.value = 0.0
		_unlock_progress.custom_minimum_size.y = 22.0
		_unlock_progress.show_percentage = false
		_unlock_progress.add_theme_stylebox_override("background", _progress_style(Color(0.18, 0.28, 0.38, 0.40)))
		_unlock_progress.add_theme_stylebox_override("fill", _progress_style(Color(0.50, 0.96, 0.62, 0.92)))
		box.add_child(_unlock_progress)
		_move_before_spacer(_unlock_progress)
	if _dual_leaderboard_label == null:
		_dual_leaderboard_label = Label.new()
		_dual_leaderboard_label.name = "AltLeaderboard"
		_dual_leaderboard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dual_leaderboard_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(_dual_leaderboard_label)
		_move_before_spacer(_dual_leaderboard_label)
	if _weekly_ladder_label == null:
		_weekly_ladder_label = Label.new()
		_weekly_ladder_label.name = "WeeklyLadder"
		_weekly_ladder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_weekly_ladder_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_weekly_ladder_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 0.96))
		box.add_child(_weekly_ladder_label)
		_move_before_spacer(_weekly_ladder_label)
	if _rival_target_label == null:
		_rival_target_label = Label.new()
		_rival_target_label.name = "WeeklyRival"
		_rival_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rival_target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(_rival_target_label)
		_move_before_spacer(_rival_target_label)
	if _grade_label == null:
		_grade_label = Label.new()
		_grade_label.name = "RunGrade"
		_grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_grade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_grade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(_grade_label)
		_move_before_spacer(_grade_label)
	if _rival_progress == null:
		_rival_progress = ProgressBar.new()
		_rival_progress.name = "RivalProgress"
		_rival_progress.min_value = 0.0
		_rival_progress.max_value = 100.0
		_rival_progress.value = 0.0
		_rival_progress.show_percentage = false
		_rival_progress.custom_minimum_size.y = 18.0
		_rival_progress.add_theme_stylebox_override("background", _progress_style(Color(0.18, 0.28, 0.38, 0.42)))
		_rival_progress.add_theme_stylebox_override("fill", _progress_style(Color(0.46, 0.88, 0.96, 0.96)))
		box.add_child(_rival_progress)
		_move_before_spacer(_rival_progress)
	if _reward_cards == null:
		_reward_cards = GridContainer.new()
		_reward_cards.name = "RewardCards"
		_reward_cards.columns = 3
		_reward_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_reward_cards.add_theme_constant_override("h_separation", 12)
		_reward_cards.add_theme_constant_override("v_separation", 8)
		box.add_child(_reward_cards)
		_move_before_spacer(_reward_cards)
		_best_reward_label = _make_reward_card("BestReward", Color(1.0, 0.86, 0.34, 1.0))
		_coins_reward_label = _make_reward_card("CoinsReward", Color(0.50, 0.96, 0.62, 1.0))
		_streak_reward_label = _make_reward_card("StreakReward", Color(0.93, 0.48, 0.97, 1.0))
		_reward_cards.add_child(_best_reward_label)
		_reward_cards.add_child(_coins_reward_label)
		_reward_cards.add_child(_streak_reward_label)
	_apply_color_crunch_results_style()

func _move_before_spacer(node: Control) -> void:
	if box == null or spacer == null:
		return
	var spacer_index: int = spacer.get_index()
	box.move_child(node, max(0, spacer_index))

func _set_compact_optional_rows(compact_mode: bool) -> void:
	if _encouragement_label:
		_encouragement_label.visible = not compact_mode
	if _unlock_progress:
		_unlock_progress.visible = not compact_mode
	if _dual_leaderboard_label:
		_dual_leaderboard_label.visible = not compact_mode
	if _weekly_ladder_label:
		_weekly_ladder_label.visible = not compact_mode
	if _rival_target_label:
		_rival_target_label.visible = not compact_mode
	if _grade_label:
		_grade_label.visible = true
	if _rival_progress:
		_rival_progress.visible = true
	if _reward_cards:
		_reward_cards.visible = true

func _build_encouragement_text(_local_best: int, best_value: int) -> String:
	if best_value <= 0:
		return "Great start. Keep chaining to build longer runs."
	if RunManager.last_score >= best_value:
		return "New benchmark set. Keep the streak alive."
	var delta: int = max(0, best_value - RunManager.last_score)
	if delta <= 128:
		return "You were close! Only %d away from best." % delta
	return "Strong run. %d points to beat your best." % delta

func _build_grade_text(best_value: int) -> String:
	var target: int = max(1, int(RunManager.get_rival_snapshot().get("target_before", RunManager.get_active_rival_target())))
	var ratio: float = float(RunManager.last_score) / float(target)
	var grade: String = "C"
	if ratio >= 1.0:
		grade = "S"
	elif ratio >= 0.82:
		grade = "A"
	elif ratio >= 0.55:
		grade = "B"
	var best_suffix: String = "  New best" if best_value > 0 and RunManager.last_score >= best_value else ""
	return "Grade %s / Rival %d%%%s" % [grade, int(round(clamp(ratio, 0.0, 1.0) * 100.0)), best_suffix]

func _rival_progress_value() -> float:
	var target: int = max(1, int(RunManager.get_rival_snapshot().get("target_before", RunManager.get_active_rival_target())))
	return clamp(float(RunManager.last_score) / float(target), 0.0, 1.0) * 100.0

func _refresh_reward_cards() -> void:
	var local_best: int = int(SaveStore.data["high_score"])
	var online_best: int = int(NakamaService.get_my_high_score().get("score", 0))
	if _best_reward_label:
		_best_reward_label.text = "Best %d" % max(local_best, online_best)
	if _coins_reward_label:
		_coins_reward_label.text = "Coins +%d" % _base_reward_amount
	if _streak_reward_label:
		_streak_reward_label.text = "Streak %d" % StreakManager.get_streak_days()

func _make_reward_card(node_name: String, accent: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.custom_minimum_size = Vector2(0.0, 64.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Typography.style_label(label, 18.0, Typography.WEIGHT_BOLD)
	label.add_theme_color_override("font_color", accent)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.12, 0.18, 0.92))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_stylebox_override("normal", _card_style(accent, 0.54))
	return label

func _apply_results_copy() -> void:
	if kicker_label:
		kicker_label.text = "RUN RESULTS"
	if play_again_button:
		play_again_button.text = "Play Again"
	if menu_button:
		menu_button.text = "New Run"
		menu_button.visible = false
		menu_button.disabled = true
		menu_button.focus_mode = Control.FOCUS_NONE
		menu_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if double_reward_button:
		double_reward_button.text = "Double Coins"

func _apply_color_crunch_results_style() -> void:
	_style_glass_panel(panel as ColorRect)
	_style_button(play_again_button, "primary")
	_style_button(menu_button, "secondary")
	_style_button(double_reward_button, "reward")
	_style_button(audio_button, "icon")
	_style_results_labels()
	if _unlock_progress:
		_unlock_progress.add_theme_stylebox_override("background", _progress_style(Color(0.18, 0.28, 0.38, 0.40)))
		_unlock_progress.add_theme_stylebox_override("fill", _progress_style(Color(0.50, 0.96, 0.62, 0.92)))
	if _rival_progress:
		_rival_progress.add_theme_stylebox_override("background", _progress_style(Color(0.18, 0.28, 0.38, 0.42)))
		_rival_progress.add_theme_stylebox_override("fill", _progress_style(Color(0.46, 0.88, 0.96, 0.96)))
	if _best_reward_label:
		_best_reward_label.add_theme_stylebox_override("normal", _card_style(Color(1.0, 0.86, 0.34, 1.0), 0.54))
	if _coins_reward_label:
		_coins_reward_label.add_theme_stylebox_override("normal", _card_style(Color(0.50, 0.96, 0.62, 1.0), 0.54))
	if _streak_reward_label:
		_streak_reward_label.add_theme_stylebox_override("normal", _card_style(Color(0.93, 0.48, 0.97, 1.0), 0.54))

func _style_results_labels() -> void:
	var shadow := Color(0.08, 0.12, 0.18, 0.94)
	var primary := Color(1.0, 0.985, 0.92, 1.0)
	var soft := Color(0.84, 0.98, 0.96, 0.88)
	var muted := Color(0.74, 0.88, 0.92, 0.86)
	var sky := Color(0.72, 0.92, 1.0, 0.90)
	for label in [title_label, best_label, streak_label, online_status_label, leaderboard_label, coins_earned_label, coin_balance_label, _powerups_label, _encouragement_label, _dual_leaderboard_label, _weekly_ladder_label, _rival_target_label, _grade_label]:
		if label == null:
			continue
		label.add_theme_color_override("font_color", primary)
		label.add_theme_color_override("font_outline_color", shadow)
		label.add_theme_constant_override("outline_size", 3)
	for label in [best_label, streak_label, coins_earned_label, coin_balance_label, _powerups_label, _encouragement_label, _weekly_ladder_label, _rival_target_label, _dual_leaderboard_label]:
		if label:
			label.add_theme_color_override("font_color", soft)
	if kicker_label:
		kicker_label.add_theme_color_override("font_color", Color(0.54, 0.96, 0.86, 1.0))
		kicker_label.add_theme_color_override("font_outline_color", shadow)
		kicker_label.add_theme_constant_override("outline_size", 2)
	if score_label:
		score_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.46, 1.0))
		score_label.add_theme_color_override("font_outline_color", Color(0.16, 0.10, 0.02, 0.96))
		score_label.add_theme_constant_override("outline_size", 4)
	if mode_badge_label:
		mode_badge_label.add_theme_color_override("font_color", soft)
	if online_status_label:
		online_status_label.add_theme_color_override("font_color", muted)
	if leaderboard_label:
		leaderboard_label.add_theme_color_override("font_color", sky)
	if _grade_label:
		_grade_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34, 1.0))

func _style_glass_panel(node: ColorRect) -> void:
	if node == null:
		return
	var tint := Color(0.06, 0.20, 0.34, 0.74)
	var edge := Color(1.0, 0.96, 0.76, 0.58)
	node.color = tint
	if _has_property(node, "tint"):
		node.set("tint", tint)
	if _has_property(node, "edge"):
		node.set("edge", edge)
	if _has_property(node, "blur_radius"):
		node.set("blur_radius", 7.4)
	if _has_property(node, "edge_width"):
		node.set("edge_width", 1.35)
	if _has_property(node, "corner_radius"):
		node.set("corner_radius", 0.09)
	var mat := node.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("edge_highlight", edge)
	mat.set_shader_parameter("blur", 7.4)
	mat.set_shader_parameter("corner_radius", 0.09)
	mat.set_shader_parameter("edge_width", 1.35)
	mat.set_shader_parameter("chromatic_strength", 0.34)

func _style_button(button: BaseButton, role: String) -> void:
	if button == null:
		return
	var normal := _button_style(role)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.08)
	hover.border_color = normal.border_color.lightened(0.10)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.12)
	var disabled_style: StyleBoxFlat = normal.duplicate()
	disabled_style.bg_color = normal.bg_color.darkened(0.22)
	disabled_style.border_color = normal.border_color * Color(1.0, 1.0, 1.0, 0.55)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled_style)
	var dark_text := role == "primary"
	var font_color := Color(0.10, 0.08, 0.02, 1.0) if dark_text else Color(1.0, 0.985, 0.92, 1.0)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_focus_color", font_color)
	button.add_theme_color_override("font_disabled_color", Color(0.78, 0.90, 0.94, 0.82))
	button.add_theme_color_override("font_outline_color", Color(1.0, 0.90, 0.42, 0.42) if dark_text else Color(0.08, 0.12, 0.18, 0.94))
	button.add_theme_constant_override("outline_size", 1 if dark_text else 2)
	if _has_property(button, "tint"):
		button.set("tint", normal.bg_color)
	if _has_property(button, "edge_highlight"):
		button.set("edge_highlight", normal.border_color)
	if button.has_method("_sync_glass_state"):
		button.call_deferred("_sync_glass_state")

func _button_style(role: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.40, 0.72, 0.52)
	style.border_color = Color(0.78, 0.94, 1.0, 0.78)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.12, 0.52, 1.0, 0.20)
	style.shadow_size = 10
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.2
	match role:
		"primary":
			style.bg_color = Color(1.0, 0.84, 0.30, 0.98)
			style.border_color = Color(1.0, 0.96, 0.64, 1.0)
			style.shadow_color = Color(1.0, 0.62, 0.10, 0.40)
			style.shadow_size = 18
		"reward":
			style.bg_color = Color(0.40, 0.94, 0.68, 0.58)
			style.border_color = Color(0.68, 1.0, 0.74, 0.82)
			style.shadow_color = Color(0.20, 0.88, 0.48, 0.20)
		"icon":
			style.bg_color = Color(0.32, 0.78, 1.0, 0.32)
			style.border_color = Color(1.0, 1.0, 1.0, 0.62)
			style.corner_radius_top_left = 16
			style.corner_radius_top_right = 16
			style.corner_radius_bottom_left = 16
			style.corner_radius_bottom_right = 16
		_:
			style.bg_color = Color(0.22, 0.46, 0.76, 0.46)
			style.border_color = Color(0.84, 0.96, 1.0, 0.70)
	return style

func _card_style(accent: Color, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.36, 0.58, alpha)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.78)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
	style.shadow_size = 8
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.2
	return style

func _progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	return style

func _has_property(node: Object, property_name: String) -> bool:
	if node == null:
		return false
	for row in node.get_property_list():
		if str(row.get("name", "")) == property_name:
			return true
	return false

func _update_social_labels() -> void:
	var weekly: Dictionary = RunManager.get_weekly_snapshot()
	var rival: Dictionary = RunManager.get_rival_snapshot()
	if _weekly_ladder_label != null:
		var week_key: String = str(weekly.get("week_key", "week"))
		var points_after: int = int(weekly.get("points_after", 0))
		var points_gained: int = int(weekly.get("points_gained", 0))
		var tier_after: int = int(weekly.get("tier_after", 0))
		var to_next: int = int(weekly.get("to_next_tier", 0))
		var week_best: int = int(weekly.get("week_best", 0))
		_weekly_ladder_label.text = "Week %s  Tier %d  %d pts (+%d)  Next %d  Best %d" % [
			week_key,
			tier_after,
			points_after,
			max(0, points_gained),
			max(0, to_next),
			max(0, week_best),
		]
	if _rival_target_label != null:
		var rival_name: String = str(rival.get("name", "Rival"))
		var target_after: int = int(rival.get("target_after", RunManager.get_active_rival_target()))
		var delta_after: int = int(rival.get("delta_after", max(0, target_after - RunManager.last_score)))
		var cleared: bool = bool(rival.get("cleared", false))
		if cleared:
			_rival_target_label.text = "%s cleared  Next target %d" % [rival_name, target_after]
			_rival_target_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.58, 0.98))
		else:
			_rival_target_label.text = "%s target %d  %d to go" % [rival_name, target_after, max(0, delta_after)]
			_rival_target_label.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0, 0.98))

func _format_alt_mode_leaderboard(mode_id: String, records: Array) -> String:
	if records.is_empty():
		return "%s leaderboard waiting." % mode_id.capitalize()
	var lines: Array[String] = []
	for i in range(min(2, records.size())):
		var row_var: Variant = records[i]
		if typeof(row_var) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_var
		lines.append("%d) %s - %d" % [
			int(row.get("rank", i + 1)),
			str(row.get("username", "Player")),
			int(row.get("score", 0)),
		])
	return "%s preview\n%s" % [mode_id.capitalize(), "\n".join(lines)]

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		Typography.style_results(self)
		_apply_color_crunch_results_style()
		_layout_results()
		_refresh_intro_pivots()
