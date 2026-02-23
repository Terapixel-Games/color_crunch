extends Control

const AUDIO_TRACK_OVERLAY_SCENE := preload("res://src/scenes/AudioTrackOverlay.tscn")
const ACCOUNT_MODAL_SCENE := preload("res://src/scenes/AccountModal.tscn")
const SHOP_MODAL_SCENE := preload("res://src/scenes/ShopModal.tscn")
const ICON_MUSIC_ON := preload("res://assets/ui/icons/atlas/music_on.tres")
const ICON_MUSIC_OFF := preload("res://assets/ui/icons/atlas/music_off.tres")
const PROMO_URL := "https://terapixel.games/lumarush"

@onready var root_margin: MarginContainer = $UI/RootMargin
@onready var panel_shell: PanelContainer = $UI/RootMargin/Layout/Center/PanelShell
@onready var panel: ColorRect = $UI/RootMargin/Layout/Center/PanelShell/Panel
@onready var content_margin: MarginContainer = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin
@onready var title_label: Label = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/Title
@onready var start_button: Button = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/Start
@onready var panel_vbox: VBoxContainer = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox
@onready var audio_button: Button = $UI/RootMargin/Layout/TopBar/Audio
@onready var account_button: Button = $UI/RootMargin/Layout/TopBar/Account
@onready var shop_button: Button = $UI/RootMargin/Layout/BottomBar/Shop
@onready var coin_badge_panel: PanelContainer = $UI/RootMargin/Layout/BottomBar/Shop/CoinBadge
@onready var coin_badge: Label = $UI/RootMargin/Layout/BottomBar/Shop/CoinBadge/Value

var _title_t: float = 0.0
var _title_base_color: Color = Color(0.98, 0.99, 1.0, 1.0)
var _title_accent_color: Color = Color(0.78, 0.88, 1.0, 1.0)
var _tracks: Array[Dictionary] = []
var _track_index: int = 0
var _audio_overlay: AudioTrackOverlay
var _mode_button: Button
var _daily_button: Button
var _promo_button: Button
var _contrast_button: Button
var _scene_opened_msec: int = Time.get_ticks_msec()
const BADGE_BG_COLOR: Color = Color(0.96, 0.22, 0.24, 1.0)
const BADGE_BORDER_COLOR: Color = Color(1.0, 0.9, 0.92, 0.96)

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
	_style_coin_badge()
	_ensure_action_buttons()
	_sync_mode_buttons()
	title_label.add_theme_color_override("font_color", _title_base_color)
	_populate_track_options()
	_refresh_audio_icon()
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
	var rot_wave: float = sin(_title_t * 1.8)
	title_label.rotation_degrees = rot_wave * 3.8
	var color_wave: float = (sin(_title_t * 1.2) + 1.0) * 0.5
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

	var panel_width: float = clamp(viewport_size.x * 0.78, 280.0, min(820.0, viewport_size.x - float(outer_margin * 2)))
	var panel_height_cap: float = max(280.0, viewport_size.y - float(outer_margin * 2) - 170.0)
	var panel_height: float = clamp(viewport_size.y * 0.62, 340.0, panel_height_cap)
	var panel_size := Vector2(panel_width, panel_height)
	panel_shell.custom_minimum_size = panel_size
	panel.custom_minimum_size = panel_size

	var inner_margin: int = int(round(clamp(panel_width * 0.05, 16.0, 34.0)))
	content_margin.add_theme_constant_override("margin_left", inner_margin)
	content_margin.add_theme_constant_override("margin_top", inner_margin)
	content_margin.add_theme_constant_override("margin_right", inner_margin)
	content_margin.add_theme_constant_override("margin_bottom", inner_margin)

	start_button.custom_minimum_size.y = clamp(viewport_size.y * 0.095, 84.0, 118.0)

	var icon_size: float = clamp(min(viewport_size.x, viewport_size.y) * 0.12, 68.0, 92.0)
	audio_button.custom_minimum_size = Vector2(icon_size, icon_size)
	account_button.custom_minimum_size = Vector2(icon_size, icon_size)
	shop_button.custom_minimum_size = Vector2(icon_size, icon_size)
	_layout_coin_badge(icon_size)

	_refresh_title_pivots()

func _refresh_title_pivots() -> void:
	if title_label:
		title_label.pivot_offset = title_label.size * 0.5

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

