extends GdUnitTestSuite

func before_test() -> void:
	SaveStore.data = {
		"high_score": 0,
		"last_play_date": "",
		"streak_days": 0,
		"streak_at_risk": 0,
		"games_played": 0,
	}
	SaveManager.data = SaveManager.DEFAULT_DATA.duplicate(true)

func test_streak_increments_next_day() -> void:
	var s := StreakManager
	s.record_game_play("2026-02-10")
	s.record_game_play("2026-02-11")
	assert_that(s.get_streak_days()).is_equal(2)

func test_streak_at_risk_on_skip() -> void:
	var s := StreakManager
	s.record_game_play("2026-02-10")
	s.record_game_play("2026-02-12")
	assert_that(s.get_streak_days()).is_equal(0)
	assert_that(s.is_streak_at_risk()).is_true()

func test_rewarded_save_restores() -> void:
	var s := StreakManager
	s.record_game_play("2026-02-10")
	s.record_game_play("2026-02-12")
	s.apply_rewarded_save("2026-02-12")
	assert_that(s.get_streak_days()).is_equal(1)
	assert_that(s.is_streak_at_risk()).is_false()
