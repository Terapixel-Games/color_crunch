extends GdUnitTestSuite

var _original_mode: String = "PURE"
var _original_open_tip_should_show: bool = true

func before() -> void:
	_original_mode = RunManager.get_selected_mode()
	_original_open_tip_should_show = SaveStore.should_show_tip(SaveStore.TIP_OPEN_LEADERBOARD_FIRST_POWERUP, true)
	_reset_powerup_test_state()

func before_test() -> void:
	_reset_powerup_test_state()

func _reset_powerup_test_state() -> void:
	RunManager.set_selected_mode("PURE", "test")
	RunManager.prepare_run_start()
	SaveStore.set_tip_dismissed(SaveStore.TIP_OPEN_LEADERBOARD_FIRST_POWERUP, true)
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
	SaveStore.set_tip_dismissed(SaveStore.TIP_OPEN_LEADERBOARD_FIRST_POWERUP, not _original_open_tip_should_show)

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

	game._on_remove_color_pressed()
	await _wait_frames(2)
	assert_that(game.get_node_or_null("PrismColorPicker")).is_not_null()
	assert_that(int(game._remove_color_charges)).is_equal(1)
	assert_that(RunManager.last_run_powerups_used).is_equal(0)
	await _select_prism_level(game, 2)
	assert_that(int(game._remove_color_charges)).is_equal(0)
	assert_that(RunManager.last_run_leaderboard_mode).is_equal("OPEN")
	assert_that(RunManager.last_run_powerups_used).is_equal(1)

	await game._on_shuffle_pressed()
	assert_that(int(game._shuffle_charges)).is_equal(0)
	assert_that(RunManager.last_run_leaderboard_mode).is_equal("OPEN")
	assert_that(RunManager.last_run_powerups_used).is_equal(2)

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
	await game._on_undo_pressed()
	assert_that(board_view.capture_snapshot()).is_equal(before)
	assert_that(int(game._undo_charges)).is_equal(0)
	assert_that(RunManager.last_run_leaderboard_mode).is_equal("OPEN")
	assert_that(RunManager.last_run_powerups_used).is_equal(1)

	await _free_scene(game)

func test_first_powerup_waits_for_open_run_tip_confirmation() -> void:
	SaveStore.set_tip_dismissed(SaveStore.TIP_OPEN_LEADERBOARD_FIRST_POWERUP, false)
	var game: Control = await _spawn_game()
	var board_view: BoardView = game.get_node("BoardView") as BoardView
	board_view.board.grid = [
		[1, 1, 1, 1],
		[2, 2, 2, 2],
		[1, 1, 1, 1],
		[2, 2, 2, 2],
	]
	board_view._refresh_tiles()
	var before: Array = board_view.capture_snapshot()

	game._on_remove_color_pressed()
	await _wait_frames(2)
	var modal: Control = game.get_node_or_null("TutorialTipModal") as Control
	assert_that(modal).is_not_null()
	assert_that(int(game._remove_color_charges)).is_equal(1)
	assert_that(board_view.capture_snapshot()).is_equal(before)
	assert_that(RunManager.last_run_powerups_used).is_equal(0)
	assert_that(RunManager.last_run_leaderboard_mode).is_equal("PURE")

	(modal.get_node("Center/Panel/Close") as Button).emit_signal("pressed")
	await _wait_frames(2)
	assert_that(game.get_node_or_null("TutorialTipModal")).is_null()
	assert_that(int(game._remove_color_charges)).is_equal(1)
	assert_that(board_view.capture_snapshot()).is_equal(before)
	assert_that(RunManager.last_run_powerups_used).is_equal(0)

	game._on_remove_color_pressed()
	await _wait_frames(2)
	modal = game.get_node_or_null("TutorialTipModal") as Control
	assert_that(modal).is_not_null()
	(modal.get_node("Center/Panel/ContentMargin/VBox/Buttons/Confirm") as Button).emit_signal("pressed")
	await _wait_frames(3)
	var picker: Control = game.get_node_or_null("PrismColorPicker") as Control
	assert_that(picker).is_not_null()
	assert_that(int(game._remove_color_charges)).is_equal(1)
	assert_that(board_view.capture_snapshot()).is_equal(before)
	assert_that(RunManager.last_run_powerups_used).is_equal(0)
	await _select_prism_level(game, 1)
	assert_that(int(game._remove_color_charges)).is_equal(0)
	assert_that(RunManager.last_run_powerups_used).is_equal(1)
	assert_that(RunManager.last_run_leaderboard_mode).is_equal("OPEN")

	await _free_scene(game)

func test_prism_picker_close_does_not_consume_charge_or_clear_board() -> void:
	var game: Control = await _spawn_game()
	var board_view: BoardView = game.get_node("BoardView") as BoardView
	board_view.board.grid = [
		[1, 1, 1, 1],
		[2, 2, 2, 2],
		[1, 1, 1, 1],
		[2, 2, 2, 2],
	]
	board_view._refresh_tiles()
	var before: Array = board_view.capture_snapshot()

	game._on_remove_color_pressed()
	await _wait_frames(2)
	var picker: Control = game.get_node_or_null("PrismColorPicker") as Control
	assert_that(picker).is_not_null()
	assert_that(int(game._remove_color_charges)).is_equal(1)
	assert_that(RunManager.last_run_powerups_used).is_equal(0)
	assert_that(board_view.capture_snapshot()).is_equal(before)
	if picker != null:
		(picker.get_node("Center/Panel/Close") as Button).emit_signal("pressed")
	await _wait_frames(2)

	assert_that(game.get_node_or_null("PrismColorPicker")).is_null()
	assert_that(int(game._remove_color_charges)).is_equal(1)
	assert_that(RunManager.last_run_powerups_used).is_equal(0)
	assert_that(RunManager.last_run_leaderboard_mode).is_equal("PURE")
	assert_that(board_view.capture_snapshot()).is_equal(before)

	await _free_scene(game)

func _spawn_game() -> Control:
	RunManager.prepare_run_start()
	var scene: PackedScene = load("res://src/scenes/Game.tscn") as PackedScene
	var game: Control = scene.instantiate() as Control
	get_tree().root.add_child(game)
	await get_tree().process_frame
	return game

func _select_prism_level(game: Control, level: int) -> void:
	var picker: Control = game.get_node_or_null("PrismColorPicker") as Control
	assert_that(picker).is_not_null()
	if picker == null:
		return
	var button: Button = picker.get_node("Center/Panel/ContentMargin/VBox/Scroll/Grid/Level%d" % level) as Button
	assert_that(button).is_not_null()
	button.emit_signal("pressed")
	await get_tree().create_timer(0.8).timeout
	await get_tree().process_frame

func _wait_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func _free_scene(scene: Node) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
