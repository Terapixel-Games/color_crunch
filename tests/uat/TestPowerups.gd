extends GdUnitTestSuite

var _original_mode: String = "PURE"

func before() -> void:
	_original_mode = RunManager.get_selected_mode()
	RunManager.set_selected_mode("OPEN", "test")
	ProjectSettings.set_setting("lumarush/powerup_undo_charges", 1)
	ProjectSettings.set_setting("lumarush/powerup_remove_color_charges", 1)
	ProjectSettings.set_setting("lumarush/powerup_shuffle_charges", 1)
	ProjectSettings.set_setting("lumarush/visual_test_mode", true)
	ProjectSettings.set_setting("lumarush/audio_test_mode", true)
	ProjectSettings.set_setting("lumarush/use_mock_ads", true)
	ProjectSettings.set_setting("color_crunch/nakama_enable_client", false)
	ProjectSettings.set_setting("color_crunch/client_events_enabled", false)
	NakamaService._read_runtime_settings()

func after() -> void:
	RunManager.set_selected_mode(_original_mode, "test")

func test_remove_color_and_shuffle_consume_charges() -> void:
	var game: Control = await _spawn_game()
	var board_view: BoardView = game.get_node("BoardView") as BoardView
	board_view.board.grid = [
		[1, 1, 1, 1],
		[2, 2, 2, 2],
		[1, 1, 1, 1],
		[2, 2, 2, 2],
	]
	board_view._refresh_tiles()

	await game._on_remove_color_pressed()
	assert_that(int(game._remove_color_charges)).is_equal(0)

	await game._on_shuffle_pressed()
	assert_that(int(game._shuffle_charges)).is_equal(0)

	await _free_scene(game)

func test_undo_restores_snapshot_and_consumes_charge() -> void:
	var game: Control = await _spawn_game()
	var board_view: BoardView = game.get_node("BoardView") as BoardView
	board_view.board.grid = [
		[1, 1, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 0, 0],
	]
	board_view._refresh_tiles()
	var before: Array = board_view.capture_snapshot()
	await board_view._attempt_move(Vector2i.LEFT)
	game._on_undo_pressed()
	assert_that(board_view.capture_snapshot()).is_equal(before)
	assert_that(int(game._undo_charges)).is_equal(0)

	await _free_scene(game)

func _spawn_game() -> Control:
	var scene: PackedScene = load("res://src/scenes/Game.tscn") as PackedScene
	var game: Control = scene.instantiate() as Control
	get_tree().root.add_child(game)
	await get_tree().process_frame
	return game

func _free_scene(scene: Node) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
