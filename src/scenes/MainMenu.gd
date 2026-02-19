extends Control

@onready var root_margin: MarginContainer = $UI/RootMargin
@onready var panel_shell: PanelContainer = $UI/RootMargin/Layout/Center/PanelShell
@onready var panel: ColorRect = $UI/RootMargin/Layout/Center/PanelShell/Panel
@onready var content_margin: MarginContainer = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin
@onready var title_label: Label = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/Title
@onready var track_selector: TrackSelectorControl = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/TrackSelector
@onready var start_button: Button = $UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/Start
@onready var account_button: Button = $UI/RootMargin/Layout/TopBar/Account
@onready var shop_button: Button = $UI/RootMargin/Layout/BottomBar/Shop
@onready var coin_badge: Label = $UI/RootMargin/Layout/BottomBar/CoinBadge

var _title_t: float = 0.0
var _title_base_color: Color = Color(0.98, 0.99, 1.0, 1.0)
var _title_accent_color: Color = Color(0.78, 0.88, 1.0, 1.0)
var _tracks: Array[Dictionary] = []
var _track_index: int = 0

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
	title_label.add_theme_color_override("font_color", _title_base_color)
	_populate_track_options()
	if not NakamaService.wallet_updated.is_connected(_on_wallet_updated):
		NakamaService.wallet_updated.connect(_on_wallet_updated)
	start_button.disabled = true
	await NakamaService.refresh_wallet(false)
	_apply_wallet_to_ui(NakamaService.get_wallet())
	start_button.disabled = false

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
	track_selector.custom_minimum_size.y = clamp(viewport_size.y * 0.09, 86.0, 104.0)

	var icon_size: float = clamp(min(viewport_size.x, viewport_size.y) * 0.12, 68.0, 92.0)
	account_button.custom_minimum_size = Vector2(icon_size, icon_size)
	shop_button.custom_minimum_size = Vector2(icon_size, icon_size)

	_refresh_title_pivots()

func _refresh_title_pivots() -> void:
	if title_label:
		title_label.pivot_offset = title_label.size * 0.5

func _on_start_pressed() -> void:
	RunManager.start_game()

func _on_account_pressed() -> void:
	var modal := preload("res://src/scenes/AccountModal.tscn").instantiate()
	add_child(modal)

func _on_shop_pressed() -> void:
	var modal := preload("res://src/scenes/ShopModal.tscn").instantiate()
	add_child(modal)

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
	var names: Array[String] = []
	for track_data in _tracks:
		names.append(str(track_data.get("name", "Track")))
	track_selector.tracks = names
	track_selector.current_index = _track_index
	track_selector.set_expanded(false)

func _selected_index_for_id(track_id: String, tracks: Array[Dictionary]) -> int:
	for i in range(tracks.size()):
		if str(tracks[i].get("id", "")) == track_id:
			return i
	return 0

func _on_track_prev_pressed() -> void:
	_cycle_track(-1)

func _on_track_next_pressed() -> void:
	_cycle_track(1)

func _cycle_track(step: int) -> void:
	if _tracks.is_empty():
		return
	if track_selector != null:
		track_selector.cycle_track(step)
		return
	_track_index = posmod(_track_index + step, _tracks.size())
	var track_id: String = str(_tracks[_track_index].get("id", ""))
	MusicManager.set_track(track_id, true)

func _on_track_selector_track_changed(_track_name: String, index: int) -> void:
	if _tracks.is_empty():
		return
	_track_index = clampi(index, 0, _tracks.size() - 1)
	var track_id: String = str(_tracks[_track_index].get("id", ""))
	MusicManager.set_track(track_id, true)

func _on_track_selector_expanded_changed(_is_expanded: bool) -> void:
	pass
