extends Control

const THEME_NEON_COST := 1500
const POWERUP_COSTS := {
	"undo": 120,
	"prism": 180,
	"shuffle": 140,
}
const COIN_PACKS := [
	{"product_id": "coins_500_color_crunch", "label": "500 - $0.99"},
	{"product_id": "coins_1200_color_crunch", "label": "1200 - $1.99"},
	{"product_id": "coins_3000_color_crunch", "label": "3000 - $4.99"},
	{"product_id": "coins_7500_color_crunch", "label": "7500 - $9.99"},
	{"product_id": "coins_20000_color_crunch", "label": "20000 - $19.99"},
]

@onready var status_label: Label = $Panel/VBox/Status
@onready var coins_label: Label = $Panel/VBox/Coins
@onready var owned_label: Label = $Panel/VBox/Scroll/Content/Themes/Owned

var _pending_theme_ad_unlock: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Typography.style_save_streak(self)
	if not AdManager.is_connected("rewarded_powerup_earned", Callable(self, "_on_rewarded_ad_earned")):
		AdManager.connect("rewarded_powerup_earned", Callable(self, "_on_rewarded_ad_earned"))
	if not NakamaService.wallet_updated.is_connected(_on_wallet_updated):
		NakamaService.wallet_updated.connect(_on_wallet_updated)
	for i in range(COIN_PACKS.size()):
		var row: Dictionary = COIN_PACKS[i]
		var button: Button = $Panel/VBox/Scroll/Content/CoinPacks.get_child(i) as Button
		button.text = str(row.get("label", "Pack"))
		if not button.pressed.is_connected(_on_coin_pack_pressed.bind(i)):
			button.pressed.connect(_on_coin_pack_pressed.bind(i))
	ThemeManager.apply_to_scene(get_tree().current_scene)
	await NakamaService.refresh_wallet(false)
	_on_wallet_updated(NakamaService.get_wallet())

func _on_wallet_updated(wallet: Dictionary) -> void:
	coins_label.text = "Coins: %d" % int(wallet.get("coin_balance", 0))
	var shop: Dictionary = wallet.get("shop", {})
	var owned: Array = shop.get("ownedThemes", ["default"])
	var equipped := str(shop.get("equippedTheme", "default"))
	var owned_texts: Array[String] = []
	for theme_var in owned:
		owned_texts.append(str(theme_var))
	owned_label.text = "Owned themes: %s | Equipped: %s" % [", ".join(owned_texts), equipped]

func _on_coin_pack_pressed(index: int) -> void:
	if index < 0 or index >= COIN_PACKS.size():
		return
	var row: Dictionary = COIN_PACKS[index]
	status_label.text = "Starting checkout..."
	var payload := {"order_id": "manual_%d" % Time.get_unix_time_from_system()}
	var result: Dictionary = await NakamaService.start_purchase(str(row.get("product_id", "")), "", payload)
	if not result.get("ok", false):
		status_label.text = "Purchase failed."
		return
	var data: Dictionary = result.get("data", {})
	var approval_url := str(data.get("approval_url", "")).strip_edges()
	if not approval_url.is_empty():
		OS.shell_open(approval_url)
		status_label.text = "Complete checkout, then tap Refresh Wallet."
		return
	await NakamaService.refresh_wallet(true)
	status_label.text = "Purchase applied."

func _on_refresh_wallet_pressed() -> void:
	status_label.text = "Refreshing wallet..."
	await NakamaService.refresh_wallet(true)
	status_label.text = "Wallet refreshed."

func _on_buy_neon_pressed() -> void:
	status_label.text = "Purchasing Neon..."
	var result: Dictionary = await NakamaService.purchase_theme("neon", THEME_NEON_COST)
	if not result.get("ok", false):
		status_label.text = "Not enough coins."
		return
	await NakamaService.refresh_wallet(false)
	var shop := NakamaService.get_shop_state()
	ThemeManager.apply_from_shop_state(shop)
	ThemeManager.apply_to_scene(get_tree().current_scene)
	status_label.text = "Neon unlocked."

func _on_preview_neon_pressed() -> void:
	SaveStore.set_equipped_theme("neon")
	ThemeManager.apply_to_scene(get_tree().current_scene)
	status_label.text = "Previewing Neon."

func _on_equip_default_pressed() -> void:
	var result: Dictionary = await NakamaService.equip_theme("default")
	if not result.get("ok", false):
		status_label.text = "Equip failed."
		return
	ThemeManager.apply_from_shop_state(NakamaService.get_shop_state())
	ThemeManager.apply_to_scene(get_tree().current_scene)
	status_label.text = "Default equipped."

func _on_equip_neon_pressed() -> void:
	var result: Dictionary = await NakamaService.equip_theme("neon")
	if not result.get("ok", false):
		status_label.text = "Neon not owned."
		return
	ThemeManager.apply_from_shop_state(NakamaService.get_shop_state())
	ThemeManager.apply_to_scene(get_tree().current_scene)
	status_label.text = "Neon equipped."

func _on_unlock_neon_ad_pressed() -> void:
	_pending_theme_ad_unlock = true
	status_label.text = "Watching rewarded ad..."
	if not AdManager.show_rewarded_for_powerup():
		_pending_theme_ad_unlock = false
		status_label.text = "Ad not ready."

func _on_rewarded_ad_earned() -> void:
	if not _pending_theme_ad_unlock:
		return
	_pending_theme_ad_unlock = false
	var result: Dictionary = await NakamaService.rent_theme_with_ad("neon")
	if not result.get("ok", false):
		status_label.text = "Ad unlock failed."
		return
	ThemeManager.apply_from_shop_state(NakamaService.get_shop_state())
	ThemeManager.apply_to_scene(get_tree().current_scene)
	status_label.text = "Neon unlocked for 24 hours."

func _on_buy_powerup_pressed(powerup_type: String) -> void:
	var cost: int = int(POWERUP_COSTS.get(powerup_type, 0))
	if cost <= 0:
		return
	status_label.text = "Purchasing %s..." % powerup_type
	var purchase_id := "%s_%d" % [powerup_type, Time.get_unix_time_from_system()]
	var result: Dictionary = await NakamaService.purchase_powerup(powerup_type, 1, cost, purchase_id)
	if not result.get("ok", false):
		status_label.text = "Need more coins for %s." % powerup_type
		return
	status_label.text = "%s purchased." % powerup_type.capitalize()

func _on_buy_undo_pressed() -> void:
	await _on_buy_powerup_pressed("undo")

func _on_buy_prism_pressed() -> void:
	await _on_buy_powerup_pressed("prism")

func _on_buy_shuffle_pressed() -> void:
	await _on_buy_powerup_pressed("shuffle")

func _on_close_pressed() -> void:
	ThemeManager.apply_from_shop_state(NakamaService.get_shop_state())
	ThemeManager.apply_to_scene(get_tree().current_scene)
	queue_free()
