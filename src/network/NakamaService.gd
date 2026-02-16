extends Node

signal online_state_changed(status: String)
signal auth_state_changed(is_authenticated: bool, user_id: String)
signal high_score_updated(record: Dictionary)
signal leaderboard_updated(records: Array)
signal profile_upgraded(success: bool, message: String)
signal entitlements_updated(entitlements: Array)
signal wallet_updated(wallet: Dictionary)
signal username_updated(username: String)

const DEFAULT_BASE_URL := "http://127.0.0.1:7350"
const DEFAULT_SERVER_KEY := "colorcrunch-dev-key"
const DEFAULT_LEADERBOARD_LIMIT := 10
const DEFAULT_EXPORT_TARGET := "web"
var PROVIDERS_BY_EXPORT_TARGET := {
	"ios": ["apple"],
	"android": ["google"],
	"poki": ["paypal_web"],
	"crazygames": ["paypal_web"],
	"web": ["paypal_web"],
}

var _base_url: String = DEFAULT_BASE_URL
var _server_key: String = DEFAULT_SERVER_KEY
var _leaderboard_limit: int = DEFAULT_LEADERBOARD_LIMIT
var _connect_enabled: bool = false
var _export_target: String = DEFAULT_EXPORT_TARGET

var _session_token: String = ""
var _refresh_token: String = ""
var _user_id: String = ""
var _username: String = ""
var _is_authenticated := false
var _online_status := "Offline"

var _my_high_score: Dictionary = {}
var _leaderboard_records: Array = []
var _entitlements: Array = []
var _wallet: Dictionary = {
	"coin_balance": 0,
	"shop": {
		"ownedThemes": ["default"],
		"equippedTheme": "default",
		"themeRentals": {},
		"powerups": {"undo": 0, "prism": 0, "shuffle": 0},
	},
}

func _ready() -> void:
	_read_runtime_settings()
	if _connect_enabled:
		call_deferred("_bootstrap")

func _bootstrap() -> void:
	await ensure_authenticated()
	if _is_authenticated:
		await refresh_my_high_score()
		await refresh_leaderboard(_leaderboard_limit)
		await refresh_entitlements(false)
		await refresh_wallet(false)

func get_online_status() -> String:
	return _online_status

func get_my_high_score() -> Dictionary:
	return _my_high_score.duplicate(true)

func get_leaderboard_records() -> Array:
	return _leaderboard_records.duplicate(true)

func get_is_authenticated() -> bool:
	return _is_authenticated

func get_username() -> String:
	return _username

func get_entitlements() -> Array:
	return _entitlements.duplicate(true)

func get_wallet() -> Dictionary:
	return _wallet.duplicate(true)

func get_coin_balance() -> int:
	return int(_wallet.get("coin_balance", 0))

func get_shop_state() -> Dictionary:
	var shop: Variant = _wallet.get("shop", {})
	if typeof(shop) == TYPE_DICTIONARY:
		return (shop as Dictionary).duplicate(true)
	return {}

func has_entitlement(entitlement_key: String) -> bool:
	var key := entitlement_key.strip_edges().to_lower()
	if key.is_empty():
		return false
	for row_var in _entitlements:
		if typeof(row_var) == TYPE_DICTIONARY:
			var row: Dictionary = row_var
			var row_key := str(row.get("entitlementKey", "")).to_lower()
			var state := str(row.get("state", "active")).to_lower()
			if row_key == key and state == "active":
				return true
	return false

func is_guest_account() -> bool:
	return SaveStore.get_terapixel_user_id().is_empty()

func set_terapixel_identity(user_id: String, display_name: String = "") -> void:
	SaveStore.set_terapixel_identity(user_id, display_name)

