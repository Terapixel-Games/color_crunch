extends Node

const THEME_DEFAULT := "default"
const THEME_NEON := "neon"

const THEMES := {
	THEME_DEFAULT: {
		"display_name": "Default",
		"background_calm_a": Color(0.88, 0.93, 1.0, 1.0),
		"background_calm_b": Color(0.64, 0.76, 1.0, 1.0),
		"background_hype_a": Color(0.2, 0.26, 0.66, 1.0),
		"background_hype_b": Color(0.6, 0.28, 0.94, 1.0),
		"tile_palette": [
			Color(0.18, 0.78, 1.0, 0.78),
			Color(0.98, 0.34, 0.30, 0.78),
			Color(0.28, 0.94, 0.46, 0.78),
			Color(1.0, 0.84, 0.18, 0.78),
			Color(0.88, 0.34, 1.0, 0.84),
		],
		"vfx_palette": [
			Color(0.42, 0.8, 1.0, 0.9),
			Color(0.96, 0.62, 0.9, 0.9),
			Color(0.6, 0.95, 0.7, 0.9),
			Color(1.0, 0.85, 0.5, 0.9),
			Color(0.9, 0.6, 0.6, 0.9),
		],
		"panel_tint": Color(0.12, 0.18, 0.32, 0.22),
	},
	THEME_NEON: {
		"display_name": "Neon",
		"background_calm_a": Color(0.08, 0.06, 0.18, 1.0),
		"background_calm_b": Color(0.12, 0.04, 0.22, 1.0),
		"background_hype_a": Color(0.0, 0.12, 0.28, 1.0),
		"background_hype_b": Color(0.62, 0.0, 0.72, 1.0),
		"tile_palette": [
			Color(0.0, 0.96, 1.0, 0.86),
			Color(1.0, 0.2, 0.64, 0.86),
			Color(0.3, 1.0, 0.7, 0.86),
			Color(1.0, 0.82, 0.24, 0.86),
			Color(0.76, 0.42, 1.0, 0.88),
		],
		"vfx_palette": [
			Color(0.0, 0.98, 1.0, 0.94),
			Color(1.0, 0.32, 0.78, 0.94),
			Color(0.28, 1.0, 0.8, 0.94),
			Color(1.0, 0.9, 0.32, 0.94),
			Color(0.72, 0.48, 1.0, 0.94),
		],
		"panel_tint": Color(0.08, 0.05, 0.2, 0.34),
	},
}

func get_current_theme_id() -> String:
	var theme_id := SaveStore.get_equipped_theme()
	if not THEMES.has(theme_id):
		return THEME_DEFAULT
	return theme_id

func get_theme_config(theme_id: String = "") -> Dictionary:
	var resolved := theme_id.strip_edges().to_lower()
	if resolved.is_empty():
		resolved = get_current_theme_id()
	if not THEMES.has(resolved):
		resolved = THEME_DEFAULT
	return (THEMES[resolved] as Dictionary).duplicate(true)

func apply_to_scene(scene: Node) -> void:
	if scene == null:
		return
	var config := get_theme_config()
	apply_to_background(scene.get_node_or_null("BackgroundController"), config)
	apply_to_board(scene.get_node_or_null("BoardView"), config)
	apply_to_ui(scene, config)
	apply_to_vfx(config)

func apply_from_shop_state(shop: Dictionary) -> void:
	var theme_id := str(shop.get("equippedTheme", THEME_DEFAULT)).strip_edges().to_lower()
	if not THEMES.has(theme_id):
		theme_id = THEME_DEFAULT
	SaveStore.set_equipped_theme(theme_id)
	var owned_var: Variant = shop.get("ownedThemes", ["default"])
	if typeof(owned_var) == TYPE_ARRAY:
		SaveStore.set_owned_themes(owned_var as Array)
	var rentals_var: Variant = shop.get("themeRentals", {})
	if typeof(rentals_var) == TYPE_DICTIONARY:
		SaveStore.set_theme_rentals(rentals_var as Dictionary)

func apply_to_background(controller: Node, config: Dictionary) -> void:
	if controller == null:
		return
	if controller.has_method("set_theme_palette"):
		controller.call(
			"set_theme_palette",
			config.get("background_calm_a"),
			config.get("background_calm_b"),
			config.get("background_hype_a"),
			config.get("background_hype_b")
		)

func apply_to_board(board: Node, config: Dictionary) -> void:
	if board == null:
		return
	if board.has_method("set_theme_palette"):
		board.call("set_theme_palette", config.get("tile_palette", []))

func apply_to_vfx(config: Dictionary) -> void:
	if VFXManager and VFXManager.has_method("set_theme_palette"):
		VFXManager.call("set_theme_palette", config.get("vfx_palette", []))

func apply_to_ui(scene: Node, config: Dictionary) -> void:
	var panel: ColorRect = scene.get_node_or_null("UI/Panel")
	if panel == null:
		panel = scene.get_node_or_null("UI/RootMargin/Layout/Center/PanelShell/Panel")
	if panel:
		panel.color = config.get("panel_tint", panel.color)
