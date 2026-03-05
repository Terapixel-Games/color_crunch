extends Control

const AUDIO_TRACK_OVERLAY_SCENE := preload("res://src/scenes/AudioTrackOverlay.tscn")
const ACCOUNT_MODAL_SCENE := preload("res://src/scenes/AccountModal.tscn")
const SHOP_MODAL_SCENE := preload("res://src/scenes/ShopModal.tscn")
const ICON_SETTINGS_ON := preload("res://assets/ui/icons/atlas/music_on.tres")
const ICON_SETTINGS_OFF := preload("res://assets/ui/icons/atlas/music_off.tres")
const PROMO_URL := "https://terapixel.games/lumarush"

@onready var root_margin: MarginContainer = $UI/RootMargin
@onready var panel_shell: PanelContainer = $UI/RootMargin/Layout/Center/PanelShell
@onready var panel: ColorRect = $UI/RootMargin/Layout/Center/PanelShell/Panel
@onready var content_margin: MarginContainer = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin
@onready var title_label: Label = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/Title
@onready var start_button: Button = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/PrimaryCTA/Start
@onready var mode_button: Button = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/SecondaryOptions/OptionRow/ModeToggle
@onready var daily_button: Button = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/SecondaryOptions/OptionRow/DailyToggle
@onready var contrast_button: Button = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/Modes/ModeRow/WeeklyLadderInfo
@onready var promo_button: Button = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/Modes/ModeRow/CrossPromo
@onready var audio_button: Button = $UI/RootMargin/Layout/TopBar/Audio
@onready var account_button: Button = $UI/RootMargin/Layout/TopBar/Account
@onready var shop_button: Button = $UI/RootMargin/Layout/TopBar/Shop
@onready var coin_badge_panel: PanelContainer = $UI/RootMargin/Layout/TopBar/Shop/CoinBadge
@onready var coin_badge: Label = $UI/RootMargin/Layout/TopBar/Shop/CoinBadge/Value

var _title_t: float = 0.0
var _title_base_color: Color = Color(0.98, 0.99, 1.0, 1.0)
var _title_accent_color: Color = Color(0.78, 0.88, 1.0, 1.0)
var _tracks: Array[Dictionary] = []
var _track_index: int = 0
var _audio_overlay: AudioTrackOverlay
var _scene_opened_msec: int = Time.get_ticks_msec()
var _logo_idle_tween: Tween
var _cta_pulse_tween: Tween
var _badge_pulse_tween: Tween
var _panel_fade_tween: Tween

func _ready() -> void:
	if FeatureFlags.clear_high_score_on_boot():
		SaveStore.clear_high_score()
	MusicManager.start_all_synced()
	BackgroundMood.register_controller($BackgroundController)
	MusicManager.set_calm()
	BackgroundMood.set_mood(BackgroundMood.Mood.CALM)
	if not FeatureFlags.is_visual_test_mode():
		$BackgroundController.call("set_emission_activity", 1.0, true)
		$BackgroundController.call("set_menu_visibility_boost", 4.4, 4.0)
		$BackgroundController.call("set_menu_emission_persistent", true)
	VisualTestMode.apply_if_enabled($BackgroundController, $BackgroundController)
	Typography.style_main_menu(self)
	ThemeManager.apply_to_scene(self)
	_layout_menu()
	call_deferred("_layout_menu")
	_sync_mode_buttons()
	title_label.add_theme_color_override("font_color", _title_base_color)
	_populate_track_options()
	_refresh_audio_icon()
	_play_menu_motion()
	if not NakamaService.wallet_updated.is_connected(_on_wallet_updated):
		NakamaService.wallet_updated.connect(_on_wallet_updated)
	start_button.disabled = true
	await NakamaService.refresh_wallet(false)
	_apply_wallet_to_ui(NakamaService.get_wallet())
	start_button.disabled = false
	Telemetry.mark_scene_loaded("main_menu", _scene_opened_msec)

func _process(delta: float) -> void:
	if FeatureFlags.is_visual_test_mode():
		return
	_title_t += delta
	var color_wave: float = (sin(_title_t * 1.10) + 1.0) * 0.5
	title_label.add_theme_color_override("font_color", _title_base_color.lerp(_title_accent_color, color_wave))

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		Typography.style_main_menu(self)
		_layout_menu()
		_refresh_title_pivots()