func upgrade_guest_to_full_profile(terapixel_user_id: String, display_name: String = "", custom_id: String = "") -> Dictionary:
	var tpx_user_id := terapixel_user_id.strip_edges()
	if tpx_user_id.is_empty():
		var bad := {"ok": false, "error": "missing terapixel_user_id"}
		profile_upgraded.emit(false, "missing terapixel_user_id")
		return bad
	if not await ensure_authenticated():
		var auth_bad := {"ok": false, "error": "auth failed"}
		profile_upgraded.emit(false, "auth failed")
		return auth_bad

	_set_online_state("Upgrading profile...")
	var link_id := custom_id.strip_edges()
	if link_id.is_empty():
		link_id = "tpx:%s" % tpx_user_id

	var link_payload := {
		"id": link_id,
		"vars": {
			"platform": str(_project_setting("color_crunch/platform", "terapixel")),
			"game": "color_crunch",
			"terapixel_user_id": tpx_user_id,
		},
	}
	var link_result: Dictionary = await _request_json(
		HTTPClient.METHOD_POST,
		"/v2/account/link/custom",
		JSON.stringify(link_payload),
		_bearer_auth_headers()
	)
	if not link_result.get("ok", false):
		_set_online_state("Connected")
		profile_upgraded.emit(false, "link failed")
		return link_result

	var username := _sanitize_username(display_name if not display_name.is_empty() else ("Player-%s" % link_id.right(8)))
	var update_payload := {
		"username": username,
		"display_name": display_name,
	}
	var update_result: Dictionary = await _request_json(
		HTTPClient.METHOD_PUT,
		"/v2/account",
		JSON.stringify(update_payload),
		_bearer_auth_headers()
	)
	if not update_result.get("ok", false):
		_set_online_state("Connected")
		profile_upgraded.emit(false, "profile update failed")
		return update_result

	SaveStore.set_terapixel_identity(tpx_user_id, display_name)
	await refresh_my_high_score()
	await refresh_leaderboard(_leaderboard_limit)
	_set_online_state("Connected")
	profile_upgraded.emit(true, "ok")
	return {"ok": true, "custom_id": link_id, "username": username}

func ensure_authenticated() -> bool:
	if not _connect_enabled:
		_set_online_state("Online disabled")
		return false
	if _is_authenticated and not _session_token.is_empty():
		return true

	_set_online_state("Connecting...")
	var result: Dictionary = await _authenticate_device()
	if not result.get("ok", false):
		_set_online_state("Offline")
		_is_authenticated = false
		auth_state_changed.emit(false, "")
		return false

	_set_online_state("Connected")
	_is_authenticated = true
	auth_state_changed.emit(true, _user_id)
	return true

func submit_score_background(score: int, metadata: Dictionary = {}) -> void:
	call_deferred("_submit_score_background", score, metadata.duplicate(true))

func _submit_score_background(score: int, metadata: Dictionary = {}) -> void:
	await submit_score(score, metadata)

func submit_score(score: int, metadata: Dictionary = {}) -> Dictionary:
	if score < 0:
		return {"ok": false, "error": "invalid score"}
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}

	_set_online_state("Syncing score...")
	var payload := {
		"score": score,
		"subscore": max(0, StreakManager.get_streak_days()),
		"metadata": _augment_metadata(metadata),
	}
	var rpc: Dictionary = await _rpc_call("tpx_submit_score", payload, true, true)
	if not rpc.get("ok", false):
		_set_online_state("Connected")
		return rpc

	var data: Variant = rpc.get("data", {})
	if typeof(data) == TYPE_DICTIONARY and data.has("record"):
		_my_high_score = data["record"]
		high_score_updated.emit(_my_high_score.duplicate(true))

	_set_online_state("Connected")
	return rpc

func refresh_my_high_score() -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	var rpc: Dictionary = await _rpc_call("tpx_get_my_high_score", {}, true, true)
	if not rpc.get("ok", false):
		return rpc

	var data: Variant = rpc.get("data", {})
	if typeof(data) == TYPE_DICTIONARY and data.has("highScore"):
		if typeof(data["highScore"]) == TYPE_DICTIONARY:
			_my_high_score = data["highScore"]
		else:
			_my_high_score = {}
		high_score_updated.emit(_my_high_score.duplicate(true))
	return rpc

func refresh_leaderboard(limit: int = DEFAULT_LEADERBOARD_LIMIT) -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	if limit <= 0:
		limit = DEFAULT_LEADERBOARD_LIMIT
	if limit > 100:
		limit = 100

	var rpc: Dictionary = await _rpc_call("tpx_list_leaderboard", {"limit": limit}, true, true)
	if not rpc.get("ok", false):
		return rpc

	var data: Variant = rpc.get("data", {})
	if typeof(data) == TYPE_DICTIONARY and data.has("records") and typeof(data["records"]) == TYPE_ARRAY:
		_leaderboard_records = data["records"]
		leaderboard_updated.emit(_leaderboard_records.duplicate(true))
	return rpc

func get_export_target() -> String:
	return _export_target

func get_allowed_iap_providers() -> PackedStringArray:
	if PROVIDERS_BY_EXPORT_TARGET.has(_export_target):
		return PackedStringArray(PROVIDERS_BY_EXPORT_TARGET[_export_target])
	return PackedStringArray(PROVIDERS_BY_EXPORT_TARGET[DEFAULT_EXPORT_TARGET])