func _cycle_track(step: int) -> void:
	if _tracks.is_empty():
		return
	var wrapped_index: int = posmod(_track_index + step, _tracks.size())
	_apply_track_index(wrapped_index)

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
	audio_button.set("icon_texture", ICON_MUSIC_OFF if is_muted else ICON_MUSIC_ON)
	var label: String = "Audio Off" if is_muted else "Audio"
	audio_button.set("tooltip_text_override", label)
	audio_button.set("accessibility_name_override", label)

func _style_coin_badge() -> void:
	if coin_badge_panel == null or coin_badge == null:
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
	coin_badge_panel.add_theme_stylebox_override("panel", style)
	coin_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_badge.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 1.0))
	coin_badge.add_theme_color_override("font_outline_color", Color(0.3, 0.0, 0.05, 0.95))
	coin_badge.add_theme_constant_override("outline_size", 2)
	coin_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shop_button.clip_contents = false

func _layout_coin_badge(icon_size: float) -> void:
	if coin_badge_panel == null:
		return
	var radius: float = clamp(icon_size * 0.23, 14.0, 22.0)
	coin_badge_panel.anchor_left = 1.0
	coin_badge_panel.anchor_top = 0.0
	coin_badge_panel.anchor_right = 1.0
	coin_badge_panel.anchor_bottom = 0.0
	coin_badge_panel.offset_left = -radius
	coin_badge_panel.offset_top = -radius
	coin_badge_panel.offset_right = radius
	coin_badge_panel.offset_bottom = radius
	coin_badge_panel.z_index = 10

func _ensure_action_buttons() -> void:
	if panel_vbox == null:
		return
	if _mode_button == null:
		_mode_button = Button.new()
		_mode_button.name = "ModeToggle"
		_mode_button.custom_minimum_size.y = 60.0
		_mode_button.pressed.connect(_on_mode_toggle_pressed)
		panel_vbox.add_child(_mode_button)
	if _daily_button == null:
		_daily_button = Button.new()
		_daily_button.name = "DailyToggle"
		_daily_button.custom_minimum_size.y = 56.0
		_daily_button.pressed.connect(_on_daily_toggle_pressed)
		panel_vbox.add_child(_daily_button)
	if _contrast_button == null:
		_contrast_button = Button.new()
		_contrast_button.name = "ContrastToggle"
		_contrast_button.custom_minimum_size.y = 56.0
		_contrast_button.pressed.connect(_on_contrast_toggle_pressed)
		panel_vbox.add_child(_contrast_button)
	if _promo_button == null:
		_promo_button = Button.new()
		_promo_button.name = "CrossPromo"
		_promo_button.text = "Play LumaRush"
		_promo_button.custom_minimum_size.y = 52.0
		_promo_button.pressed.connect(_on_promo_pressed)
		panel_vbox.add_child(_promo_button)
	UiFx.fade_in(_mode_button, 0.14)
	UiFx.fade_in(_daily_button, 0.14)
	UiFx.fade_in(_contrast_button, 0.14)
	UiFx.fade_in(_promo_button, 0.14)

func _sync_mode_buttons() -> void:
	if _mode_button:
		_mode_button.text = "Leaderboard Mode: %s" % RunManager.get_selected_mode()
	if _daily_button:
		_daily_button.text = "Daily Puzzle: %s" % ("On" if SaveStore.get_daily_challenge_enabled() else "Off")
	if _contrast_button:
		_contrast_button.text = "Colorblind Contrast: %s" % ("On" if SaveStore.is_colorblind_high_contrast() else "Off")

func _on_mode_toggle_pressed() -> void:
	var next_mode := "OPEN" if RunManager.get_selected_mode() == "PURE" else "PURE"
	RunManager.set_selected_mode(next_mode, "menu_toggle")
	_sync_mode_buttons()
	UiFx.pop(_mode_button)

func _on_daily_toggle_pressed() -> void:
	RunManager.set_daily_challenge_enabled(not SaveStore.get_daily_challenge_enabled())
	_sync_mode_buttons()
	UiFx.pop(_daily_button)

func _on_contrast_toggle_pressed() -> void:
	SaveStore.set_colorblind_high_contrast(not SaveStore.is_colorblind_high_contrast())
	_sync_mode_buttons()
	UiFx.pop(_contrast_button)

func _on_promo_pressed() -> void:
	OS.shell_open(PROMO_URL)
