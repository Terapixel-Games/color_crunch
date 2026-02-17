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

@onready var status_label: Label = $Panel/VBox/Status
@onready var coins_label: Label = $Panel/VBox/Coins
@onready var owned_label: Label = $Panel/VBox/Scroll/Content/Themes/Owned

var _pending_theme_ad_unlock: bool = false
var _paypal_bridge_initialized := false

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