func _layout_menu() -> void:
	if root_margin == null or panel_shell == null or content_margin == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var outer_margin: int = int(round(clamp(min(viewport_size.x, viewport_size.y) * 0.045, 12.0, 32.0)))
	root_margin.add_theme_constant_override("margin_left", outer_margin)
	root_margin.add_theme_constant_override("margin_top", outer_margin)
	root_margin.add_theme_constant_override("margin_right", outer_margin)
	root_margin.add_theme_constant_override("margin_bottom", outer_margin)

	var panel_width: float = clamp(viewport_size.x * 0.82, 320.0, min(880.0, viewport_size.x - float(outer_margin * 2)))
	var panel_height_cap: float = max(320.0, viewport_size.y - float(outer_margin * 2) - 120.0)
	var panel_height: float = clamp(viewport_size.y * 0.70, 420.0, panel_height_cap)
	var panel_size := Vector2(panel_width, panel_height)
	panel_shell.custom_minimum_size = panel_size
	panel.custom_minimum_size = panel_size

	var inner_margin: int = int(round(clamp(panel_width * 0.052, 18.0, 38.0)))
	content_margin.add_theme_constant_override("margin_left", inner_margin)
	content_margin.add_theme_constant_override("margin_top", inner_margin)
	content_margin.add_theme_constant_override("margin_right", inner_margin)
	content_margin.add_theme_constant_override("margin_bottom", inner_margin)

	start_button.custom_minimum_size.y = clamp(viewport_size.y * 0.10, 86.0, 122.0)
	mode_button.custom_minimum_size.y = clamp(viewport_size.y * 0.076, 62.0, 86.0)
	daily_button.custom_minimum_size.y = mode_button.custom_minimum_size.y
	contrast_button.custom_minimum_size.y = mode_button.custom_minimum_size.y
	promo_button.custom_minimum_size.y = mode_button.custom_minimum_size.y

	var icon_size: float = clamp(min(viewport_size.x, viewport_size.y) * 0.095, 62.0, 90.0)
	audio_button.custom_minimum_size = Vector2(icon_size, icon_size)
	account_button.custom_minimum_size = Vector2(icon_size, icon_size)
	shop_button.custom_minimum_size = Vector2(icon_size, icon_size)
	_layout_coin_badge(icon_size)
	_refresh_title_pivots()

func _refresh_title_pivots() -> void:
	if title_label:
		title_label.pivot_offset = title_label.size * 0.5

func _play_menu_motion() -> void:
	_run_panel_fade_in()
	_run_logo_idle_float()
	_run_badge_pulse()
	_run_cta_pulse()

func _run_logo_idle_float() -> void:
	if is_instance_valid(_logo_idle_tween):
		_logo_idle_tween.kill()
	_logo_idle_tween = create_tween()
	_logo_idle_tween.set_loops()
	_logo_idle_tween.tween_property(title_label, "scale", Vector2(1.02, 1.02), 1.45)
	_logo_idle_tween.tween_property(title_label, "scale", Vector2.ONE, 1.45)

func _run_cta_pulse() -> void:
	if is_instance_valid(_cta_pulse_tween):
		_cta_pulse_tween.kill()
	_cta_pulse_tween = create_tween()
	_cta_pulse_tween.set_loops()
	_cta_pulse_tween.tween_property(start_button, "scale", Vector2(1.015, 1.015), 0.9)
	_cta_pulse_tween.tween_property(start_button, "scale", Vector2.ONE, 0.9)

func _run_badge_pulse() -> void:
	if is_instance_valid(_badge_pulse_tween):
		_badge_pulse_tween.kill()
	_badge_pulse_tween = create_tween()
	_badge_pulse_tween.set_loops()
	_badge_pulse_tween.tween_property(coin_badge_panel, "scale", Vector2(1.06, 1.06), 0.7)
	_badge_pulse_tween.tween_property(coin_badge_panel, "scale", Vector2.ONE, 0.7)

func _run_panel_fade_in() -> void:
	if is_instance_valid(_panel_fade_tween):
		_panel_fade_tween.kill()
	panel.modulate.a = 0.0
	_panel_fade_tween = create_tween()
	_panel_fade_tween.tween_property(panel, "modulate:a", 1.0, 0.48)

func _on_start_pressed() -> void:
	Telemetry.mark_mode_selected(RunManager.get_selected_mode(), "menu_start")
	RunManager.start_game()

func _on_account_pressed() -> void:
	ModalManager.open_scene(ACCOUNT_MODAL_SCENE, self)

func _on_audio_pressed() -> void:
	if is_instance_valid(_audio_overlay):
		_audio_overlay.queue_free()
		_audio_overlay = null
		return
	var overlay := AUDIO_TRACK_OVERLAY_SCENE.instantiate() as AudioTrackOverlay
	if overlay == null:
		return
	add_child(overlay)
	_audio_overlay = overlay
	overlay.setup(_track_names(), _track_index)
	overlay.track_selected.connect(_on_audio_overlay_track_selected)
	overlay.closed.connect(_on_audio_overlay_closed)

