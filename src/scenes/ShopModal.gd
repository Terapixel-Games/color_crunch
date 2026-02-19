extends Control

const THEME_NEON_COST := 1500
const POWERUP_COSTS := {
	"undo": 120,
	"prism": 180,
	"shuffle": 140,
}
const COIN_PACKS := [
	{"product_id": "coins_500_color_crunch", "label": "500 - $0.99", "price_usd": 0.99},
	{"product_id": "coins_1200_color_crunch", "label": "1200 - $1.99", "price_usd": 1.99},
	{"product_id": "coins_3000_color_crunch", "label": "3000 - $4.99", "price_usd": 4.99},
	{"product_id": "coins_7500_color_crunch", "label": "7500 - $9.99", "price_usd": 9.99},
	{"product_id": "coins_20000_color_crunch", "label": "20000 - $19.99", "price_usd": 19.99},
]
const ICON_SHEET_PATH := "res://assets/ui/icons/sheet_white2x.png"
const ICON_REGION_STAR := Rect2(100, 1000, 100, 100)
const ICON_REGION_PRISM := Rect2(100, 1000, 100, 100)
const ICON_REGION_UNDO := Rect2(200, 500, 100, 100)
const ICON_REGION_HINT := Rect2(200, 600, 100, 100)
const ICON_REGION_AD_VIDEO := Rect2(0, 1900, 100, 100)

@onready var status_label: Label = $Panel/VBox/Status
@onready var backdrop: ColorRect = $Backdrop
@onready var panel: Control = $Panel
@onready var panel_vbox: VBoxContainer = $Panel/VBox
@onready var top_inset: Control = $Panel/VBox/TopInset
@onready var footer_panel: PanelContainer = $Panel/VBox/Footer
@onready var bottom_inset: Control = $Panel/VBox/BottomInset
@onready var header_bar: Control = $Panel/VBox/Header
@onready var header_divider: Control = $Panel/VBox/HeaderDivider
@onready var scroll_container: ScrollContainer = $Panel/VBox/Scroll
@onready var scroll_content: Control = $Panel/VBox/Scroll/Content
@onready var close_button: Button = $Panel/VBox/Footer/Actions/Close
@onready var header_title: Label = $Panel/VBox/Header/Title
@onready var coins_label: Label = $Panel/VBox/Header/RightSlot/CoinPill/Row/Balance
@onready var refresh_wallet_button: Button = $Panel/VBox/Footer/Actions/RefreshWallet
@onready var theme_default_action: Button = $Panel/VBox/Scroll/Content/Themes/ThemeDefault/Margin/Row/ActionButton
@onready var theme_default_subtitle: Label = $Panel/VBox/Scroll/Content/Themes/ThemeDefault/Margin/Row/Texts/Subtitle
@onready var theme_default_card: Control = $Panel/VBox/Scroll/Content/Themes/ThemeDefault
@onready var theme_neon_action: Button = null
@onready var theme_neon_subtitle: Label = $Panel/VBox/Scroll/Content/Themes/ThemeNeon/Margin/Row/Texts/Subtitle
@onready var theme_neon_card: Control = $Panel/VBox/Scroll/Content/Themes/ThemeNeon
@onready var theme_neon_actions: HBoxContainer = $Panel/VBox/Scroll/Content/Themes/ThemeNeon/Margin/Row/ThemeNeonActions
@onready var theme_neon_ad_unlock: Button = $Panel/VBox/Scroll/Content/Themes/ThemeNeon/Margin/Row/ThemeNeonActions/UnlockNeonAd
@onready var undo_subtitle: Label = $Panel/VBox/Scroll/Content/Powerups/BuyUndo/Margin/Row/Texts/Subtitle
@onready var prism_subtitle: Label = $Panel/VBox/Scroll/Content/Powerups/BuyPrism/Margin/Row/Texts/Subtitle
@onready var shuffle_subtitle: Label = $Panel/VBox/Scroll/Content/Powerups/BuyShuffle/Margin/Row/Texts/Subtitle

var _pending_theme_ad_unlock: bool = false
var _paypal_bridge_initialized := false
var _closing := false
var _open_tween: Tween
var _close_tween: Tween
var _neon_owned := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reap_detached_labels()
	Typography.style_save_streak(self)
	_apply_header_hierarchy()
	_apply_static_shop_styling()
	_bind_theme_action_nodes()
	_ensure_shop_icons()
	_layout_modal()
	call_deferred("_layout_modal")
	header_title.text = "Shop"
	_refresh_panel_pivot()
	call_deferred("_refresh_panel_pivot")
	_play_open_animation()
	if not AdManager.is_connected("rewarded_powerup_earned", Callable(self, "_on_rewarded_ad_earned")):
		AdManager.connect("rewarded_powerup_earned", Callable(self, "_on_rewarded_ad_earned"))
	if not NakamaService.wallet_updated.is_connected(_on_wallet_updated):
		NakamaService.wallet_updated.connect(_on_wallet_updated)
	for i in range(COIN_PACKS.size()):
		var row: Dictionary = COIN_PACKS[i]
		_configure_coin_pack_row(i, row)
	ThemeManager.apply_to_scene(get_tree().current_scene)
	await NakamaService.refresh_wallet(false)
	_on_wallet_updated(NakamaService.get_wallet())

