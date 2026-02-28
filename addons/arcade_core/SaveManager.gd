extends Node

const SAVE_PATH := "user://arcade_save.json"
const WEB_STORAGE_KEY := "arcade_save_v1"

const DEFAULT_DATA := {
    "best": {},
    "settings": {
        "sfx_enabled": true,
        "music_enabled": true,
    },
    "streaks": {
        "days": 0,
        "at_risk": 0,
        "last_play_date": "",
    },
    "meta": {
        "games_played": 0,
        "selected_track_id": "default",
        "last_run_ended_at": "",
    },
    "ui": {
        "dismissed_tips": {},
    },
}

var data: Dictionary = {}

func _ready() -> void:
    load_save()

func load_save() -> void:
    data = _deep_copy_dictionary(DEFAULT_DATA)

    if _load_from_web_storage():
        return
    if _load_from_file():
        return

    flush()

func flush() -> void:
    var payload := JSON.stringify(data, "\t")
    _save_to_file(payload)
    _save_to_web_storage(payload)

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
    _merge_known_keys(data, parsed)
    return true

func _merge_known_keys(target: Dictionary, source: Dictionary) -> void:
    for key in target.keys():
        if not source.has(key):
            continue
        var current: Variant = target[key]
        var incoming: Variant = source[key]
        if typeof(current) == TYPE_DICTIONARY and typeof(incoming) == TYPE_DICTIONARY:
            _merge_known_keys(current, incoming)
        else:
            target[key] = incoming

func _is_web_storage_supported() -> bool:
    return OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge")

func _load_from_web_storage() -> bool:
    if not _is_web_storage_supported():
        return false
    var key_literal := JSON.stringify(WEB_STORAGE_KEY)
    var js := "window.localStorage.getItem(%s);" % key_literal
    var stored: Variant = JavaScriptBridge.eval(js, true)
    if typeof(stored) != TYPE_STRING:
        return false
    var payload := str(stored)
    if payload.is_empty():
        return false
    return _apply_serialized_payload(payload)

func _save_to_web_storage(payload: String) -> void:
    if not _is_web_storage_supported():
        return
    var key_literal := JSON.stringify(WEB_STORAGE_KEY)
    var payload_literal := JSON.stringify(payload)
    var js := "window.localStorage.setItem(%s, %s);" % [key_literal, payload_literal]
    JavaScriptBridge.eval(js, true)

func _deep_copy_dictionary(input: Dictionary) -> Dictionary:
    return input.duplicate(true)

func get_best(key: String, default_value := 0) -> Variant:
    return data.get("best", {}).get(key, default_value)

func set_best(key: String, value: Variant) -> void:
    data["best"][key] = value
    flush()

func get_setting(key: String, default_value: Variant = null) -> Variant:
    return data.get("settings", {}).get(key, default_value)

func set_setting(key: String, value: Variant) -> void:
    data["settings"][key] = value
    flush()

func increment_games_played() -> void:
    data["meta"]["games_played"] = int(data["meta"].get("games_played", 0)) + 1
    flush()

func games_played() -> int:
    return int(data.get("meta", {}).get("games_played", 0))

func set_last_run_ended_at(date_key: String) -> void:
    data["meta"]["last_run_ended_at"] = date_key
    flush()

func set_selected_track_id(track_id: String) -> void:
    data["meta"]["selected_track_id"] = track_id
    flush()

func selected_track_id(default_value: String = "default") -> String:
    return str(data.get("meta", {}).get("selected_track_id", default_value))

func is_tip_dismissed(tip_id: String) -> bool:
    var key := tip_id.strip_edges().to_lower()
    if key.is_empty():
        return false
    var ui: Variant = data.get("ui", {})
    if typeof(ui) != TYPE_DICTIONARY:
        return false
    var dismissed: Variant = (ui as Dictionary).get("dismissed_tips", {})
    if typeof(dismissed) != TYPE_DICTIONARY:
        return false
    return bool((dismissed as Dictionary).get(key, false))

func should_show_tip(tip_id: String, default_value: bool = true) -> bool:
    var key := tip_id.strip_edges().to_lower()
    if key.is_empty():
        return default_value
    return not is_tip_dismissed(key)

func set_tip_dismissed(tip_id: String, dismissed: bool = true) -> void:
    var key := tip_id.strip_edges().to_lower()
    if key.is_empty():
        return
    var ui_value: Variant = data.get("ui", {})
    var ui: Dictionary = {}
    if typeof(ui_value) == TYPE_DICTIONARY:
        ui = (ui_value as Dictionary).duplicate(true)
    var dismissed_value: Variant = ui.get("dismissed_tips", {})
    var dismissed_tips: Dictionary = {}
    if typeof(dismissed_value) == TYPE_DICTIONARY:
        dismissed_tips = (dismissed_value as Dictionary).duplicate(true)
    if dismissed:
        dismissed_tips[key] = true
    else:
        dismissed_tips.erase(key)
    ui["dismissed_tips"] = dismissed_tips
    data["ui"] = ui
    flush()