func start_purchase(product_id: String, provider: String = "", purchase_payload: Dictionary = {}) -> Dictionary:
	var cleaned_product := product_id.strip_edges().to_lower()
	if cleaned_product.is_empty():
		return {"ok": false, "error": "missing product_id"}
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	var allowed := get_allowed_iap_providers()
	var selected_provider := provider.strip_edges().to_lower()
	if selected_provider.is_empty() and allowed.size() > 0:
		selected_provider = str(allowed[0])
	if not allowed.has(selected_provider):
		return {
			"ok": false,
			"error": "provider not allowed for export target",
			"provider": selected_provider,
			"export_target": _export_target,
		}

	var payload := {
		"product_id": cleaned_product,
		"provider": selected_provider,
		"export_target": _export_target,
		"payload": purchase_payload.duplicate(true),
	}
	var rpc: Dictionary = await _rpc_call("tpx_iap_purchase_start", payload, true, true)
	return rpc

func refresh_entitlements(force_refresh: bool = true) -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}

	var payload := {"force_refresh": force_refresh}
	var rpc: Dictionary = await _rpc_call("tpx_iap_get_entitlements", payload, true, true)
	if not rpc.get("ok", false):
		return rpc

	var data: Variant = rpc.get("data", {})
	if typeof(data) == TYPE_DICTIONARY and data.has("entitlements"):
		var entitlements_value: Variant = data["entitlements"]
		if typeof(entitlements_value) == TYPE_ARRAY:
			_entitlements = entitlements_value.duplicate(true)
		elif typeof(entitlements_value) == TYPE_DICTIONARY:
			_entitlements = [entitlements_value.duplicate(true)]
		else:
			_entitlements = []
	else:
		_entitlements = []
	entitlements_updated.emit(_entitlements.duplicate(true))
	return rpc

func refresh_wallet(force_refresh: bool = false) -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	var rpc: Dictionary = await _rpc_call("tpx_wallet_get", {"force_refresh": force_refresh}, true, true)
	if not rpc.get("ok", false):
		return rpc
	var data: Variant = rpc.get("data", {})
	if typeof(data) == TYPE_DICTIONARY:
		var wallet: Dictionary = _wallet.duplicate(true)
		wallet["coin_balance"] = int((data as Dictionary).get("coinBalance", 0))
		var shop_var: Variant = (data as Dictionary).get("shop", {})
		if typeof(shop_var) == TYPE_DICTIONARY:
			wallet["shop"] = (shop_var as Dictionary).duplicate(true)
		_wallet = wallet
		SaveStore.set_coins(int(_wallet.get("coin_balance", 0)))
		if typeof(_wallet.get("shop", {})) == TYPE_DICTIONARY:
			var shop_dict: Dictionary = _wallet.get("shop", {})
			var owned_var: Variant = shop_dict.get("ownedThemes", ["default"])
			if typeof(owned_var) == TYPE_ARRAY:
				SaveStore.set_owned_themes(owned_var as Array)
			SaveStore.set_equipped_theme(str(shop_dict.get("equippedTheme", "default")))
			var rentals_var: Variant = shop_dict.get("themeRentals", {})
			if typeof(rentals_var) == TYPE_DICTIONARY:
				SaveStore.set_theme_rentals(rentals_var as Dictionary)
			var powerups_var: Variant = shop_dict.get("powerups", {})
			if typeof(powerups_var) == TYPE_DICTIONARY:
				SaveStore.set_owned_powerups(powerups_var as Dictionary)
		var ent_var: Variant = (data as Dictionary).get("entitlements", {})
		if typeof(ent_var) == TYPE_DICTIONARY:
			_entitlements = [ent_var.duplicate(true)]
		elif typeof(ent_var) == TYPE_ARRAY:
			_entitlements = ent_var.duplicate(true)
		wallet_updated.emit(_wallet.duplicate(true))
		entitlements_updated.emit(_entitlements.duplicate(true))
	return rpc

func claim_run_reward(score: int, streak_days: int, completed_by_gameplay: bool, double_reward: bool, run_id: String) -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	var payload := {
		"score": score,
		"streak_days": streak_days,
		"completed_by_gameplay": completed_by_gameplay,
		"double_reward": double_reward,
		"run_id": run_id.strip_edges(),
	}
	var rpc: Dictionary = await _rpc_call("tpx_wallet_claim_run_reward", payload, true, true)
	if rpc.get("ok", false):
		await refresh_wallet(false)
	return rpc