func _reap_detached_labels() -> void:
	# Godot can leave detached Label nodes from nested packed-scene overrides.
	# Reap them proactively so test runs do not accumulate orphans.
	var labels := find_children("*", "Label", true, false)
	for node in labels:
		var label := node as Label
		if label != null and not label.is_inside_tree():
			label.free()

func _on_wallet_updated(wallet: Dictionary) -> void:
	if theme_neon_action == null:
		_bind_theme_action_nodes()
	coins_label.text = str(int(wallet.get("coin_balance", 0)))
	var shop: Dictionary = wallet.get("shop", {})
	var owned: Array = shop.get("ownedThemes", ["default"])
	var equipped := str(shop.get("equippedTheme", "default"))
	_neon_owned = "neon" in owned
	if theme_default_subtitle != null:
		theme_default_subtitle.text = "Equip"
	if theme_neon_subtitle != null:
		theme_neon_subtitle.text = "Equip"
	if theme_default_action != null:
		theme_default_action.disabled = equipped == "default"
		theme_default_action.text = "Equipped" if equipped == "default" else "Equip"
	else:
		push_warning("ShopModal: missing default theme action button node.")
	if theme_neon_action != null:
		theme_neon_action.disabled = _neon_owned and equipped == "neon"
		if _neon_owned:
			theme_neon_action.text = "Equipped" if equipped == "neon" else "Equip"
		else:
			theme_neon_action.text = "Buy"
	else:
		push_warning("ShopModal: missing neon theme action button node.")
	var powerups_var: Variant = shop.get("powerups", {})
	var powerups: Dictionary = powerups_var if typeof(powerups_var) == TYPE_DICTIONARY else {}
	undo_subtitle.text = "Owned: %d  |  %d coins" % [int(powerups.get("undo", 0)), int(POWERUP_COSTS["undo"])]
	prism_subtitle.text = "Owned: %d  |  %d coins" % [int(powerups.get("prism", 0)), int(POWERUP_COSTS["prism"])]
	shuffle_subtitle.text = "Owned: %d  |  %d coins" % [int(powerups.get("shuffle", 0)), int(POWERUP_COSTS["shuffle"])]
	_apply_powerup_typography()

func _bind_theme_action_nodes() -> void:
	theme_neon_action = get_node_or_null(
		"Panel/VBox/Scroll/Content/Themes/ThemeNeon/Margin/Row/ThemeNeonActions/ActionButton"
	) as Button
	if theme_neon_action == null:
		theme_neon_action = get_node_or_null(
			"Panel/VBox/Scroll/Content/Themes/ThemeNeon/Margin/Row/ActionButton"
		) as Button

func _on_coin_pack_pressed(index: int) -> void:
	if index < 0 or index >= COIN_PACKS.size():
		return
	var row: Dictionary = COIN_PACKS[index]
	status_label.text = "Opening PayPal checkout..."
	var checkout: Dictionary = await _start_paypal_checkout(row)
	if not checkout.get("ok", false):
		if checkout.get("cancelled", false):
			status_label.text = "Checkout cancelled."
			return
		var checkout_error := str(checkout.get("error", "")).strip_edges()
		if checkout_error.is_empty():
			status_label.text = "Checkout failed."
		else:
			status_label.text = "Checkout failed: %s" % checkout_error
		return
	var order_id := str(checkout.get("order_id", "")).strip_edges()
	if order_id.is_empty():
		status_label.text = "Checkout failed: missing order id."
		return
	status_label.text = "Verifying purchase..."
	var payload := {"order_id": order_id}
	var result: Dictionary = await NakamaService.start_purchase(str(row.get("product_id", "")), "paypal_web", payload)
	if not result.get("ok", false):
		status_label.text = "Purchase failed."
		return
	await NakamaService.refresh_wallet(true)
	status_label.text = "Purchase applied."

func _start_paypal_checkout(row: Dictionary) -> Dictionary:
	if not _is_web_checkout_supported():
		return {"ok": false, "error": "paypal web checkout is only available in browser builds"}
	var client_id := _resolve_paypal_client_id()
	if client_id.is_empty():
		return {"ok": false, "error": "paypal client id is not configured"}
	var amount := float(row.get("price_usd", 0.0))
	if amount <= 0.0:
		return {"ok": false, "error": "invalid price"}
	_ensure_paypal_bridge()
	if not _paypal_bridge_initialized:
		return {"ok": false, "error": "paypal bridge initialization failed"}

	var checkout_id := "cc_%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec() % 1000000]
	var payload := {
		"checkout_id": checkout_id,
		"client_id": client_id,
		"currency": _resolve_paypal_currency(),
		"product_id": str(row.get("product_id", "")).strip_edges().to_lower(),
		"label": str(row.get("label", "Color Crunch Coins")).strip_edges(),
		"amount": "%.2f" % amount,
	}
	var start_js := (
		"(function(){if(!window.ColorCrunchPayPalBridge){return 'missing';}"
		+ "window.ColorCrunchPayPalBridge.start(%s);return 'ok';})();"
	) % JSON.stringify(payload)
	var start_result := str(JavaScriptBridge.eval(start_js, true))
	if start_result != "ok":
		return {"ok": false, "error": "paypal bridge start failed"}

	var start_time_ms := Time.get_ticks_msec()
	while is_inside_tree() and (Time.get_ticks_msec() - start_time_ms) < 180000:
		var next := _take_paypal_checkout_result(checkout_id)
		if not next.is_empty():
			return next
		await get_tree().create_timer(0.25).timeout
	return {"ok": false, "error": "checkout timed out"}

