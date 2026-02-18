extends Node

const SAVE_PATH := "user://color_crunch_save.json"
const WEB_STORAGE_KEY := "color_crunch_save_v1"
const TIP_OPEN_LEADERBOARD_FIRST_POWERUP := "leaderboard.open_mode_first_powerup"

var data := {
	"high_score": 0,
	"last_play_date": "",
	"streak_days": 0,
	"streak_at_risk": 0,
	"games_played": 0,
	"selected_track_id": "glassgrid",
	"nakama_device_id": "",
	"nakama_user_id": "",
	"terapixel_user_id": "",
	"terapixel_display_name": "",
	"terapixel_email": "",
	"coins": 0,
	"owned_themes": ["default"],
	"equipped_theme": "default",
	"theme_rentals": {},
	"owned_powerups": {"undo": 0, "prism": 0, "shuffle": 0},
	"dismissed_tips": {},
	"show_open_leaderboard_tip": true,
}

func _ready() -> void:
	load_save()

func load_save() -> void:
	if _load_from_web_storage():
		return
	if _load_from_file():
		return
	save()

func save() -> void:
	var payload: String = JSON.stringify(data)
	if _is_web_storage_supported():
		_save_to_web_storage(payload)
	_save_to_file(payload)

func _load_from_file() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	return _apply_serialized_payload(txt)

func _save_to_file(payload: String) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(payload)
	f.close()

func _apply_serialized_payload(payload: String) -> bool:
	var parsed: Variant = JSON.parse_string(payload)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	for k in data.keys():
		if parsed.has(k):
			data[k] = parsed[k]
	_migrate_legacy_tip_preferences()
	return true

func _migrate_legacy_tip_preferences() -> void:
	var dismissed_var: Variant = data.get("dismissed_tips", {})
	var dismissed: Dictionary = {}
	if typeof(dismissed_var) == TYPE_DICTIONARY:
		dismissed = (dismissed_var as Dictionary).duplicate(true)
	if not bool(data.get("show_open_leaderboard_tip", true)):
		dismissed[TIP_OPEN_LEADERBOARD_FIRST_POWERUP] = true
	data["dismissed_tips"] = dismissed

func _is_web_storage_supported() -> bool:
	return OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge")

func _load_from_web_storage() -> bool:
	if not _is_web_storage_supported():
		return false
	var key_literal: String = JSON.stringify(WEB_STORAGE_KEY)
	var js: String = "window.localStorage.getItem(%s);" % key_literal
	var stored: Variant = JavaScriptBridge.eval(js, true)
	if typeof(stored) != TYPE_STRING:
		return false
	var payload: String = str(stored)
	if payload.is_empty():
		return false
	return _apply_serialized_payload(payload)

func _save_to_web_storage(payload: String) -> void:
	if not _is_web_storage_supported():
		return
	var key_literal: String = JSON.stringify(WEB_STORAGE_KEY)
	var payload_literal: String = JSON.stringify(payload)
	var js: String = "window.localStorage.setItem(%s, %s);" % [key_literal, payload_literal]
	JavaScriptBridge.eval(js, true)

func set_high_score(score: int) -> void:
	if score > int(data["high_score"]):
		data["high_score"] = score
		save()

func clear_high_score() -> void:
	data["high_score"] = 0
	save()

func set_selected_track_id(track_id: String) -> void:
	data["selected_track_id"] = track_id
	save()

func increment_games_played() -> void:
	data["games_played"] = int(data["games_played"]) + 1
	save()

func set_streak_days(days: int) -> void:
	data["streak_days"] = days
	save()

func set_streak_at_risk(days: int) -> void:
	data["streak_at_risk"] = days
	save()

func set_last_play_date(date_key: String) -> void:
	data["last_play_date"] = date_key
	save()

func get_or_create_nakama_device_id() -> String:
	var current: String = str(data.get("nakama_device_id", ""))
	if not current.is_empty():
		return current
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	current = "cc-%s" % bytes.hex_encode()
	data["nakama_device_id"] = current
	save()
	return current

func set_nakama_user_id(user_id: String) -> void:
	data["nakama_user_id"] = user_id
	save()

