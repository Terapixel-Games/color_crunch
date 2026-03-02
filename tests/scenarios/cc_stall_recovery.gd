extends "res://addons/arcade_core/testing/MovieScenario.gd"

var _ctx: Dictionary = {}
var _actions_total: int = 0
var _runs_started: int = 0
var _runs_finished: int = 0
var _score_final: int = 0
var _action_interval: int = 6
var _restart_interval: int = 420
var _powerup_interval: int = 210
var _menu_action_interval: int = 12
var _menu_settle_frames: int = 10
var _results_hold_frames: int = 90
var _last_menu_action_frame: int = -100000
var _results_enter_frame: int = -1
var _game_enter_frame: int = -1
var _last_scene_path: String = ""
var _last_scene_id: int = 0
var _next_direction: int = 0

const DIR_ORDER := [Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP]


func setup(context: Dictionary) -> void:
	_ctx = context.duplicate(true)
	var persona: Dictionary = actor_persona()
	_action_interval = maxi(
		1,
		int(persona.get("gameplay_action_interval_frames", persona.get("action_interval_frames", 6)))
	)
	_restart_interval = maxi(120, int(persona.get("restart_interval_frames", 420)))
	_powerup_interval = maxi(90, int(persona.get("powerup_interval_frames", 210)))
	_menu_action_interval = maxi(1, int(persona.get("menu_action_interval_frames", 12)))
	_menu_settle_frames = maxi(0, int(persona.get("menu_settle_frames", 10)))
	_results_hold_frames = maxi(0, int(persona.get("results_hold_frames", 90)))


func step(frame: int, _delta: float) -> void:
	var scene: Node = _current_scene()
	if scene == null:
		return
	var scene_path: String = str(scene.scene_file_path)
	var scene_id: int = scene.get_instance_id()
	var scene_changed: bool = scene_path != _last_scene_path or scene_id != _last_scene_id
	_track_scene_transition(scene, scene_path)
	if scene_changed:
		if scene_path.ends_with("Game.tscn"):
			_game_enter_frame = frame
			_results_enter_frame = -1
		elif scene_path.ends_with("Results.tscn"):
			_results_enter_frame = frame

	if scene_path.ends_with("Boot.tscn"):
		if _can_menu_action(frame):
			var run_manager_boot: Node = _run_manager()
			if run_manager_boot != null and run_manager_boot.has_method("goto_menu"):
				run_manager_boot.call("goto_menu")
				_last_menu_action_frame = frame
		return
	if scene_path.ends_with("MainMenu.tscn"):
		if _can_menu_action(frame):
			var run_manager_menu: Node = _run_manager()
			if run_manager_menu != null and run_manager_menu.has_method("start_game"):
				run_manager_menu.call("start_game")
				_last_menu_action_frame = frame
		return
	if scene_path.ends_with("Results.tscn"):
		var run_manager_results: Node = _run_manager()
		if run_manager_results != null:
			_score_final = maxi(_score_final, int(run_manager_results.get("last_score")))
			if _results_enter_frame < 0:
				_results_enter_frame = frame
			var should_restart: bool = frame - _results_enter_frame >= _results_hold_frames
			if should_restart and _can_menu_action(frame) and run_manager_results.has_method("start_game"):
				run_manager_results.call("start_game")
				_last_menu_action_frame = frame
		return
	if not scene_path.ends_with("Game.tscn"):
		return
	if _game_enter_frame >= 0 and frame - _game_enter_frame < _menu_settle_frames:
		return

	if frame > 0 and frame % _restart_interval == 0:
		var run_manager_restart: Node = _run_manager()
		if run_manager_restart != null and run_manager_restart.has_method("start_game"):
			run_manager_restart.call("start_game")
		return

	if frame % _powerup_interval == 0 and _apply_shuffle(scene):
		_actions_total += 1
		_score_final = maxi(_score_final, int(scene.get("score")))
		return

	if frame % _action_interval == 0 and _perform_cycle_move(scene):
		_actions_total += 1
		_score_final = maxi(_score_final, int(scene.get("score")))


func collect_metrics() -> Dictionary:
	return {
		"actions_total": _actions_total,
		"score_final": _score_final,
		"runs_started": _runs_started,
		"runs_finished": _runs_finished,
	}


func get_invariants() -> Array[Dictionary]:
	return [
		{"id": "actions_non_idle", "metric": "actions_total", "op": ">=", "value": 15},
		{"id": "rerun_transition", "metric": "runs_started", "op": ">=", "value": 2},
		{"id": "score_progress", "metric": "score_final", "op": ">=", "value": 40},
	]


func _perform_cycle_move(game_scene: Node) -> bool:
	var board_view: Node = game_scene.get_node_or_null("BoardView")
	if board_view == null:
		return false
	var direction: Vector2i = DIR_ORDER[_next_direction % DIR_ORDER.size()]
	_next_direction += 1
	return _apply_move(board_view, direction)


func _apply_move(board_view: Node, direction: Vector2i) -> bool:
	var board = board_view.get("board")
	if board == null:
		return false
	var snapshot: Array = board.snapshot()
	var result: Dictionary = board.move(direction)
	if not bool(result.get("moved", false)):
		return false
	var merge_positions: Array = result.get("merge_positions", [])
	board_view.set("_last_move_score", int(result.get("score_gain", 0)))
	board_view.set("_last_merge_count", merge_positions.size())
	board_view.call("_refresh_tiles")
	board_view.emit_signal("move_committed", merge_positions, snapshot)
	if merge_positions.size() > 0:
		board_view.emit_signal("match_made", merge_positions)
	board_view.call("_check_no_moves_and_emit")
	return true


func _apply_shuffle(game_scene: Node) -> bool:
	var board_view: Node = game_scene.get_node_or_null("BoardView")
	if board_view == null:
		return false
	var board = board_view.get("board")
	if board == null:
		return false
	var before: Array = board.snapshot()
	board.shuffle_tiles()
	var changed: bool = before != board.snapshot()
	if not changed:
		return false
	board_view.call("_refresh_tiles")
	board_view.call("_check_no_moves_and_emit")
	return true


func _track_scene_transition(scene: Node, scene_path: String) -> void:
	var scene_id: int = scene.get_instance_id()
	if scene_path == _last_scene_path and scene_id == _last_scene_id:
		return
	if scene_path.ends_with("Game.tscn") and scene_id != _last_scene_id:
		_runs_started += 1
	if scene_path.ends_with("Results.tscn") and _last_scene_path.ends_with("Game.tscn"):
		_runs_finished += 1
	_last_scene_path = scene_path
	_last_scene_id = scene_id


func _current_scene() -> Node:
	var tree: SceneTree = _ctx.get("scene_tree")
	if tree == null:
		return null
	return tree.current_scene


func _run_manager() -> Node:
	var tree: SceneTree = _ctx.get("scene_tree")
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("RunManager")


func _can_menu_action(frame: int) -> bool:
	return frame - _last_menu_action_frame >= _menu_action_interval