func _take_paypal_checkout_result(checkout_id: String) -> Dictionary:
	if checkout_id.is_empty():
		return {}
	var js := (
		"(function(){window.__colorCrunchPayPalResults=window.__colorCrunchPayPalResults||{};"
		+ "var key=%s; if(!(key in window.__colorCrunchPayPalResults)){return '';}"
		+ "var out=window.__colorCrunchPayPalResults[key]; delete window.__colorCrunchPayPalResults[key];"
		+ "return JSON.stringify(out);})();"
	) % JSON.stringify(checkout_id)
	var raw: Variant = JavaScriptBridge.eval(js, true)
	if typeof(raw) != TYPE_STRING:
		return {}
	var text := str(raw).strip_edges()
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	return {"ok": false, "error": "invalid checkout payload"}

func _ensure_paypal_bridge() -> void:
	if _paypal_bridge_initialized:
		return
	var bridge_js := """
	(function() {
	  if (window.ColorCrunchPayPalBridge) { return; }
	  window.__colorCrunchPayPalResults = window.__colorCrunchPayPalResults || {};
	  window.ColorCrunchPayPalBridge = {
	    sdkPromise: null,
		sdkKey: "",
	    ensureSdk: function(clientId, currency) {
		  var key = String(clientId || "") + "|" + String(currency || "USD");
	      if (window.paypal && window.paypal.Buttons && this.sdkKey === key) {
	        return Promise.resolve(window.paypal);
	      }
	      if (this.sdkPromise && this.sdkKey === key) {
	        return this.sdkPromise;
	      }
	      this.sdkKey = key;
	      this.sdkPromise = new Promise(function(resolve, reject) {
			var existing = document.querySelector("script[data-cc-paypal='1']");
	        if (existing && window.paypal && window.paypal.Buttons) {
	          resolve(window.paypal);
	          return;
	        }
	        if (existing && !window.paypal) {
	          existing.remove();
	        }
			var script = document.createElement("script");
			script.setAttribute("data-cc-paypal", "1");
			script.crossOrigin = "anonymous";
			script.src = "https://www.paypal.com/sdk/js?client-id="
			  + encodeURIComponent(String(clientId || ""))
			  + "&currency=" + encodeURIComponent(String(currency || "USD"))
			  + "&intent=capture&components=buttons";
	        script.onload = function() {
	          if (window.paypal && window.paypal.Buttons) {
	            resolve(window.paypal);
	          } else {
				reject(new Error("paypal sdk unavailable"));
	          }
	        };
	        script.onerror = function() {
			  reject(new Error("paypal sdk failed to load"));
	        };
	        document.head.appendChild(script);
	      });
	      return this.sdkPromise;
	    },
	    ensureOverlay: function() {
		  var overlay = document.getElementById("cc-paypal-overlay");
	      if (overlay) { return overlay; }
		  overlay = document.createElement("div");
		  overlay.id = "cc-paypal-overlay";
		  overlay.style.position = "fixed";
		  overlay.style.inset = "0";
		  overlay.style.background = "rgba(0, 0, 0, 0.78)";
		  overlay.style.display = "none";
		  overlay.style.alignItems = "center";
		  overlay.style.justifyContent = "center";
		  overlay.style.zIndex = "2147483647";
		  var card = document.createElement("div");
		  card.style.width = "min(92vw, 420px)";
		  card.style.background = "#111827";
		  card.style.border = "1px solid #334155";
		  card.style.borderRadius = "12px";
		  card.style.padding = "16px";
		  card.style.boxSizing = "border-box";
		  var title = document.createElement("div");
		  title.textContent = "Complete purchase";
		  title.style.color = "#e5e7eb";
		  title.style.fontFamily = "system-ui, sans-serif";
		  title.style.fontSize = "18px";
		  title.style.fontWeight = "600";
		  title.style.marginBottom = "12px";
		  var buttonHost = document.createElement("div");
		  buttonHost.id = "cc-paypal-buttons";
		  buttonHost.style.minHeight = "56px";
		  var close = document.createElement("button");
		  close.type = "button";
		  close.textContent = "Cancel";
		  close.style.marginTop = "12px";
		  close.style.width = "100%";
		  close.style.height = "42px";
		  close.style.borderRadius = "8px";
		  close.style.border = "1px solid #475569";
		  close.style.background = "#0f172a";
		  close.style.color = "#e5e7eb";
		  close.style.cursor = "pointer";
	      close.onclick = function() {
			overlay.style.display = "none";
	        if (overlay._checkoutId) {
	          window.__colorCrunchPayPalResults[overlay._checkoutId] = {
	            ok: false,
	            cancelled: true,
				error: "paypal_cancelled"
	          };
	        }
	      };
	      card.appendChild(title);
	      card.appendChild(buttonHost);
	      card.appendChild(close);
	      overlay.appendChild(card);
	      document.body.appendChild(overlay);
	      return overlay;
	    },
	    start: function(opts) {
	      var self = this;
		  var checkoutId = String(opts && opts.checkout_id || "");
		  var clientId = String(opts && opts.client_id || "");
		  var productId = String(opts && opts.product_id || "");
		  var label = String(opts && opts.label || "Color Crunch Coins");
		  var currency = String(opts && opts.currency || "USD").toUpperCase();
		  var amount = String(opts && opts.amount || "0.99");
	      if (!checkoutId) { return; }
	      if (!clientId) {
			window.__colorCrunchPayPalResults[checkoutId] = { ok: false, error: "missing_client_id" };
	        return;
	      }
	      self.ensureSdk(clientId, currency).then(function() {
	        if (!window.paypal || !window.paypal.Buttons) {
			  window.__colorCrunchPayPalResults[checkoutId] = { ok: false, error: "paypal_sdk_unavailable" };
	          return;
	        }
	        var overlay = self.ensureOverlay();
	        overlay._checkoutId = checkoutId;
			overlay.style.display = "flex";
			var host = document.getElementById("cc-paypal-buttons");
	        if (!host) {
			  window.__colorCrunchPayPalResults[checkoutId] = { ok: false, error: "paypal_host_missing" };
			  overlay.style.display = "none";
	          return;
	        }
			host.innerHTML = "";
	        window.paypal.Buttons({
			  style: { layout: "vertical", shape: "rect", label: "paypal" },
	          createOrder: function(_data, actions) {
	            return actions.order.create({
	              purchase_units: [{
	                amount: {
	                  currency_code: currency,
	                  value: amount
	                },
	                description: label,
	                custom_id: productId
	              }]
	            });
	          },
	          onApprove: function(data, actions) {
	            return actions.order.capture().then(function(details) {
				  overlay.style.display = "none";
				  var captureId = "";
	              try {
	                var captures = details.purchase_units[0].payments.captures;
	                if (captures && captures.length > 0) {
					  captureId = String(captures[0].id || "");
	                }
	              } catch (_err) {}
	              window.__colorCrunchPayPalResults[checkoutId] = {
	                ok: true,
					order_id: String(data.orderID || ""),
	                capture_id: captureId,
					status: String(details && details.status || "")
	              };
	            });
	          },
	          onCancel: function() {
				overlay.style.display = "none";
	            window.__colorCrunchPayPalResults[checkoutId] = {
	              ok: false,
	              cancelled: true,
				  error: "paypal_cancelled"
	            };
	          },
	          onError: function(err) {
				overlay.style.display = "none";
	            window.__colorCrunchPayPalResults[checkoutId] = {
	              ok: false,
				  error: "paypal_error",
	              message: String(err && err.message ? err.message : err)
	            };
	          }
	        }).render(host).catch(function(err) {
			  overlay.style.display = "none";
	          window.__colorCrunchPayPalResults[checkoutId] = {
	            ok: false,
				error: "paypal_render_failed",
	            message: String(err && err.message ? err.message : err)
	          };
	        });
	      }).catch(function(err) {
	        window.__colorCrunchPayPalResults[checkoutId] = {
	          ok: false,
			  error: "paypal_sdk_load_failed",
	          message: String(err && err.message ? err.message : err)
	        };
	      });
	    }
	  };
	})();
	"""
	JavaScriptBridge.eval(bridge_js, true)
	_paypal_bridge_initialized = true

