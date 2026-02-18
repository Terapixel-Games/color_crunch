extends Node

const REFERENCE_HEIGHT: float = 2532.0
const GLOBAL_TEXT_SCALE: float = 2.12
const MIN_SCALE_FACTOR: float = 0.90
const MAX_SCALE_FACTOR: float = 2.30
const PRIMARY_TEXT: Color = Color8(242, 244, 255, 255)
const SECONDARY_TEXT: Color = Color8(242, 244, 255, 166)
const SHADOW_TEXT: Color = Color(0.02, 0.04, 0.12, 0.82)

const SIZE_SCORE: float = 60.0
const SIZE_BUTTON: float = 30.0
const SIZE_MODAL_TITLE: float = 56.0
const SIZE_BODY: float = 30.0
const SIZE_MENU_TITLE: float = 64.0

const WEIGHT_REGULAR: int = 400
const WEIGHT_MEDIUM: int = 500
const WEIGHT_SEMIBOLD: int = 600
const WEIGHT_BOLD: int = 700

const BASE_FONT_PATH := "res://assets/fonts/SpaceGrotesk.ttf"

var _base_font: Font
var _font_cache: Dictionary = {}

func scale_factor() -> float:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return 1.0
	var h: float = tree.root.get_visible_rect().size.y
	if h <= 0.0:
		return 1.0
	return clamp(h / REFERENCE_HEIGHT, MIN_SCALE_FACTOR, MAX_SCALE_FACTOR)

func px(reference_size: float) -> int:
	return int(round(reference_size * scale_factor() * GLOBAL_TEXT_SCALE))

func _font_for_weight(weight: int) -> Font:
	if _font_cache.has(weight):
		return _font_cache[weight]
	var variation := FontVariation.new()
	variation.base_font = _ensure_base_font()
	variation.variation_opentype = {"wght": weight}
	_font_cache[weight] = variation
	return variation

func _ensure_base_font() -> Font:
	if _base_font != null:
		return _base_font
	var loaded: Resource = load(BASE_FONT_PATH)
	if loaded is Font:
		_base_font = loaded as Font
	else:
		_base_font = ThemeDB.fallback_font
	return _base_font

func style_label(label: Label, reference_size: float, weight: int, secondary: bool = false) -> void:
	if label == null:
		return
	label.add_theme_font_override("font", _font_for_weight(weight))
	label.add_theme_font_size_override("font_size", px(reference_size))
	label.add_theme_color_override("font_color", SECONDARY_TEXT if secondary else PRIMARY_TEXT)
	label.add_theme_color_override("font_outline_color", SHADOW_TEXT)
	label.add_theme_constant_override("outline_size", max(1, int(round(2.0 * scale_factor()))))

func style_button(button: BaseButton, reference_size: float, weight: int = WEIGHT_SEMIBOLD) -> void:
	if button == null:
		return
	button.add_theme_font_override("font", _font_for_weight(weight))
	button.add_theme_font_size_override("font_size", px(reference_size))
	button.add_theme_color_override("font_color", PRIMARY_TEXT)
	button.add_theme_color_override("font_hover_color", PRIMARY_TEXT)
	button.add_theme_color_override("font_pressed_color", PRIMARY_TEXT)
	button.add_theme_color_override("font_disabled_color", SECONDARY_TEXT)
	button.add_theme_color_override("font_outline_color", SHADOW_TEXT)
	button.add_theme_constant_override("outline_size", max(1, int(round(2.0 * scale_factor()))))

func style_main_menu(scene: Control) -> void:
	style_label(scene.get_node_or_null("UI/VBox/Title"), SIZE_MENU_TITLE, WEIGHT_BOLD)
	style_label(scene.get_node_or_null("UI/VBox/Subtitle"), SIZE_BODY, WEIGHT_REGULAR, true)
	style_label(scene.get_node_or_null("UI/VBox/TrackLabel"), 22.0, WEIGHT_MEDIUM, true)
	style_button(scene.get_node_or_null("UI/VBox/TrackCarousel/TrackPrev"), 26.0, WEIGHT_BOLD)
	style_label(scene.get_node_or_null("UI/VBox/TrackCarousel/TrackNameHost/TrackName"), 24.0, WEIGHT_SEMIBOLD)
	style_button(scene.get_node_or_null("UI/VBox/TrackCarousel/TrackNext"), 26.0, WEIGHT_BOLD)
	style_button(scene.get_node_or_null("UI/VBox/Start"), SIZE_BUTTON, WEIGHT_SEMIBOLD)
	style_button(scene.get_node_or_null("UI/Account"), 20.0, WEIGHT_SEMIBOLD)
	style_button(scene.get_node_or_null("UI/Shop"), 20.0, WEIGHT_SEMIBOLD)
	style_label(scene.get_node_or_null("UI/Shop/CoinBadge"), 16.0, WEIGHT_BOLD)

