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
	var reward_cards: Control = results.get_node_or_null("UI/Panel/Scroll/VBox/RewardCards") as Control
	assert_that(panel).is_not_null()
	assert_that(play_again).is_not_null()
	assert_that(menu).is_not_null()
	assert_that(audio_button).is_not_null()
	assert_that(reward_cards).is_not_null()

	var viewport_sizes: Array[Vector2] = [
		Vector2(720.0, 1280.0),
		Vector2(768.0, 1024.0),
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
		_assert_rect_inside(reward_cards.get_global_rect(), panel_rect)
		_assert_rect_inside(audio_rect, Rect2(Vector2.ZERO, size))

	results.queue_free()

func test_results_uses_color_crunch_run_payoff_contract() -> void:
	RunManager.last_score = 512
	RunManager.last_run_leaderboard_mode = "PURE"
	RunManager.last_run_powerups_used = 2
	SaveStore.data["high_score"] = 1024

	var scene: PackedScene = load("res://src/scenes/Results.tscn") as PackedScene
	var results: Control = scene.instantiate() as Control
	assert_that(results).is_not_null()
	get_tree().root.add_child(results)
	await get_tree().process_frame
	await get_tree().process_frame

	var kicker := results.get_node("UI/Panel/Scroll/VBox/Kicker") as Label
	var title := results.get_node("UI/Panel/Scroll/VBox/Title") as Label
	var score := results.get_node("UI/Panel/Scroll/VBox/StatsSplit/LeftColumn/Score") as Label
	var mode := results.get_node("UI/Panel/Scroll/VBox/StatsSplit/LeftColumn/ModeBadge") as Label
	var play_again := results.get_node("UI/Panel/Scroll/VBox/PlayAgain") as Button
	var menu := results.get_node("UI/Panel/Scroll/VBox/Menu") as Button
	var reward_cards := results.get_node("UI/Panel/Scroll/VBox/RewardCards") as GridContainer
	var grade := results.get_node("UI/Panel/Scroll/VBox/RunGrade") as Label
	var progress := results.get_node("UI/Panel/Scroll/VBox/RivalProgress") as ProgressBar

	assert_that(kicker.text).is_equal("RUN RESULTS")
	assert_that(title.text).is_equal("Run Complete")
	assert_that(score.text).is_equal("512")
	assert_that(mode.text).is_equal("PURE MODE")
	assert_that(play_again.text).is_equal("Play Again")
	assert_that(menu.text).is_equal("New Run")
	assert_that(reward_cards.get_child_count()).is_equal(3)
	assert_that(grade.text).contains("Grade")
	assert_that(progress.value).is_greater_equal(0.0)
	assert_that((results.get_node("UI/Panel") as Control).pivot_offset).is_equal((results.get_node("UI/Panel") as Control).size * 0.5)

	results.queue_free()

func _assert_rect_inside(inner: Rect2, outer: Rect2, epsilon: float = 1.0) -> void:
	assert_that(inner.position.x).is_greater_equal(outer.position.x - epsilon)
	assert_that(inner.position.y).is_greater_equal(outer.position.y - epsilon)
	assert_that(inner.position.x + inner.size.x).is_less_equal(outer.position.x + outer.size.x + epsilon)
	assert_that(inner.position.y + inner.size.y).is_less_equal(outer.position.y + outer.size.y + epsilon)
