extends Node

const BOOT_SCENE := "res://src/scenes/Boot.tscn"
const MENU_SCENE := "res://src/scenes/MainMenu.tscn"
const GAME_SCENE := "res://src/scenes/Game.tscn"
const RESULTS_SCENE := "res://src/scenes/Results.tscn"

var last_score := 0
var last_run_completed_by_gameplay: bool = false
var last_run_id: String = ""

func goto_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func end_game(score: int, completed_by_gameplay: bool = true) -> void:
	last_score = score
	last_run_completed_by_gameplay = completed_by_gameplay
	last_run_id = "cc-run-%d" % Time.get_unix_time_from_system()
	SaveStore.set_high_score(score)
	StreakManager.record_game_play()
	AdManager.on_game_finished()
	get_tree().change_scene_to_file(RESULTS_SCENE)