func purchase_theme(theme_id: String, cost_coins: int) -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	var payload := {
		"theme_id": theme_id.strip_edges().to_lower(),
		"cost_coins": cost_coins,
	}
	var rpc: Dictionary = await _rpc_call("tpx_shop_purchase_theme", payload, true, true)
	if rpc.get("ok", false):
		await refresh_wallet(false)
	return rpc

func equip_theme(theme_id: String) -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	var payload := {
		"theme_id": theme_id.strip_edges().to_lower(),
	}
	var rpc: Dictionary = await _rpc_call("tpx_shop_equip_theme", payload, true, true)
	if rpc.get("ok", false):
		await refresh_wallet(false)
	return rpc

func rent_theme_with_ad(theme_id: String) -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	var payload := {
		"theme_id": theme_id.strip_edges().to_lower(),
	}
	var rpc: Dictionary = await _rpc_call("tpx_shop_rent_theme_ad", payload, true, true)
	if rpc.get("ok", false):
		await refresh_wallet(false)
	return rpc

func purchase_powerup(powerup_type: String, quantity: int, cost_coins: int, purchase_id: String = "") -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	var payload := {
		"powerup_type": powerup_type.strip_edges().to_lower(),
		"quantity": max(1, quantity),
		"cost_coins": max(0, cost_coins),
		"purchase_id": purchase_id.strip_edges(),
	}
	var rpc: Dictionary = await _rpc_call("tpx_shop_purchase_powerup", payload, true, true)
	if rpc.get("ok", false):
		await refresh_wallet(false)
	return rpc

func consume_powerup(powerup_type: String, quantity: int = 1) -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	var payload := {
		"powerup_type": powerup_type.strip_edges().to_lower(),
		"quantity": max(1, quantity),
	}
	var rpc: Dictionary = await _rpc_call("tpx_shop_consume_powerup", payload, true, true)
	if rpc.get("ok", false):
		await refresh_wallet(false)
	return rpc

func start_magic_link(email: String) -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	var payload := {"email": email.strip_edges().to_lower()}
	return await _rpc_call("tpx_account_magic_link_start", payload, true, true)

func complete_magic_link(ml_token: String) -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	var payload := {"ml_token": ml_token.strip_edges()}
	var rpc: Dictionary = await _rpc_call("tpx_account_magic_link_complete", payload, true, true)
	if rpc.get("ok", false):
		await refresh_wallet(true)
	return rpc

func get_magic_link_status(clear_after_read: bool = true) -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	var payload := {"clear_after_read": clear_after_read}
	var rpc: Dictionary = await _rpc_call("tpx_account_magic_link_status", payload, true, true)
	if not rpc.get("ok", false):
		return rpc
	var data: Variant = rpc.get("data", {})
	if typeof(data) == TYPE_DICTIONARY:
		var row: Dictionary = data
		if bool(row.get("completed", false)):
			await refresh_wallet(true)
			profile_upgraded.emit(true, str(row.get("status", "ok")))
	return rpc

func create_account_merge_code() -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	return await _rpc_call("tpx_account_merge_code", {}, true, true)

func redeem_account_merge_code(merge_code: String) -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	return await _rpc_call("tpx_account_merge_redeem", {"merge_code": merge_code.strip_edges()}, true, true)

func get_username_status() -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	return await _rpc_call("tpx_account_username_status", {}, true, true)

func update_username(new_username: String) -> Dictionary:
	if not await ensure_authenticated():
		return {"ok": false, "error": "auth failed"}
	var payload := {"username": new_username.strip_edges().to_lower()}
	var rpc: Dictionary = await _rpc_call("tpx_account_update_username", payload, true, true)
	if not rpc.get("ok", false):
		return rpc
	var data: Variant = rpc.get("data", {})
	if typeof(data) == TYPE_DICTIONARY:
		var row: Dictionary = data
		var username := str(row.get("username", "")).strip_edges()
		if not username.is_empty():
			_username = username
			username_updated.emit(_username)
		if row.has("coinBalance"):
			await refresh_wallet(false)
	return rpc

