extends Node
class_name SaveStoreCompat

@export var default_high_score_key := "high_score"
@export var default_games_played_key := "games_played"

var _initialized := false

func _ready() -> void:
	initialize()

func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	SaveManager.load_save()

func load_save() -> void:
	SaveManager.load_save()

func save() -> void:
	SaveManager.flush()

func set_high_score(score: int, best_key: String = "") -> void:
	var key := _resolve_best_key(best_key)
	var current: int = int(SaveManager.get_best(key, 0))
	if score > current:
		SaveManager.set_best(key, score)

func get_high_score(best_key: String = "") -> int:
	return int(SaveManager.get_best(_resolve_best_key(best_key), 0))

func increment_games_played(_legacy_key: String = "") -> void:
	SaveManager.increment_games_played()

func get_games_played(_legacy_key: String = "") -> int:
	return SaveManager.games_played()

func get_best(key: String, default_value: Variant = 0) -> Variant:
	return SaveManager.get_best(key, default_value)

func set_best(key: String, value: Variant) -> void:
	SaveManager.set_best(key, value)

func get_setting(key: String, default_value: Variant = null) -> Variant:
	return SaveManager.get_setting(key, default_value)

func set_setting(key: String, value: Variant) -> void:
	SaveManager.set_setting(key, value)

func import_legacy_save(path: String, high_score_key: String = "", games_played_key: String = "") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return false

	var source: Dictionary = parsed as Dictionary
	var best_key := _resolve_best_key(high_score_key)
	var games_key := _resolve_games_key(games_played_key)

	var incoming_best: int = int(source.get(best_key, source.get(default_high_score_key, 0)))
	if incoming_best > int(SaveManager.get_best(best_key, 0)):
		SaveManager.data["best"][best_key] = incoming_best

	var incoming_games: int = int(source.get(games_key, source.get(default_games_played_key, 0)))
	if incoming_games > SaveManager.games_played():
		SaveManager.data["meta"]["games_played"] = incoming_games

	SaveManager.flush()
	return true

func _resolve_best_key(best_key: String) -> String:
	var key := best_key.strip_edges()
	if key.is_empty():
		key = default_high_score_key
	return key

func _resolve_games_key(games_key: String) -> String:
	var key := games_key.strip_edges()
	if key.is_empty():
		key = default_games_played_key
	return key
