extends GdUnitTestSuite

func before() -> void:
	ProjectSettings.set_setting("lumarush/visual_test_mode", true)
	ProjectSettings.set_setting("lumarush/audio_test_mode", true)
	ProjectSettings.set_setting("lumarush/use_mock_ads", true)

func test_main_menu_scene_smoke() -> void:
	var scene := await _load_scene("res://src/scenes/MainMenu.tscn")
	var title := scene.get_node_or_null("UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/Title") as Label
	assert_that(title).is_not_null()
	assert_that(title.text).is_equal("Color Crunch")
	scene.queue_free()

func test_game_scene_smoke_and_merge_scores() -> void:
	var scene: Control = await _load_scene("res://src/scenes/Game.tscn") as Control
	var board_view: BoardView = scene.get_node("BoardView") as BoardView
	board_view.board.grid = [
		[1, 1, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 0, 0],
	]
	board_view._refresh_tiles()
	await board_view._attempt_move(Vector2i.LEFT)
	assert_that(int(scene.score)).is_greater(0)
	scene.queue_free()

func test_results_scene_smoke() -> void:
	RunManager.last_score = 512
	SaveStore.data["high_score"] = 1024
	var scene := await _load_scene("res://src/scenes/Results.tscn")
	assert_that(scene.get_node_or_null("UI/Panel/Scroll")).is_not_null()
	assert_that(scene.get_node_or_null("UI/Panel/Scroll/VBox/Title")).is_not_null()
	assert_that((scene.get_node("UI/Panel/Scroll/VBox/Title") as Label).text).is_equal("Color Crunch")
	scene.queue_free()

func _load_scene(path: String) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	var inst: Node = packed.instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	return inst
