extends Control

@onready var score_label: Label = $UI/Panel/Scroll/VBox/Score
@onready var title_label: Label = $UI/Panel/Scroll/VBox/Title
@onready var mode_badge_label: Label = $UI/Panel/Scroll/VBox/ModeBadge
@onready var best_label: Label = $UI/Panel/Scroll/VBox/Best
@onready var streak_label: Label = $UI/Panel/Scroll/VBox/Streak
@onready var online_status_label: Label = $UI/Panel/Scroll/VBox/OnlineStatus
@onready var leaderboard_label: Label = $UI/Panel/Scroll/VBox/Leaderboard
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

func _ready() -> void:
	BackgroundMood.register_controller($BackgroundController)
	BackgroundMood.set_mood(BackgroundMood.Mood.CALM)
	MusicManager.fade_to_calm(0.6)
	VisualTestMode.apply_if_enabled($BackgroundController, $BackgroundController)
	Typography.style_results(self)
	ThemeManager.apply_to_scene(self)
	_layout_results()
	call_deferred("_layout_results")
	_refresh_intro_pivots()
	_update_labels()
	_bind_online_signals()
	_sync_online_results()
	_sync_wallet_rewards()
	_play_intro()
	if StreakManager.is_streak_at_risk():
		var modal := preload("res://src/scenes/SaveStreakModal.tscn").instantiate()
		add_child(modal)
	if not AdManager.is_connected("rewarded_powerup_earned", Callable(self, "_on_double_reward_ad_earned")):
		AdManager.connect("rewarded_powerup_earned", Callable(self, "_on_double_reward_ad_earned"))

func _update_labels() -> void:
	score_label.text = "%d" % RunManager.last_score
	mode_badge_label.text = "Mode: %s" % _mode_label()
	var local_best: int = int(SaveStore.data["high_score"])
	var online_record: Dictionary = NakamaService.get_my_high_score()
	var online_best: int = int(online_record.get("score", 0))
	var online_rank: int = int(online_record.get("rank", 0))
	var best_value: int = max(local_best, online_best)
	if online_best > 0 and online_rank > 0:
		best_label.text = "Best: %d (Global #%d)" % [best_value, online_rank]
	else:
		best_label.text = "Best: %d" % best_value
	streak_label.text = "Streak: %d" % StreakManager.get_streak_days()
	online_status_label.text = "Online: %s" % NakamaService.get_online_status()
	leaderboard_label.text = _format_leaderboard(NakamaService.get_leaderboard_records())
	coin_balance_label.text = "Coins balance: %d" % NakamaService.get_coin_balance()
	if _base_reward_claimed:
		coins_earned_label.text = "Coins earned: %d" % _base_reward_amount
	else:
		coins_earned_label.text = "Coins earned: pending"
	_layout_results()

func _on_play_again_pressed() -> void:
	AdManager.maybe_show_interstitial()
	RunManager.start_game()

func _on_menu_pressed() -> void:
	AdManager.maybe_show_interstitial()
	RunManager.goto_menu()