func _resolve_paypal_client_id() -> String:
	var from_env := OS.get_environment("COLOR_CRUNCH_PAYPAL_CLIENT_ID").strip_edges()
	if not from_env.is_empty():
		return from_env
	var from_setting := str(_project_setting("color_crunch/paypal_client_id", "")).strip_edges()
	if not from_setting.is_empty():
		return from_setting
	if _is_web_checkout_supported():
		var from_window: Variant = JavaScriptBridge.eval(
			"(function(){return String(window.COLOR_CRUNCH_PAYPAL_CLIENT_ID || window.TPX_PAYPAL_CLIENT_ID || '');})();",
			true
		)
		if typeof(from_window) == TYPE_STRING:
			var val := str(from_window).strip_edges()
			if not val.is_empty():
				return val
	return ""

func _resolve_paypal_currency() -> String:
	var currency := str(_project_setting("color_crunch/paypal_currency", "USD")).strip_edges().to_upper()
	if currency.is_empty():
		return "USD"
	return currency

func _is_web_checkout_supported() -> bool:
	return OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge")

func _project_setting(key: String, default_value: Variant) -> Variant:
	if ProjectSettings.has_setting(key):
		return ProjectSettings.get_setting(key)
	return default_value

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

func _on_theme_neon_action_pressed() -> void:
	if _neon_owned:
		await _on_equip_neon_pressed()
	else:
		await _on_buy_neon_pressed()

