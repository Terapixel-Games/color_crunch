extends Node

const BOOT_SCENE := "res://src/scenes/Boot.tscn"
const MENU_SCENE := "res://src/scenes/MainMenu.tscn"
const GAME_SCENE := "res://src/scenes/Game.tscn"
const RESULTS_SCENE := "res://src/scenes/Results.tscn"

var last_score := 0
var last_run_completed_by_gameplay: bool = false
var last_run_id: String = ""
var last_run_powerups_used: int = 0
var last_run_coins_spent: int = 0
var last_run_leaderboard_mode: String = "PURE"
var last_run_selected_mode: String = "PURE"
var last_run_daily_challenge: bool = false
var last_run_powerup_breakdown: Dictionary = {}
var last_run_duration_ms: int = 0
var _run_started_at_unix: int = 0
var _pending_daily_seed: int = -1

func goto_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func start_game() -> void:
	last_run_selected_mode = SaveStore.get_preferred_mode()
	last_run_daily_challenge = SaveStore.get_daily_challenge_enabled()
	last_run_powerups_used = 0
	last_run_coins_spent = 0
	last_run_leaderboard_mode = last_run_selected_mode
	last_run_powerup_breakdown = {}
	last_run_duration_ms = 0
	_run_started_at_unix = Time.get_unix_time_from_system()
	_pending_daily_seed = _daily_seed_for_today() if last_run_daily_challenge else -1
	if Telemetry and Telemetry.has_method("mark_run_start"):
		Telemetry.mark_run_start(last_run_selected_mode, last_run_daily_challenge)
	get_tree().change_scene_to_file(GAME_SCENE)

func set_run_leaderboard_context(powerups_used: int, coins_spent: int = 0, powerup_breakdown: Dictionary = {}) -> void:
	last_run_powerups_used = max(0, powerups_used)
	last_run_coins_spent = max(0, coins_spent)
	last_run_leaderboard_mode = "OPEN" if (last_run_powerups_used > 0 or last_run_selected_mode == "OPEN") else "PURE"
	last_run_powerup_breakdown = powerup_breakdown.duplicate(true)

func end_game(score: int, completed_by_gameplay: bool = true) -> void:
	last_score = score
	last_run_completed_by_gameplay = completed_by_gameplay
	last_run_id = "cc-run-%d" % Time.get_unix_time_from_system()
	var started_at := _run_started_at_unix
	if started_at <= 0:
		started_at = Time.get_unix_time_from_system()
	last_run_duration_ms = int(max(0, (Time.get_unix_time_from_system() - started_at) * 1000))
	if Telemetry and Telemetry.has_method("mark_run_end"):
		Telemetry.mark_run_end(
			score,
			last_run_leaderboard_mode,
			last_run_powerups_used,
			last_run_duration_ms,
			completed_by_gameplay
		)
	SaveStore.set_high_score(score)
	StreakManager.record_game_play()
	AdManager.on_game_finished()
	_update_unlock_progress()
	get_tree().change_scene_to_file(RESULTS_SCENE)

func set_selected_mode(mode_id: String, source: String = "ui") -> void:
	var mode := mode_id.strip_edges().to_upper()
	if mode != "OPEN":
		mode = "PURE"
	SaveStore.set_preferred_mode(mode)
	last_run_selected_mode = mode
	if Telemetry and Telemetry.has_method("mark_mode_selected"):
		Telemetry.mark_mode_selected(mode, source)

func get_selected_mode() -> String:
	return SaveStore.get_preferred_mode()

func set_daily_challenge_enabled(enabled: bool) -> void:
	SaveStore.set_daily_challenge_enabled(enabled)

func consume_pending_daily_seed() -> int:
	var seed := _pending_daily_seed
	_pending_daily_seed = -1
	return seed

func _daily_seed_for_today() -> int:
	var now_dict := Time.get_datetime_dict_from_system()
	return int(now_dict["year"]) * 10000 + int(now_dict["month"]) * 100 + int(now_dict["day"])

func _update_unlock_progress() -> void:
	var games_played: int = max(0, int(SaveStore.data.get("games_played", 0)))
	var progress: float = clamp(float(games_played) / 40.0, 0.0, 1.0)
	SaveStore.set_unlock_progress(progress)
