extends Control

@onready var score_label: Label = $UI/VBox/Score
@onready var mode_badge_label: Label = $UI/VBox/ModeBadge
@onready var best_label: Label = $UI/VBox/Best
@onready var streak_label: Label = $UI/VBox/Streak
@onready var online_status_label: Label = $UI/VBox/OnlineStatus
@onready var leaderboard_label: Label = $UI/VBox/Leaderboard
@onready var coins_earned_label: Label = $UI/VBox/CoinsEarned
@onready var coin_balance_label: Label = $UI/VBox/CoinBalance
@onready var double_reward_button: Button = $UI/VBox/DoubleReward
@onready var panel: Control = $UI/Panel
@onready var box: VBoxContainer = $UI/VBox
@onready var play_again_button: Button = $UI/VBox/PlayAgain
@onready var menu_button: Button = $UI/VBox/Menu

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
	var box: CanvasItem = $UI/VBox
	var play_again: CanvasItem = $UI/VBox/PlayAgain
	var menu: CanvasItem = $UI/VBox/Menu
	ui.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	box.scale = Vector2(0.95, 0.95)
	play_again.modulate.a = 0.0
	menu.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(ui, "modulate:a", 1.0, 0.28)
	t.parallel().tween_property(panel, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(box, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(play_again, "modulate:a", 1.0, 0.16)
	t.tween_property(menu, "modulate:a", 1.0, 0.16)

func _refresh_intro_pivots() -> void:
	if panel:
		panel.pivot_offset = panel.size * 0.5
	if box:
		box.pivot_offset = box.size * 0.5

func _layout_results() -> void:
	if panel == null or box == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var panel_size: Vector2 = Vector2(
		clamp(viewport_size.x * 0.82, 520.0, viewport_size.x - 34.0),
		clamp(viewport_size.y * 0.68, 980.0, viewport_size.y - 120.0)
	)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = (viewport_size - panel_size) * 0.5
	panel.size = panel_size

	var margin_x: float = clamp(panel_size.x * 0.045, 18.0, 36.0)
	var margin_y: float = clamp(panel_size.y * 0.04, 16.0, 40.0)
	var content_size: Vector2 = panel_size - Vector2(margin_x * 2.0, margin_y * 2.0)
	var separation: int = int(clamp(round(content_size.y * 0.012), 10.0, 20.0))
	box.add_theme_constant_override("separation", separation)

	var secondary_button_height: float = clamp(content_size.y * 0.07, 70.0, 88.0)
	var primary_button_height: float = clamp(content_size.y * 0.09, 88.0, 116.0)
	double_reward_button.custom_minimum_size.y = secondary_button_height
	if play_again_button:
		play_again_button.custom_minimum_size.y = primary_button_height
	if menu_button:
		menu_button.custom_minimum_size.y = primary_button_height

	box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	box.position = panel.position + Vector2(
		(panel_size.x - content_size.x) * 0.5,
		(panel_size.y - content_size.y) * 0.5
	)
	box.size = content_size

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