func _on_preview_neon_pressed() -> void:
	SaveStore.set_equipped_theme("neon")
	ThemeManager.apply_to_scene(get_tree().current_scene)
	status_label.text = "Previewing Neon."

func _on_theme_neon_row_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if theme_neon_actions != null and theme_neon_actions.get_global_rect().has_point(mouse_event.global_position):
				return
			_on_preview_neon_pressed()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			if theme_neon_actions != null and theme_neon_actions.get_global_rect().has_point(touch_event.position):
				return
			_on_preview_neon_pressed()

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
	await NakamaService.refresh_wallet(false)
	status_label.text = "%s purchased." % powerup_type.capitalize()

func _on_buy_undo_pressed() -> void:
	await _on_buy_powerup_pressed("undo")

func _on_buy_prism_pressed() -> void:
	await _on_buy_powerup_pressed("prism")

func _on_buy_shuffle_pressed() -> void:
	await _on_buy_powerup_pressed("shuffle")

func _on_close_pressed() -> void:
	if _closing:
		return
	_closing = true
	if is_instance_valid(_open_tween):
		_open_tween.kill()
	ThemeManager.apply_from_shop_state(NakamaService.get_shop_state())
	ThemeManager.apply_to_scene(get_tree().current_scene)
	_close_tween = create_tween()
	_close_tween.set_parallel(true)
	_close_tween.tween_property(panel, "scale", Vector2(0.98, 0.98), 0.14)
	_close_tween.tween_property(panel, "modulate:a", 0.0, 0.14)
	_close_tween.tween_property(backdrop, "modulate:a", 0.0, 0.14)
	_close_tween.finished.connect(queue_free)

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_layout_modal()
		_refresh_panel_pivot()

func _layout_modal() -> void:
	if panel == null or panel_vbox == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	_layout_modal_for_size(viewport_size)

