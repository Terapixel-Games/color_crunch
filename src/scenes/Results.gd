extends Control

const AUDIO_TRACK_OVERLAY_SCENE := preload("res://src/scenes/AudioTrackOverlay.tscn")
const ICON_MUSIC_ON: Texture2D = preload("res://assets/ui/icons/atlas/music_on.tres")
const ICON_MUSIC_OFF: Texture2D = preload("res://assets/ui/icons/atlas/music_off.tres")

@onready var title_label: Label = $UI/Panel/Scroll/VBox/Title
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

func _ready() -> void:
	BackgroundMood.register_controller($BackgroundController)
	BackgroundMood.set_mood(BackgroundMood.Mood.CALM)
	MusicManager.fade_to_calm(0.6)
	VisualTestMode.apply_if_enabled($BackgroundController, $BackgroundController)
	Typography.style_results(self)
	ThemeManager.apply_to_scene(self)
	_refresh_audio_icon()
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
	_close_audio_overlay()
	AdManager.maybe_show_interstitial()
	RunManager.start_game()

func _on_menu_pressed() -> void:
	_close_audio_overlay()
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
	_layout_results_for_size(get_viewport_rect().size)

func _layout_results_for_size(viewport_size: Vector2) -> void:
	if panel == null or scroll == null or box == null:
		return
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
	_layout_top_right(viewport_size)

	var margin_x: float = clamp(panel_size.x * 0.055, 20.0, 44.0)
	var margin_y: float = clamp(panel_size.y * 0.045, 16.0, 34.0)
	var content_size: Vector2 = panel_size - Vector2(margin_x * 2.0, margin_y * 2.0)
	var use_split: bool = viewport_aspect >= 1.45
	_configure_stats_split(content_size, use_split)
	var base_separation: float = clamp(round(content_size.y * 0.01), 6.0, 16.0)
	var compact_scale: float = 1.0
	for _i in range(6):
		var separation: int = int(clamp(round(base_separation * compact_scale), 6.0, 16.0))
		box.add_theme_constant_override("separation", separation)
		_apply_responsive_typography(content_size, viewport_aspect, use_split, compact_scale)

		var secondary_button_height: float = clamp(content_size.y * (0.07 if is_wide else 0.065) * compact_scale, 38.0, 84.0)
		var primary_button_height: float = clamp(content_size.y * (0.09 if is_wide else 0.095) * compact_scale, 48.0, 104.0)
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
		var next_scale: float = clamp(compact_scale * fit_ratio, 0.6, compact_scale)
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

func _layout_top_right(viewport_size: Vector2) -> void:
	if top_right_bar == null or audio_button == null:
		return
	var margin: float = clamp(min(viewport_size.x, viewport_size.y) * 0.045, 12.0, 32.0)
	var icon_size: float = clamp(min(viewport_size.x, viewport_size.y) * 0.12, 68.0, 92.0)
	top_right_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_right_bar.position = Vector2(viewport_size.x - margin - icon_size, margin)
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
	for label in [score_label, mode_badge_label, best_label, streak_label]:
		if label:
			label.horizontal_alignment = left_alignment
	if online_status_label:
		online_status_label.horizontal_alignment = right_alignment
	if leaderboard_label:
		leaderboard_label.horizontal_alignment = right_alignment

func _apply_responsive_typography(content_size: Vector2, viewport_aspect: float, use_split: bool, compact_scale: float = 1.0) -> void:
	var is_wide: bool = viewport_aspect >= 1.55
	var headline_scale: float = compact_scale
	var action_scale: float = compact_scale
	var split_gap: float = 20.0
	if stats_split:
		split_gap = float(stats_split.get_theme_constant("h_separation"))
	var stat_column_width: float = max(220.0, (content_size.x - split_gap) * 0.5) if use_split else content_size.x
	var menu_title_px: int = Typography.px(Typography.SIZE_MENU_TITLE)
	var menu_button_px: int = Typography.px(Typography.SIZE_BUTTON)
	var title_size: int = int(round(clamp(float(menu_title_px) * 0.82 * headline_scale, 46.0, 124.0)))
	var score_size: int = int(round(clamp(max(float(menu_title_px) * 1.0, stat_column_width * 0.16) * headline_scale, 58.0, 156.0)))
	var mode_size: int = int(round(clamp(float(menu_button_px) * 0.74 * compact_scale, 18.0, 48.0)))
	var stat_size: int = int(round(clamp(float(menu_button_px) * 0.9 * compact_scale, 22.0, 58.0)))
	var body_size: int = int(round(clamp(float(menu_button_px) * 0.76 * compact_scale, 17.0, 44.0)))
	var coin_size: int = int(round(clamp(float(menu_button_px) * 0.8 * compact_scale, 17.0, 46.0)))
	var reward_button_size: int = int(round(clamp(float(menu_button_px) * 0.78 * action_scale, 17.0, 40.0)))
	var primary_button_size: int = int(round(clamp(float(menu_button_px) * (0.9 if is_wide else 0.95) * action_scale, 20.0, 56.0)))

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

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		Typography.style_results(self)
		_layout_results()
		_refresh_intro_pivots()
