extends GdUnitTestSuite

func test_run_mode_switches_to_open_after_powerup_usage() -> void:
	var original_selected_mode: String = RunManager.last_run_selected_mode
	RunManager.last_run_selected_mode = "OPEN"
	RunManager.set_run_leaderboard_context(0, 0, {})
	var no_powerup_mode: String = RunManager.last_run_leaderboard_mode
	RunManager.last_run_selected_mode = original_selected_mode
	assert_that(no_powerup_mode).is_equal("PURE")
	RunManager.set_run_leaderboard_context(1, 0, {"undo": 1})
	assert_that(RunManager.last_run_leaderboard_mode).is_equal("OPEN")
	assert_that(RunManager.last_run_powerups_used).is_equal(1)
	assert_that(int(RunManager.last_run_powerup_breakdown.get("undo", 0))).is_equal(1)

func test_tip_dismissal_hides_open_leaderboard_tip() -> void:
	var tip_id := SaveStore.TIP_OPEN_LEADERBOARD_FIRST_POWERUP
	var original_show := SaveStore.should_show_tip(tip_id, true)

	SaveStore.set_tip_dismissed(tip_id, true)
	assert_that(SaveStore.should_show_tip(tip_id, true)).is_false()

	SaveStore.set_tip_dismissed(tip_id, false)
	assert_that(SaveStore.should_show_tip(tip_id, true)).is_true()

	SaveStore.set_tip_dismissed(tip_id, not original_show)
