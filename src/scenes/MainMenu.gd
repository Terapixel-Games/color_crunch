extends Control

@onready var track_prev: Button = $UI/VBox/TrackCarousel/TrackPrev
@onready var track_next: Button = $UI/VBox/TrackCarousel/TrackNext
@onready var track_label: Label = $UI/VBox/TrackLabel
@onready var track_carousel: HBoxContainer = $UI/VBox/TrackCarousel
@onready var track_name_host: Control = $UI/VBox/TrackCarousel/TrackNameHost
@onready var track_name: Label = $UI/VBox/TrackCarousel/TrackNameHost/TrackName
@onready var title_label: Label = $UI/VBox/Title
@onready var panel: Control = $UI/Panel
@onready var menu_box: VBoxContainer = $UI/VBox
@onready var start_button: Button = $UI/VBox/Start
@onready var account_button: Button = $UI/Account
@onready var shop_button: Button = $UI/Shop
@onready var coin_badge: Label = $UI/Shop/CoinBadge

var _title_t: float = 0.0
var _title_base_color: Color = Color(0.98, 0.99, 1.0, 1.0)
var _title_accent_color: Color = Color(0.78, 0.88, 1.0, 1.0)
var _tracks: Array[Dictionary] = []
var _track_index: int = 0
var _track_slide_tween: Tween

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
	await NakamaService.refresh_wallet(false)
	_apply_wallet_to_ui(NakamaService.get_wallet())

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
	if panel == null or menu_box == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	# Keep menu panel centered in viewport coordinates for stable desktop/mobile alignment.
	var panel_size: Vector2 = Vector2(
		clamp(viewport_size.x * 0.76, 520.0, viewport_size.x - 34.0),
		clamp(viewport_size.y * 0.60, 520.0, viewport_size.y - 140.0)
	)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = (viewport_size - panel_size) * 0.5
	panel.size = panel_size

	var margin_x: float = panel_size.x * 0.05
	var margin_y: float = panel_size.y * 0.05
	var content_size: Vector2 = panel_size - Vector2(margin_x * 2.0, margin_y * 2.0)
	var carousel_sep: int = track_carousel.get_theme_constant("separation")
	var side_buttons_width: float = track_prev.get_combined_minimum_size().x + track_next.get_combined_minimum_size().x + float(carousel_sep * 2)
	track_name_host.custom_minimum_size.x = max(120.0, content_size.x - side_buttons_width)

	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_carousel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fit_label_font_to_width(title_label, content_size.x, 34)

	menu_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_box.position = panel.position + Vector2((panel_size.x - content_size.x) * 0.5, (panel_size.y - content_size.y) * 0.5)
	menu_box.size = content_size

	_refresh_title_pivots()

func _fit_label_font_to_width(label: Label, target_width: float, min_size: int) -> void:
	if label == null:
		return
	var theme_font: Font = label.get_theme_font("font")
	if theme_font == null:
		return
	var font_size: int = label.get_theme_font_size("font_size")
	var clamped_width: float = max(40.0, target_width)
	while font_size > min_size and theme_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > clamped_width:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)

func _refresh_title_pivots() -> void:
	if title_label == null:
		return
	title_label.pivot_offset = title_label.size * 0.5
	if track_name:
		track_name.pivot_offset = track_name.size * 0.5

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
	var can_cycle: bool = _tracks.size() > 1
	track_prev.disabled = not can_cycle
	track_next.disabled = not can_cycle
	_refresh_track_name(false)

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
	_track_index = posmod(_track_index + step, _tracks.size())
	var track_id: String = str(_tracks[_track_index].get("id", ""))
	MusicManager.set_track(track_id, true)
	_refresh_track_name(true, step)

func _refresh_track_name(animated: bool, direction: int = 1) -> void:
	if _tracks.is_empty():
		track_name.text = ""
		return
	track_name.text = str(_tracks[_track_index].get("name", "Track"))
	if track_name:
		track_name.pivot_offset = track_name.size * 0.5
	if not animated:
		track_name.modulate = Color(1, 1, 1, 1)
		track_name.scale = Vector2.ONE
		track_name.position.x = 0.0
		return
	if is_instance_valid(_track_slide_tween):
		_track_slide_tween.kill()
	var offset: float = 22.0 * float(sign(direction))
	var dir_scale: float = 1.0 + (0.05 * float(sign(direction)))
	track_name.position.x = offset
	track_name.scale = Vector2(dir_scale, 1.0)
	track_name.modulate.a = 0.0
	_track_slide_tween = create_tween()
	_track_slide_tween.set_parallel(true)
	_track_slide_tween.tween_property(track_name, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_track_slide_tween.tween_property(track_name, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_track_slide_tween.tween_property(track_name, "modulate:a", 1.0, 0.2)
