extends GdUnitTestSuite

func test_is_muted_track_helper() -> void:
	var menu_script: GDScript = load("res://src/scenes/MainMenu.gd") as GDScript
	assert_that(menu_script).is_not_null()
	assert_that(menu_script.is_muted_track("off")).is_true()
	assert_that(menu_script.is_muted_track(" OFF ")).is_true()
	assert_that(menu_script.is_muted_track("glassgrid")).is_false()
	assert_that(menu_script.is_muted_track("default")).is_false()