func style_game(scene: Control) -> void:
	style_label(scene.get_node_or_null("UI/TopBar/ScoreBox/ScoreCaption"), 20.0, WEIGHT_MEDIUM, true)
	style_label(scene.get_node_or_null("UI/TopBar/ScoreBox/ScoreValue"), 60.0, WEIGHT_SEMIBOLD)
	style_button(scene.get_node_or_null("UI/TopBar/Pause"), 24.0, WEIGHT_BOLD)
	style_button(scene.get_node_or_null("UI/Powerups/Undo"), 56.0, WEIGHT_SEMIBOLD)
	style_button(scene.get_node_or_null("UI/Powerups/RemoveColor"), 56.0, WEIGHT_SEMIBOLD)
	style_button(scene.get_node_or_null("UI/Powerups/Shuffle"), 56.0, WEIGHT_SEMIBOLD)
	style_label(scene.get_node_or_null("UI/Powerups/Undo/Badge"), 28.0, WEIGHT_SEMIBOLD)
	style_label(scene.get_node_or_null("UI/Powerups/RemoveColor/Badge"), 28.0, WEIGHT_SEMIBOLD)
	style_label(scene.get_node_or_null("UI/Powerups/Shuffle/Badge"), 28.0, WEIGHT_SEMIBOLD)

func style_results(scene: Control) -> void:
	style_label(scene.get_node_or_null("UI/VBox/Title"), 62.0, WEIGHT_BOLD)
	style_label(scene.get_node_or_null("UI/VBox/Score"), 64.0, WEIGHT_BOLD)
	style_label(scene.get_node_or_null("UI/VBox/ModeBadge"), 20.0, WEIGHT_SEMIBOLD, true)
	style_label(scene.get_node_or_null("UI/VBox/Best"), 34.0, WEIGHT_BOLD, false)
	style_label(scene.get_node_or_null("UI/VBox/Streak"), 34.0, WEIGHT_BOLD, false)
	style_label(scene.get_node_or_null("UI/VBox/OnlineStatus"), 30.0, WEIGHT_BOLD, false)
	var leaderboard := scene.get_node_or_null("UI/VBox/Leaderboard")
	style_label(leaderboard, 28.0, WEIGHT_SEMIBOLD, false)
	style_label(scene.get_node_or_null("UI/VBox/CoinsEarned"), 26.0, WEIGHT_BOLD, false)
	style_label(scene.get_node_or_null("UI/VBox/CoinBalance"), 24.0, WEIGHT_SEMIBOLD, false)
	if leaderboard != null:
		leaderboard.add_theme_constant_override("line_spacing", max(2, int(round(6.0 * scale_factor()))))
	style_button(scene.get_node_or_null("UI/VBox/DoubleReward"), 24.0, WEIGHT_SEMIBOLD)
	style_button(scene.get_node_or_null("UI/VBox/PlayAgain"), 36.0, WEIGHT_BOLD)
	style_button(scene.get_node_or_null("UI/VBox/Menu"), 36.0, WEIGHT_BOLD)

func style_pause_overlay(scene: Control) -> void:
	style_label(scene.get_node_or_null("VBox/Title"), SIZE_MODAL_TITLE, WEIGHT_BOLD)
	style_button(scene.get_node_or_null("VBox/Resume"), SIZE_BUTTON, WEIGHT_SEMIBOLD)
	style_button(scene.get_node_or_null("VBox/Quit"), SIZE_BUTTON, WEIGHT_SEMIBOLD)

func style_save_streak(scene: Control) -> void:
	# Compact defaults for modal layouts on narrow mobile viewports.
	style_label(scene.get_node_or_null("Panel/VBox/Title"), 26.0, WEIGHT_BOLD)
	style_label(scene.get_node_or_null("Panel/VBox/Status"), 16.0, WEIGHT_REGULAR, true)
	style_button(scene.get_node_or_null("Panel/VBox/SaveButton"), 18.0, WEIGHT_SEMIBOLD)
	style_button(scene.get_node_or_null("Panel/VBox/Close"), 18.0, WEIGHT_MEDIUM)
	style_label(scene.get_node_or_null("Center/Panel/VBox/Title"), 26.0, WEIGHT_BOLD)
	style_label(scene.get_node_or_null("Center/Panel/VBox/Status"), 16.0, WEIGHT_REGULAR, true)
	style_button(scene.get_node_or_null("Center/Panel/VBox/SaveButton"), 18.0, WEIGHT_SEMIBOLD)
	style_button(scene.get_node_or_null("Center/Panel/VBox/Close"), 18.0, WEIGHT_MEDIUM)

func style_tutorial_tip(scene: Control) -> void:
	style_label(scene.get_node_or_null("Center/Panel/VBox/Title"), 24.0, WEIGHT_BOLD)
	style_label(scene.get_node_or_null("Center/Panel/VBox/Message"), 16.0, WEIGHT_REGULAR, true)
	style_button(scene.get_node_or_null("Center/Panel/VBox/Confirm"), 18.0, WEIGHT_SEMIBOLD)
	var toggle := scene.get_node_or_null("Center/Panel/VBox/DoNotShow")
	if toggle and toggle is BaseButton:
		style_button(toggle as BaseButton, 14.0, WEIGHT_MEDIUM)