func _play_intro() -> void:
	var ui: CanvasItem = $UI
	var panel: CanvasItem = $UI/Panel
	var box_item: CanvasItem = box
	var play_again: CanvasItem = play_again_button
	var menu: CanvasItem = menu_button
	ui.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	box_item.scale = Vector2(0.95, 0.95)
	play_again.modulate.a = 0.0
	menu.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(ui, "modulate:a", 1.0, 0.28)
	t.parallel().tween_property(panel, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(box_item, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(play_again, "modulate:a", 1.0, 0.16)
	t.tween_property(menu, "modulate:a", 1.0, 0.16)

func _refresh_intro_pivots() -> void:
	if panel:
		panel.pivot_offset = panel.size * 0.5
	if box:
		box.pivot_offset = box.size * 0.5

func _layout_results() -> void:
	if panel == null or scroll == null or box == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var viewport_aspect: float = viewport_size.x / max(1.0, viewport_size.y)
	var is_wide: bool = viewport_aspect >= 1.55
	var outer_margin_x: float = clamp(viewport_size.x * 0.04, 18.0, 64.0)
	var outer_margin_y: float = clamp(viewport_size.y * 0.04, 16.0, 40.0)
	var max_panel_width: float = max(360.0, viewport_size.x - (outer_margin_x * 2.0))
	var min_panel_width: float = min(460.0, max_panel_width)
	var target_panel_width: float = viewport_size.x * (0.62 if is_wide else 0.82)
	var panel_width: float = clamp(target_panel_width, min_panel_width, min(980.0, max_panel_width))
	var max_panel_height: float = max(320.0, viewport_size.y - (outer_margin_y * 2.0))
	var min_panel_height: float = min(500.0, max_panel_height)
	var target_panel_height: float = viewport_size.y * (0.84 if is_wide else 0.72)
	var panel_height: float = clamp(target_panel_height, min_panel_height, max_panel_height)
	var panel_size: Vector2 = Vector2(panel_width, panel_height)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = (viewport_size - panel_size) * 0.5
	panel.size = panel_size

	var margin_x: float = clamp(panel_size.x * 0.055, 20.0, 44.0)
	var margin_y: float = clamp(panel_size.y * 0.045, 16.0, 34.0)
	var content_size: Vector2 = panel_size - Vector2(margin_x * 2.0, margin_y * 2.0)
	var base_separation: float = clamp(round(content_size.y * 0.01), 8.0, 16.0)
	var compact_scale: float = 1.0
	for _i in range(3):
		var separation: int = int(clamp(round(base_separation * compact_scale), 6.0, 16.0))
		box.add_theme_constant_override("separation", separation)
		_apply_responsive_typography(content_size, viewport_aspect, compact_scale)

		var secondary_button_height: float = clamp(content_size.y * (0.07 if is_wide else 0.065) * compact_scale, 52.0, 84.0)
		var primary_button_height: float = clamp(content_size.y * (0.09 if is_wide else 0.095) * compact_scale, 64.0, 104.0)
		double_reward_button.custom_minimum_size.y = secondary_button_height
		if play_again_button:
			play_again_button.custom_minimum_size.y = primary_button_height
		if menu_button:
			menu_button.custom_minimum_size.y = primary_button_height
		if spacer:
			spacer.custom_minimum_size.y = max(0.0, round(content_size.y * 0.015 * compact_scale))

		var required_height: float = box.get_combined_minimum_size().y
		if required_height <= content_size.y:
			break
		var fit_ratio: float = content_size.y / max(1.0, required_height)
		var next_scale: float = clamp(compact_scale * fit_ratio, 0.68, compact_scale)
		if absf(next_scale - compact_scale) < 0.01:
			break
		compact_scale = next_scale

	scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scroll.position = Vector2(margin_x, margin_y)
	scroll.size = content_size

	box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	box.position = Vector2.ZERO
	box.size = Vector2(content_size.x, content_size.y)
	box.custom_minimum_size = Vector2(content_size.x, 0.0)
	var content_min_height: float = box.get_combined_minimum_size().y
	box.custom_minimum_size.y = max(content_size.y, content_min_height)

func _apply_responsive_typography(content_size: Vector2, viewport_aspect: float, compact_scale: float = 1.0) -> void:
	var is_wide: bool = viewport_aspect >= 1.55
	var title_size: int = int(round(clamp(content_size.x * (0.06 if is_wide else 0.07) * compact_scale, 28.0, 62.0)))
	var score_size: int = int(round(clamp(content_size.x * (0.11 if is_wide else 0.13) * compact_scale, 44.0, 108.0)))
	var mode_size: int = int(round(clamp(content_size.x * 0.038 * compact_scale, 16.0, 32.0)))
	var stat_size: int = int(round(clamp(content_size.x * 0.05 * compact_scale, 22.0, 44.0)))
	var body_size: int = int(round(clamp(content_size.x * 0.032 * compact_scale, 15.0, 30.0)))
	var coin_size: int = int(round(clamp(content_size.x * 0.028 * compact_scale, 14.0, 26.0)))
	var reward_button_size: int = int(round(clamp(content_size.x * 0.026 * compact_scale, 14.0, 26.0)))
	var primary_button_size: int = int(round(clamp(content_size.x * 0.032 * compact_scale, 16.0, 34.0)))

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
		leaderboard_label.add_theme_constant_override("line_spacing", int(clamp(round(float(body_size) * 0.25), 4.0, 10.0)))
	if coins_earned_label:
		coins_earned_label.add_theme_font_size_override("font_size", coin_size)
	if coin_balance_label:
		coin_balance_label.add_theme_font_size_override("font_size", coin_size)
	if double_reward_button:
		double_reward_button.add_theme_font_size_override("font_size", reward_button_size)
	if play_again_button:
		play_again_button.add_theme_font_size_override("font_size", primary_button_size)
	if menu_button:
		menu_button.add_theme_font_size_override("font_size", primary_button_size)

func _bind_online_signals() -> void:
	if not NakamaService.online_state_changed.is_connected(_on_online_state_changed):
		NakamaService.online_state_changed.connect(_on_online_state_changed)
	if not NakamaService.high_score_updated.is_connected(_on_high_score_updated):
		NakamaService.high_score_updated.connect(_on_high_score_updated)
	if not NakamaService.leaderboard_updated.is_connected(_on_leaderboard_updated):
		NakamaService.leaderboard_updated.connect(_on_leaderboard_updated)

func _on_online_state_changed(status: String) -> void:
	online_status_label.text = "Online: %s" % status

func _on_high_score_updated(_record: Dictionary) -> void:
	_update_labels()

func _on_leaderboard_updated(records: Array) -> void:
	leaderboard_label.text = _format_leaderboard(records)

func _sync_online_results() -> void:
	var mode: String = String(RunManager.last_run_leaderboard_mode).strip_edges().to_upper()
	if mode.is_empty():
		mode = "PURE"
	await NakamaService.submit_score(RunManager.last_score, {
		"source": "results_ready",
		"run_id": RunManager.last_run_id,
		"powerup_breakdown": RunManager.last_run_powerup_breakdown.duplicate(true),
	}, mode, RunManager.last_run_powerups_used, RunManager.last_run_coins_spent, RunManager.last_run_id, RunManager.last_run_duration_ms)
	await NakamaService.refresh_my_high_score(mode)
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
	coin_balance_label.text = "Coins balance: %d" % NakamaService.get_coin_balance()
	coins_earned_label.text = "Coins earned: %d" % _base_reward_amount
	double_reward_button.disabled = not RunManager.last_run_completed_by_gameplay

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
		double_reward_button.text = "Watch Ad: Double Coins"

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
	coins_earned_label.text = "Coins earned: %d" % _base_reward_amount
	coin_balance_label.text = "Coins balance: %d" % NakamaService.get_coin_balance()
	double_reward_button.text = "Coins Doubled"

func _format_leaderboard(records: Array) -> String:
	var mode_label := _mode_label()
	if records.is_empty():
		return "%s Leaderboard: no online records yet" % mode_label
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
	return "%s Leaderboard\n%s" % [mode_label, "\n".join(lines)]

func _mode_label() -> String:
	return "Pure" if String(RunManager.last_run_leaderboard_mode).to_upper() == "PURE" else "Open"

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		Typography.style_results(self)
		_layout_results()
		_refresh_intro_pivots()
