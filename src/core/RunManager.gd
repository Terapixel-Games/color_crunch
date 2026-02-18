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
var last_run_powerup_breakdown: Dictionary = {}
var last_run_duration_ms: int = 0
var _run_started_at_unix: int = 0

func goto_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func start_game() -> void:
	last_run_powerups_used = 0
	last_run_coins_spent = 0
	last_run_leaderboard_mode = "PURE"
	last_run_powerup_breakdown = {}
	last_run_duration_ms = 0
	_run_started_at_unix = Time.get_unix_time_from_system()
	get_tree().change_scene_to_file(GAME_SCENE)

func set_run_leaderboard_context(powerups_used: int, coins_spent: int = 0, powerup_breakdown: Dictionary = {}) -> void:
	last_run_powerups_used = max(0, powerups_used)
	last_run_coins_spent = max(0, coins_spent)
	last_run_leaderboard_mode = "OPEN" if last_run_powerups_used > 0 else "PURE"
	last_run_powerup_breakdown = powerup_breakdown.duplicate(true)

func end_game(score: int, completed_by_gameplay: bool = true) -> void:
	last_score = score
	last_run_completed_by_gameplay = completed_by_gameplay
	last_run_id = "cc-run-%d" % Time.get_unix_time_from_system()
	var started_at := _run_started_at_unix
	if started_at <= 0:
		started_at = Time.get_unix_time_from_system()
	last_run_duration_ms = int(max(0, (Time.get_unix_time_from_system() - started_at) * 1000))
	SaveStore.set_high_score(score)
	StreakManager.record_game_play()
	AdManager.on_game_finished()
	get_tree().change_scene_to_file(RESULTS_SCENE)
