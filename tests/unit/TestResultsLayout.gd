extends GdUnitTestSuite

var _original_enable_client: bool = true

func before_test() -> void:
	_original_enable_client = bool(ProjectSettings.get_setting("color_crunch/nakama_enable_client", true))
	ProjectSettings.set_setting("color_crunch/nakama_enable_client", false)
	NakamaService.set("_connect_enabled", false)

func after_test() -> void:
	ProjectSettings.set_setting("color_crunch/nakama_enable_client", _original_enable_client)
	NakamaService.set("_connect_enabled", _original_enable_client)

func test_results_actions_stay_inside_panel_on_wide_short_viewports() -> void:
	RunManager.last_score = 148
	RunManager.last_run_leaderboard_mode = "OPEN"
	SaveStore.data["high_score"] = 148

	var scene: PackedScene = load("res://src/scenes/Results.tscn") as PackedScene
	var results: Control = scene.instantiate() as Control
	assert_that(results).is_not_null()
	get_tree().root.add_child(results)
	await get_tree().process_frame
	await get_tree().process_frame

	var panel: Control = results.get_node("UI/Panel") as Control
	var play_again: Button = results.get_node("UI/Panel/Scroll/VBox/PlayAgain") as Button
	var menu: Button = results.get_node("UI/Panel/Scroll/VBox/Menu") as Button
	var audio_button: Control = results.get_node_or_null("UI/TopRightBar/Audio") as Control
	assert_that(panel).is_not_null()
	assert_that(play_again).is_not_null()
	assert_that(menu).is_not_null()
	assert_that(audio_button).is_not_null()

	var viewport_sizes: Array[Vector2] = [
		Vector2(1920.0, 1010.0),
		Vector2(1920.0, 720.0),
		Vector2(2560.0, 900.0),
		Vector2(2560.0, 720.0),
	]
	for size in viewport_sizes:
		results.call("_layout_results_for_size", size)
		await get_tree().process_frame
		var panel_rect: Rect2 = panel.get_global_rect()
		var play_rect: Rect2 = play_again.get_global_rect()
		var menu_rect: Rect2 = menu.get_global_rect()
		var audio_rect: Rect2 = audio_button.get_global_rect()
		_assert_rect_inside(play_rect, panel_rect)
		_assert_rect_inside(menu_rect, panel_rect)
		_assert_rect_inside(audio_rect, Rect2(Vector2.ZERO, size))

	results.queue_free()

func _assert_rect_inside(inner: Rect2, outer: Rect2, epsilon: float = 1.0) -> void:
	assert_that(inner.position.x).is_greater_equal(outer.position.x - epsilon)
	assert_that(inner.position.y).is_greater_equal(outer.position.y - epsilon)
	assert_that(inner.position.x + inner.size.x).is_less_equal(outer.position.x + outer.size.x + epsilon)
	assert_that(inner.position.y + inner.size.y).is_less_equal(outer.position.y + outer.size.y + epsilon)