func _layout_modal_for_size(viewport_size: Vector2) -> void:
	if panel == null or panel_vbox == null:
		return
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var viewport_aspect: float = viewport_size.x / max(1.0, viewport_size.y)
	var is_wide: bool = viewport_aspect >= 1.5
	var outer_margin_x: float = clamp(viewport_size.x * (0.03 if is_wide else 0.04), 18.0, 48.0)
	var outer_margin_y: float = clamp(viewport_size.y * 0.04, 14.0, 30.0)
	var panel_max_width_cap: float = 1460.0 if is_wide else viewport_size.x - 12.0
	var panel_width: float = clamp(
		viewport_size.x - (outer_margin_x * 2.0),
		420.0,
		min(panel_max_width_cap, viewport_size.x - 12.0)
	)
	var max_panel_height: float = clamp(viewport_size.y - (outer_margin_y * 2.0), 520.0, viewport_size.y - 12.0)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(panel_width, max_panel_height)
	panel.position = (viewport_size - panel.size) * 0.5

	var margin_x: float = clamp(panel_width * (0.032 if is_wide else 0.07), 16.0, 34.0)
	var panel_inner_width: float = max(280.0, panel_width - (margin_x * 2.0))
	var content_inset: float = clamp(panel_inner_width * (0.012 if is_wide else 0.03), 8.0, 24.0)
	var content_width: float = clamp(panel_inner_width - (content_inset * 2.0), 280.0, panel_inner_width)
	# Match top/bottom inside spacing to the effective side spacing (panel inset + content inset).
	var inside_edge_padding: float = margin_x + content_inset
	panel_vbox.add_theme_constant_override("separation", int(round(clamp(max_panel_height * 0.01, 8.0, 12.0))))
	if scroll_content is VBoxContainer:
		(scroll_content as VBoxContainer).add_theme_constant_override(
			"separation",
			int(round(clamp(max_panel_height * (0.008 if is_wide else 0.01), 8.0, 12.0)))
		)
	if header_bar != null:
		header_bar.custom_minimum_size.y = clamp(max_panel_height * (0.105 if is_wide else 0.12), 68.0, 90.0)
	if top_inset != null:
		top_inset.custom_minimum_size.y = inside_edge_padding
	if bottom_inset != null:
		bottom_inset.custom_minimum_size.y = inside_edge_padding
	for path in [
		"Panel/VBox/Header",
		"Panel/VBox/Status",
		"Panel/VBox/HeaderDivider",
		"Panel/VBox/Scroll/Content/CoinPacksHeader",
		"Panel/VBox/Scroll/Content/CoinPacks",
		"Panel/VBox/Scroll/Content/ThemesHeader",
		"Panel/VBox/Scroll/Content/Themes",
		"Panel/VBox/Scroll/Content/PowerupsHeader",
		"Panel/VBox/Scroll/Content/Powerups",
		"Panel/VBox/Footer",
	]:
		_apply_centered_content_width(path, content_width)

	if footer_panel != null:
		footer_panel.custom_minimum_size.y = clamp(max_panel_height * (0.1 if is_wide else 0.12), 96.0, 118.0)

	if close_button != null:
		close_button.size_flags_horizontal = Control.SIZE_FILL
		close_button.custom_minimum_size = Vector2(0.0, clamp(max_panel_height * 0.055, 48.0, 56.0))
		close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Keep theme item rows tall enough for title/subtitle + action controls.
	if theme_default_card != null:
		theme_default_card.custom_minimum_size.y = clamp(max_panel_height * (0.082 if is_wide else 0.092), 78.0, 96.0)
	if theme_neon_card != null:
		theme_neon_card.custom_minimum_size.y = clamp(max_panel_height * (0.086 if is_wide else 0.096), 82.0, 100.0)

	var row_inner_width: float = max(320.0, content_width - 12.0)
	var action_gap: int = 10
	var primary_action_width: float = clamp(row_inner_width * (0.18 if is_wide else 0.24), 102.0, 140.0)
	var ad_badge_width: float = clamp(row_inner_width * (0.12 if is_wide else 0.16), 82.0, 108.0)
	var action_height: float = clamp(max_panel_height * (0.042 if is_wide else 0.045), 44.0, 52.0)

	if theme_default_action != null:
		theme_default_action.custom_minimum_size = Vector2(primary_action_width, action_height)
		theme_default_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_apply_button_variant(theme_default_action, "primary")

	if theme_neon_actions != null:
		theme_neon_actions.add_theme_constant_override("separation", action_gap)
		theme_neon_actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if theme_neon_action != null:
		theme_neon_action.custom_minimum_size = Vector2(primary_action_width, action_height)
		theme_neon_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_apply_button_variant(theme_neon_action, "primary")
	if theme_neon_ad_unlock != null:
		theme_neon_ad_unlock.custom_minimum_size = Vector2(ad_badge_width, max(48.0, action_height))
		theme_neon_ad_unlock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_apply_button_variant(theme_neon_ad_unlock, "badge")

	for index in range(COIN_PACKS.size()):
		var coin_card := get_node_or_null("Panel/VBox/Scroll/Content/CoinPacks/Pack%d" % index) as Control
		if coin_card != null:
			coin_card.custom_minimum_size.y = clamp(max_panel_height * (0.074 if is_wide else 0.082), 68.0, 84.0)
		var coin_button := get_node_or_null("Panel/VBox/Scroll/Content/CoinPacks/Pack%d/Margin/Row/ActionButton" % index) as Button
		if coin_button != null:
			coin_button.custom_minimum_size = Vector2(clamp(primary_action_width, 106.0, 136.0), clamp(action_height, 44.0, 52.0))
			coin_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_apply_button_variant(coin_button, "primary")

	for path in [
		"Panel/VBox/Scroll/Content/Powerups/BuyUndo",
		"Panel/VBox/Scroll/Content/Powerups/BuyPrism",
		"Panel/VBox/Scroll/Content/Powerups/BuyShuffle",
	]:
		var card := get_node_or_null(path) as Control
		if card != null:
			card.custom_minimum_size.y = clamp(max_panel_height * (0.067 if is_wide else 0.074), 62.0, 74.0)

	for button in [
		get_node_or_null("Panel/VBox/Scroll/Content/Powerups/BuyUndo/Margin/Row/ActionButton") as Button,
		get_node_or_null("Panel/VBox/Scroll/Content/Powerups/BuyPrism/Margin/Row/ActionButton") as Button,
		get_node_or_null("Panel/VBox/Scroll/Content/Powerups/BuyShuffle/Margin/Row/ActionButton") as Button,
		refresh_wallet_button,
	]:
		if button == null:
			continue
		if button == refresh_wallet_button:
			button.custom_minimum_size = Vector2(0.0, clamp(max_panel_height * 0.05, 44.0, 50.0))
			button.size_flags_horizontal = Control.SIZE_FILL
			_apply_button_variant(button, "ghost")
		else:
			button.custom_minimum_size = Vector2(112.0, clamp(max_panel_height * 0.052, 46.0, 52.0))
			_apply_button_variant(button, "secondary")
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Shrink the glass panel to fit content + equal inner top/bottom padding.
	var vbox_separation: float = float(panel_vbox.get_theme_constant("separation"))
	var non_scroll_height: float = 0.0
	var visible_vbox_children: int = 0
	for child in panel_vbox.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		visible_vbox_children += 1
		if control == scroll_container:
			continue
		non_scroll_height += control.get_combined_minimum_size().y

	var scroll_content_height: float = 0.0
	if scroll_content != null:
		scroll_content_height = scroll_content.get_combined_minimum_size().y
	if scroll_container != null:
		scroll_container.custom_minimum_size.y = 0.0

	var gap_count: int = max(0, visible_vbox_children - 1)
	var inner_height_target: float = non_scroll_height + scroll_content_height + (vbox_separation * float(gap_count))
	var target_panel_height: float = inner_height_target
	panel.size = Vector2(panel_width, min(target_panel_height, max_panel_height))
	panel.position = (viewport_size - panel.size) * 0.5