func _authenticate_device() -> Dictionary:
	var device_id: String = SaveStore.get_or_create_nakama_device_id()
	var username: String = _resolve_display_name()
	var auth_body := {
		"id": device_id,
		"vars": _build_auth_vars(),
	}
	var path := "/v2/account/authenticate/device?create=true&username=%s" % username.uri_encode()
	var response: Dictionary = await _request_json(
		HTTPClient.METHOD_POST,
		path,
		JSON.stringify(auth_body),
		_basic_auth_headers()
	)
	if not response.get("ok", false):
		return response

	var data: Variant = response.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid auth response"}

	_session_token = str(data.get("token", ""))
	_refresh_token = str(data.get("refresh_token", ""))
	if _session_token.is_empty():
		return {"ok": false, "error": "missing session token"}

	var account_response: Dictionary = await _request_json(
		HTTPClient.METHOD_GET,
		"/v2/account",
		"",
		_bearer_auth_headers()
	)
	if not account_response.get("ok", false):
		return account_response

	var account_data: Variant = account_response.get("data", {})
	if typeof(account_data) == TYPE_DICTIONARY and account_data.has("user"):
		var user_obj: Variant = account_data["user"]
		if typeof(user_obj) == TYPE_DICTIONARY:
			_user_id = str(user_obj.get("id", ""))
			_username = str(user_obj.get("username", ""))
			SaveStore.set_nakama_user_id(_user_id)
	return {"ok": true}

func _rpc_call(rpc_id: String, payload: Dictionary, requires_auth: bool, retry_on_unauthorized: bool) -> Dictionary:
	var path := "/v2/rpc/%s" % rpc_id
	var headers := _bearer_auth_headers() if requires_auth else _basic_auth_headers()
	var rpc_payload_json: String = JSON.stringify(payload)
	var request_body: String = JSON.stringify(rpc_payload_json)
	var response: Dictionary = await _request_json(
		HTTPClient.METHOD_POST,
		path,
		request_body,
		headers
	)

	if retry_on_unauthorized and int(response.get("code", 0)) == 401:
		_is_authenticated = false
		if await ensure_authenticated():
			headers = _bearer_auth_headers() if requires_auth else _basic_auth_headers()
			response = await _request_json(
				HTTPClient.METHOD_POST,
				path,
				request_body,
				headers
			)

	if not response.get("ok", false):
		return response

	var raw_data: Variant = response.get("data", {})
	var parsed_data: Dictionary = {}
	if typeof(raw_data) == TYPE_DICTIONARY and raw_data.has("payload"):
		var rpc_payload: Variant = raw_data["payload"]
		if typeof(rpc_payload) == TYPE_STRING:
			var parsed: Variant = JSON.parse_string(str(rpc_payload))
			if typeof(parsed) == TYPE_DICTIONARY:
				parsed_data = parsed
		elif typeof(rpc_payload) == TYPE_DICTIONARY:
			parsed_data = rpc_payload
	elif typeof(raw_data) == TYPE_DICTIONARY:
		parsed_data = raw_data

	return {
		"ok": true,
		"data": parsed_data,
		"code": int(response.get("code", 200)),
	}

func _request_json(method: int, path: String, body: String, headers: PackedStringArray) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 10.0
	add_child(request)

	var url := "%s%s" % [_base_url.trim_suffix("/"), path]
	var err: Error = request.request(url, headers, method, body)
	if err != OK:
		request.queue_free()
		return {"ok": false, "error": "request start failed", "code": 0}

	var completed: Array = await request.request_completed
	request.queue_free()

	var result_code: int = int(completed[0])
	var status_code: int = int(completed[1])
	var response_body: PackedByteArray = completed[3]
	var text := response_body.get_string_from_utf8()

	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "transport error", "code": status_code, "body": text}

	var parsed: Variant = {}
	if not text.is_empty():
		var json_parsed: Variant = JSON.parse_string(text)
		if json_parsed != null:
			parsed = json_parsed

	if status_code < 200 or status_code >= 300:
		return {"ok": false, "error": "http error", "code": status_code, "body": text, "data": parsed}

	return {"ok": true, "code": status_code, "data": parsed, "body": text}

