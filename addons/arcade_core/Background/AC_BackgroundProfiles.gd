class_name AC_BackgroundProfiles
extends RefCounted
## Loads, parses, and caches background profile JSON files.

const DEFAULT_PATH := "res://addons/arcade_core/Background/profiles/background_profiles.json"
const BACKGROUND_PROFILE_SCRIPT := preload("res://addons/arcade_core/Background/AC_BackgroundProfile.gd")

static var _cache: Dictionary = {}

static func clear_cache() -> void:
	_cache.clear()

static func list_profile_names(path: String = DEFAULT_PATH) -> PackedStringArray:
	var profiles: Dictionary = load_profiles(path)
	var names := PackedStringArray()
	for key in profiles.keys():
		names.append(str(key))
	names.sort()
	return names

static func get_profile(name: String, path: String = DEFAULT_PATH):
	var profiles: Dictionary = load_profiles(path)
	if profiles.has(name):
		return profiles[name]
	if profiles.size() > 0:
		return profiles.values()[0]
	return BACKGROUND_PROFILE_SCRIPT.from_dict("fallback", {})

static func load_profiles(path: String = DEFAULT_PATH) -> Dictionary:
	if _cache.has(path):
		return _cache[path]

	var raw: Variant = _read_json(path)
	var parsed: Dictionary = _parse_profile_map(raw)
	if parsed.is_empty():
		var builtin: Dictionary = BACKGROUND_PROFILE_SCRIPT.builtin_profiles()
		_cache[path] = builtin
		return builtin
	_cache[path] = parsed
	return parsed

static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("AC_BackgroundProfiles: failed to parse %s (%s)" % [path, json.get_error_message()])
		return {}
	return json.data

static func _parse_profile_map(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var profiles_data: Variant = raw.get("profiles", {})
	if not (profiles_data is Dictionary):
		return {}

	var out: Dictionary = {}
	for key in profiles_data.keys():
		var name := str(key)
		var data: Variant = profiles_data[key]
		if data is Dictionary:
			out[name] = BACKGROUND_PROFILE_SCRIPT.from_dict(name, data)
	return out