func _refresh_panel_pivot() -> void:
	if panel == null:
		return
	if panel.size.x <= 0.0 or panel.size.y <= 0.0:
		return
	panel.pivot_offset = panel.size * 0.5

func _play_open_animation() -> void:
	panel.scale = Vector2(0.98, 0.98)
	panel.modulate.a = 0.0
	backdrop.modulate.a = 0.0
	_open_tween = create_tween()
	_open_tween.set_parallel(true)
	_open_tween.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	_open_tween.tween_property(backdrop, "modulate:a", 1.0, 0.18)

func _ensure_shop_icons() -> void:
	var force_assign := OS.has_feature("android")
	var coin_icon_paths := [
		"res://assets/ui/icons/coin_26.png",
		"res://assets/ui/icons/coin_27.png",
		"res://assets/ui/icons/coin_28.png",
		"res://assets/ui/icons/coin_29.png",
		"res://assets/ui/icons/coin_30.png",
	]
	for i in range(coin_icon_paths.size()):
		var coin_texture := load(coin_icon_paths[i]) as Texture2D
		_set_texture_rect_icon(
			"Panel/VBox/Scroll/Content/CoinPacks/Pack%d/Margin/Row/Icon" % i,
			coin_texture,
			force_assign
		)

	# Keep the header coin pill icon resilient on mobile exports.
	_set_texture_rect_icon("Panel/VBox/Header/RightSlot/CoinPill/Row/CoinIcon", load(coin_icon_paths[0]) as Texture2D, force_assign)

	var star_icon := _atlas_from_sheet(ICON_REGION_STAR)
	var prism_icon := _atlas_from_sheet(ICON_REGION_PRISM)
	var undo_icon := _atlas_from_sheet(ICON_REGION_UNDO)
	var hint_icon := _atlas_from_sheet(ICON_REGION_HINT)
	var ad_icon := _atlas_from_sheet(ICON_REGION_AD_VIDEO)

	_set_texture_rect_icon("Panel/VBox/Scroll/Content/Themes/ThemeDefault/Margin/Row/Icon", star_icon, force_assign)
	_set_texture_rect_icon("Panel/VBox/Scroll/Content/Themes/ThemeNeon/Margin/Row/Icon", prism_icon, force_assign)
	_set_texture_rect_icon("Panel/VBox/Scroll/Content/Powerups/BuyUndo/Margin/Row/Icon", undo_icon, force_assign)
	_set_texture_rect_icon("Panel/VBox/Scroll/Content/Powerups/BuyPrism/Margin/Row/Icon", prism_icon, force_assign)
	_set_texture_rect_icon("Panel/VBox/Scroll/Content/Powerups/BuyShuffle/Margin/Row/Icon", hint_icon, force_assign)
	_set_button_icon("Panel/VBox/Scroll/Content/Themes/ThemeNeon/Margin/Row/ThemeNeonActions/UnlockNeonAd", ad_icon, force_assign)

func _atlas_from_sheet(region: Rect2) -> Texture2D:
	var sheet := load(ICON_SHEET_PATH) as Texture2D
	if sheet == null:
		return null
	var tex := AtlasTexture.new()
	tex.atlas = sheet
	tex.region = region
	return tex

func _set_texture_rect_icon(node_path: String, texture: Texture2D, force_assign: bool) -> void:
	var icon := get_node_or_null(node_path) as TextureRect
	if icon == null or texture == null:
		return
	if not force_assign and icon.texture != null:
		return
	icon.texture = texture
	icon.modulate = Color(1, 1, 1, 1)

func _set_button_icon(node_path: String, texture: Texture2D, force_assign: bool) -> void:
	var button := get_node_or_null(node_path) as Button
	if button == null or texture == null:
		return
	if not force_assign and button.icon != null:
		return
	button.icon = texture
	button.expand_icon = true

func _configure_coin_pack_row(index: int, row: Dictionary) -> void:
	var title_label := get_node_or_null("Panel/VBox/Scroll/Content/CoinPacks/Pack%d/Margin/Row/Texts/Title" % index) as Label
	var subtitle_label := get_node_or_null("Panel/VBox/Scroll/Content/CoinPacks/Pack%d/Margin/Row/Texts/Subtitle" % index) as Label
	var button := get_node_or_null("Panel/VBox/Scroll/Content/CoinPacks/Pack%d/Margin/Row/ActionButton" % index) as Button
	if title_label == null or subtitle_label == null or button == null:
		return
	var label := str(row.get("label", "Pack"))
	var parts := label.split(" - ")
	if parts.size() >= 2:
		title_label.text = parts[0]
		subtitle_label.text = parts[1]
	else:
		title_label.text = label
		subtitle_label.text = "$0.00"
	button.text = "Buy"
	Typography.style_label(title_label, 19.0, Typography.WEIGHT_BOLD)
	Typography.style_label(subtitle_label, 14.0, Typography.WEIGHT_MEDIUM, true)
	Typography.style_button(button, 16.0, Typography.WEIGHT_SEMIBOLD)