func _on_shop_pressed() -> void:
	ModalManager.open_scene(SHOP_MODAL_SCENE, self)

func _on_wallet_updated(wallet: Dictionary) -> void:
	_apply_wallet_to_ui(wallet)

func _apply_wallet_to_ui(wallet: Dictionary) -> void:
	var balance: int = int(wallet.get("coin_balance", 0))
	coin_badge.text = str(max(0, balance))
	var shop_state: Variant = wallet.get("shop", {})
	if typeof(shop_state) == TYPE_DICTIONARY:
		ThemeManager.apply_from_shop_state(shop_state as Dictionary)
		ThemeManager.apply_to_scene(self)

func _populate_track_options() -> void:
	_tracks = MusicManager.get_available_tracks()
	_track_index = _selected_index_for_id(MusicManager.get_current_track_id(), _tracks)
	_sync_audio_overlay_selector()
	_refresh_audio_icon()

func _track_names() -> Array[String]:
	var names: Array[String] = []
	for track_data in _tracks:
		names.append(str(track_data.get("name", "Track")))
	return names

func _selected_index_for_id(track_id: String, tracks: Array[Dictionary]) -> int:
	for i in range(tracks.size()):
		if str(tracks[i].get("id", "")) == track_id:
			return i
	return 0

func _on_audio_overlay_track_selected(_track_name: String, index: int) -> void:
	_apply_track_index(index)

func _apply_track_index(index: int) -> void:
	if _tracks.is_empty():
		return
	_track_index = clampi(index, 0, _tracks.size() - 1)
	var track_id: String = str(_tracks[_track_index].get("id", ""))
	MusicManager.set_track(track_id, true)
	_sync_audio_overlay_selector()
	_refresh_audio_icon()

func _on_audio_overlay_closed() -> void:
	_audio_overlay = null

func _sync_audio_overlay_selector() -> void:
	if not is_instance_valid(_audio_overlay):
		return
	_audio_overlay.set_selected_index(_track_index)

static func is_muted_track(track_id: String) -> bool:
	return track_id.strip_edges().to_lower() == "off"

func _refresh_audio_icon() -> void:
	if audio_button == null:
		return
	var is_muted: bool = is_muted_track(str(MusicManager.get_current_track_id()))
	audio_button.set("icon_texture", ICON_SETTINGS_OFF if is_muted else ICON_SETTINGS_ON)
	var label: String = "Settings (Audio Off)" if is_muted else "Settings"
	audio_button.set("tooltip_text_override", label)
	audio_button.set("accessibility_name_override", label)

func _layout_coin_badge(icon_size: float) -> void:
	if coin_badge_panel == null:
		return
	var radius: float = clamp(icon_size * 0.20, 13.0, 19.0)
	coin_badge_panel.offset_left = icon_size * 0.68
	coin_badge_panel.offset_top = -radius * 0.5
	coin_badge_panel.offset_right = coin_badge_panel.offset_left + (radius * 2.0)
	coin_badge_panel.offset_bottom = coin_badge_panel.offset_top + (radius * 2.0)

func _sync_mode_buttons() -> void:
	if mode_button:
		var week_tier: int = int(SaveStore.data.get("social_week_tier", 0))
		mode_button.text = "Leaderboard: %s (Tier %d)" % [RunManager.get_selected_mode(), week_tier]
	if daily_button:
		daily_button.text = "Daily Puzzle: %s" % ("On" if SaveStore.get_daily_challenge_enabled() else "Off")
	if contrast_button:
		contrast_button.text = "Contrast: %s" % ("On" if SaveStore.is_colorblind_high_contrast() else "Off")
	if promo_button:
		promo_button.text = "LumaRush"

func _on_mode_toggle_pressed() -> void:
	var next_mode := "OPEN" if RunManager.get_selected_mode() == "PURE" else "PURE"
	RunManager.set_selected_mode(next_mode, "menu_toggle")
	_sync_mode_buttons()
	UiFx.pop(mode_button)

func _on_daily_toggle_pressed() -> void:
	RunManager.set_daily_challenge_enabled(not SaveStore.get_daily_challenge_enabled())
	_sync_mode_buttons()
	UiFx.pop(daily_button)

func _on_contrast_toggle_pressed() -> void:
	SaveStore.set_colorblind_high_contrast(not SaveStore.is_colorblind_high_contrast())
	_sync_mode_buttons()
	UiFx.pop(contrast_button)

func _on_promo_pressed() -> void:
	OS.shell_open(PROMO_URL)