func _read_runtime_settings() -> void:
	_base_url = _env_or_setting_string(
		"COLOR_CRUNCH_NAKAMA_BASE_URL",
		"color_crunch/nakama_base_url",
		DEFAULT_BASE_URL
	)
	_server_key = _env_or_setting_string(
		"COLOR_CRUNCH_NAKAMA_SERVER_KEY",
		"color_crunch/nakama_server_key",
		DEFAULT_SERVER_KEY
	)
	_leaderboard_limit = int(_project_setting("color_crunch/nakama_leaderboard_limit", DEFAULT_LEADERBOARD_LIMIT))
	_connect_enabled = bool(_project_setting("color_crunch/nakama_enable_client", false))
	_export_target = _resolve_export_target()
	_base_url = _base_url.strip_edges()
	if _base_url.is_empty():
		_base_url = DEFAULT_BASE_URL
	if _leaderboard_limit <= 0:
		_leaderboard_limit = DEFAULT_LEADERBOARD_LIMIT
	var configured_tpx_user_id: String = _env_or_setting_string(
		"COLOR_CRUNCH_TERAPIXEL_USER_ID",
		"color_crunch/terapixel_user_id",
		""
	)
	var configured_tpx_name: String = _env_or_setting_string(
		"COLOR_CRUNCH_TERAPIXEL_DISPLAY_NAME",
		"color_crunch/terapixel_display_name",
		""
	)
	if SaveStore.get_terapixel_user_id().is_empty() and not configured_tpx_user_id.is_empty():
		SaveStore.set_terapixel_identity(configured_tpx_user_id, configured_tpx_name)

func _env_or_setting_string(env_key: String, setting_key: String, fallback: String) -> String:
	var from_env: String = OS.get_environment(env_key).strip_edges()
	if not from_env.is_empty():
		return from_env
	var from_setting: String = str(_project_setting(setting_key, fallback)).strip_edges()
	if not from_setting.is_empty():
		return from_setting
	return fallback

func _resolve_display_name() -> String:
	var from_store: String = SaveStore.get_terapixel_display_name()
	if not from_store.is_empty():
		return from_store
	var from_setting: String = str(_project_setting("color_crunch/terapixel_display_name", ""))
	if not from_setting.is_empty():
		return from_setting
	return "Player-%s" % SaveStore.get_or_create_nakama_device_id().right(6)

func _sanitize_username(value: String) -> String:
	var raw := value.strip_edges().to_lower()
	if raw.is_empty():
		raw = "player"
	var out := ""
	for i in range(raw.length()):
		var c := raw[i]
		var is_letter := c >= "a" and c <= "z"
		var is_digit := c >= "0" and c <= "9"
		if is_letter or is_digit:
			out += c
		elif c == "_" or c == "-":
			out += c
	if out.length() < 3:
		out += "123"
	if out.length() > 20:
		out = out.substr(0, 20)
	return out

func _augment_metadata(metadata: Dictionary) -> Dictionary:
	var out := metadata.duplicate(true)
	out["platform"] = str(_project_setting("color_crunch/platform", "terapixel"))
	out["track_id"] = MusicManager.get_current_track_id()
	out["streak_days"] = StreakManager.get_streak_days()
	out["games_played"] = int(SaveStore.data.get("games_played", 0))
	out["terapixel_user_id"] = SaveStore.get_terapixel_user_id()
	return out

func _build_auth_vars() -> Dictionary:
	return {
		"platform": str(_project_setting("color_crunch/platform", "terapixel")),
		"game": "color_crunch",
		"terapixel_user_id": SaveStore.get_terapixel_user_id(),
	}

func _project_setting(key: String, default_value: Variant) -> Variant:
	if ProjectSettings.has_setting(key):
		return ProjectSettings.get_setting(key)
	return default_value

func _resolve_export_target() -> String:
	var configured := _env_or_setting_string(
		"COLOR_CRUNCH_EXPORT_TARGET",
		"color_crunch/export_target",
		""
	).to_lower()
	if configured in PROVIDERS_BY_EXPORT_TARGET.keys():
		return configured
	if OS.has_feature("ios"):
		return "ios"
	if OS.has_feature("android"):
		return "android"
	var platform_name := str(_project_setting("color_crunch/platform", "web")).to_lower()
	if platform_name in ["poki", "crazygames", "web"]:
		return platform_name
	return DEFAULT_EXPORT_TARGET

func _basic_auth_headers() -> PackedStringArray:
	var basic_token := Marshalls.raw_to_base64(("%s:" % _server_key).to_utf8_buffer())
	return PackedStringArray([
		"Authorization: Basic %s" % basic_token,
		"Content-Type: application/json",
		"Accept: application/json",
	])

func _bearer_auth_headers() -> PackedStringArray:
	return PackedStringArray([
		"Authorization: Bearer %s" % _session_token,
		"Content-Type: application/json",
		"Accept: application/json",
	])

func _set_online_state(status: String) -> void:
	_online_status = status
	online_state_changed.emit(status)