func set_terapixel_identity(user_id: String, display_name: String = "", email: String = "") -> void:
	data["terapixel_user_id"] = user_id.strip_edges()
	if not display_name.is_empty():
		data["terapixel_display_name"] = display_name
	if not email.is_empty():
		data["terapixel_email"] = email.strip_edges().to_lower()
	save()

func get_terapixel_user_id() -> String:
	return str(data.get("terapixel_user_id", ""))

func get_terapixel_display_name() -> String:
	return str(data.get("terapixel_display_name", ""))

func set_terapixel_email(email: String) -> void:
	data["terapixel_email"] = email.strip_edges().to_lower()
	save()

func get_terapixel_email() -> String:
	return str(data.get("terapixel_email", ""))

func clear_terapixel_identity() -> void:
	data["terapixel_user_id"] = ""
	data["terapixel_display_name"] = ""
	data["terapixel_email"] = ""
	save()

func set_coins(value: int) -> void:
	data["coins"] = max(0, value)
	save()

func get_coins() -> int:
	return int(data.get("coins", 0))

func get_owned_themes() -> Array:
	var raw: Variant = data.get("owned_themes", ["default"])
	if typeof(raw) == TYPE_ARRAY:
		return (raw as Array).duplicate(true)
	return ["default"]

func set_owned_themes(themes: Array) -> void:
	var out: Array = []
	for theme_var in themes:
		var theme_id := str(theme_var).strip_edges().to_lower()
		if theme_id.is_empty():
			continue
		if out.has(theme_id):
			continue
		out.append(theme_id)
	if not out.has("default"):
		out.push_front("default")
	data["owned_themes"] = out
	save()

func get_equipped_theme() -> String:
	var theme_id := str(data.get("equipped_theme", "default")).strip_edges().to_lower()
	if theme_id.is_empty():
		return "default"
	return theme_id

func set_equipped_theme(theme_id: String) -> void:
	var cleaned := theme_id.strip_edges().to_lower()
	if cleaned.is_empty():
		cleaned = "default"
	data["equipped_theme"] = cleaned
	save()

func set_theme_rentals(rentals: Dictionary) -> void:
	data["theme_rentals"] = rentals.duplicate(true)
	save()

func get_theme_rentals() -> Dictionary:
	var raw: Variant = data.get("theme_rentals", {})
	if typeof(raw) == TYPE_DICTIONARY:
		return (raw as Dictionary).duplicate(true)
	return {}

func set_owned_powerups(powerups: Dictionary) -> void:
	data["owned_powerups"] = powerups.duplicate(true)
	save()

func get_owned_powerups() -> Dictionary:
	var raw: Variant = data.get("owned_powerups", {"undo": 0, "prism": 0, "shuffle": 0})
	if typeof(raw) == TYPE_DICTIONARY:
		return (raw as Dictionary).duplicate(true)
	return {"undo": 0, "prism": 0, "shuffle": 0}

func should_show_tip(tip_id: String, default_value: bool = true) -> bool:
	var key := tip_id.strip_edges().to_lower()
	if key.is_empty():
		return default_value
	var dismissed_var: Variant = data.get("dismissed_tips", {})
	if typeof(dismissed_var) != TYPE_DICTIONARY:
		return default_value
	return not bool((dismissed_var as Dictionary).get(key, false))

func set_tip_dismissed(tip_id: String, dismissed: bool = true) -> void:
	var key := tip_id.strip_edges().to_lower()
	if key.is_empty():
		return
	var dismissed_var: Variant = data.get("dismissed_tips", {})
	var dismissed_tips: Dictionary = {}
	if typeof(dismissed_var) == TYPE_DICTIONARY:
		dismissed_tips = (dismissed_var as Dictionary).duplicate(true)
	if dismissed:
		dismissed_tips[key] = true
	else:
		dismissed_tips.erase(key)
	data["dismissed_tips"] = dismissed_tips
	save()

func should_show_open_leaderboard_tip() -> bool:
	return should_show_tip(TIP_OPEN_LEADERBOARD_FIRST_POWERUP, true)

func set_show_open_leaderboard_tip(should_show: bool) -> void:
	data["show_open_leaderboard_tip"] = should_show
	set_tip_dismissed(TIP_OPEN_LEADERBOARD_FIRST_POWERUP, not should_show)
