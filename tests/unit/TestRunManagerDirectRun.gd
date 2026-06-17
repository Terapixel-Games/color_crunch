extends GdUnitTestSuite

func test_prepare_run_start_supports_direct_game_boot_flow() -> void:
	var original_mode: String = SaveStore.get_preferred_mode()
	var original_daily: bool = SaveStore.get_daily_challenge_enabled()
	SaveStore.set_preferred_mode("OPEN")
	SaveStore.set_daily_challenge_enabled(false)

	RunManager.last_run_powerups_used = 4
	RunManager.last_run_coins_spent = 300
	RunManager.last_run_leaderboard_mode = "PURE"
	RunManager.last_run_powerup_breakdown = {"undo": 2}
	RunManager.last_run_duration_ms = 999
	RunManager.prepare_run_start()

	assert_that(RunManager.last_run_selected_mode).is_equal("OPEN")
	assert_that(RunManager.last_run_daily_challenge).is_false()
	assert_that(RunManager.last_run_powerups_used).is_equal(0)
	assert_that(RunManager.last_run_coins_spent).is_equal(0)
	assert_that(RunManager.last_run_leaderboard_mode).is_equal("OPEN")
	assert_that(RunManager.last_run_powerup_breakdown).is_empty()
	assert_that(RunManager.last_run_duration_ms).is_equal(0)

	SaveStore.set_preferred_mode(original_mode)
	SaveStore.set_daily_challenge_enabled(original_daily)

func test_main_menu_is_fallback_scene_not_default_boot_target() -> void:
	assert_that(RunManager.MENU_SCENE).is_equal("res://src/scenes/MainMenu.tscn")
	assert_that(RunManager.GAME_SCENE).is_equal("res://src/scenes/Game.tscn")
	assert_that(RunManager.MENU_SCENE).is_not_equal(RunManager.GAME_SCENE)