func _apply_header_hierarchy() -> void:
	Typography.style_label(header_title, 34.0, Typography.WEIGHT_BOLD)
	if refresh_wallet_button != null:
		Typography.style_button(refresh_wallet_button, 14.0, Typography.WEIGHT_MEDIUM)
		refresh_wallet_button.text = "Refresh Wallet"
	coins_label.add_theme_color_override("font_color", Color(0.97, 0.99, 1.0, 1.0))
	coins_label.add_theme_color_override("font_outline_color", Color(0.06, 0.1, 0.2, 0.9))
	coins_label.add_theme_constant_override("outline_size", 2)
	Typography.style_label(coins_label, 18.0, Typography.WEIGHT_BOLD)

func _apply_static_shop_styling() -> void:
	status_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 0.9))
	status_label.add_theme_color_override("font_outline_color", Color(0.08, 0.14, 0.28, 0.92))
	status_label.add_theme_constant_override("outline_size", 2)
	Typography.style_label(status_label, 14.0, Typography.WEIGHT_MEDIUM, true)
	for header_path in [
		"Panel/VBox/Scroll/Content/CoinPacksHeader/Label",
		"Panel/VBox/Scroll/Content/ThemesHeader/Label",
		"Panel/VBox/Scroll/Content/PowerupsHeader/Label",
	]:
		var label := get_node_or_null(header_path) as Label
		if label != null:
			Typography.style_label(label, 18.0, Typography.WEIGHT_SEMIBOLD)

func _apply_powerup_typography() -> void:
	for path in [
		"Panel/VBox/Scroll/Content/Powerups/BuyUndo",
		"Panel/VBox/Scroll/Content/Powerups/BuyPrism",
		"Panel/VBox/Scroll/Content/Powerups/BuyShuffle",
	]:
		var title := get_node_or_null("%s/Margin/Row/Texts/Title" % path) as Label
		var subtitle := get_node_or_null("%s/Margin/Row/Texts/Subtitle" % path) as Label
		var button := get_node_or_null("%s/Margin/Row/ActionButton" % path) as Button
		if title != null:
			Typography.style_label(title, 18.0, Typography.WEIGHT_BOLD)
		if subtitle != null:
			Typography.style_label(subtitle, 14.0, Typography.WEIGHT_MEDIUM, true)
		if button != null:
			Typography.style_button(button, 16.0, Typography.WEIGHT_SEMIBOLD)

func _apply_button_variant(button: Button, variant: String) -> void:
	if button == null:
		return
	var base := Color(0.12, 0.2, 0.38, 0.58)
	var edge := Color(0.9, 0.96, 1.0, 0.62)
	var font := Color(0.98, 0.99, 1.0, 1.0)
	var shadow := Color(0.03, 0.07, 0.16, 0.36)
	var corner := 18
	match variant:
		"secondary":
			base = Color(0.11, 0.18, 0.34, 0.48)
			edge = Color(0.86, 0.93, 1.0, 0.5)
			shadow = Color(0.03, 0.06, 0.14, 0.28)
		"ghost":
			base = Color(0.09, 0.14, 0.27, 0.28)
			edge = Color(0.86, 0.93, 1.0, 0.4)
			shadow = Color(0.03, 0.05, 0.12, 0.16)
			font = Color(0.9, 0.95, 1.0, 0.95)
			corner = 999
		"badge":
			base = Color(0.12, 0.18, 0.34, 0.4)
			edge = Color(0.89, 0.96, 1.0, 0.42)
			shadow = Color(0.03, 0.05, 0.12, 0.2)
			font = Color(0.9, 0.95, 1.0, 0.95)
			corner = 999
	var normal := StyleBoxFlat.new()
	normal.bg_color = base
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = edge
	normal.corner_radius_top_left = corner
	normal.corner_radius_top_right = corner
	normal.corner_radius_bottom_right = corner
	normal.corner_radius_bottom_left = corner
	normal.shadow_color = shadow
	normal.shadow_size = 3
	normal.anti_aliasing = true
	normal.anti_aliasing_size = 1.1

	var hover := normal.duplicate()
	hover.bg_color = base.lightened(0.08)
	hover.border_color = edge.lightened(0.14)
	var pressed := normal.duplicate()
	pressed.bg_color = base.darkened(0.12)
	var disabled_style := normal.duplicate()
	disabled_style.bg_color = base.darkened(0.15)
	disabled_style.border_color = edge * Color(1.0, 1.0, 1.0, 0.65)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_hover_color", font)
	button.add_theme_color_override("font_pressed_color", font)
	button.add_theme_color_override("font_focus_color", font)
	button.add_theme_color_override("font_disabled_color", font * Color(1.0, 1.0, 1.0, 0.8))
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.16, 0.9))
	button.add_theme_constant_override("outline_size", 2)
	if button.has_method("_sync_glass_state"):
		button.call_deferred("_sync_glass_state")

func _apply_centered_content_width(path: String, width: float) -> void:
	var control := get_node_or_null(path) as Control
	if control == null:
		return
	control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	control.custom_minimum_size.x = width

func _exit_tree() -> void:
	if is_instance_valid(_open_tween):
		_open_tween.kill()
	if is_instance_valid(_close_tween):
		_close_tween.kill()
