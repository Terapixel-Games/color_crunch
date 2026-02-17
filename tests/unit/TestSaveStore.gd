extends GdUnitTestSuite

func test_clear_high_score_resets_to_zero() -> void:
	var original: int = int(SaveStore.data["high_score"])
	SaveStore.data["high_score"] = 1234
	SaveStore.clear_high_score()
	assert_that(int(SaveStore.data["high_score"])).is_equal(0)
	SaveStore.data["high_score"] = original

func test_set_selected_track_id_persists() -> void:
	var original: String = str(SaveStore.data.get("selected_track_id", "glassgrid"))
	SaveStore.set_selected_track_id("off")
	assert_that(str(SaveStore.data["selected_track_id"])).is_equal("off")
	SaveStore.set_selected_track_id(original)

func test_terapixel_identity_round_trip_and_clear() -> void:
	var original_user_id: String = SaveStore.get_terapixel_user_id()
	var original_name: String = SaveStore.get_terapixel_display_name()
	var original_email: String = SaveStore.get_terapixel_email()

	SaveStore.set_terapixel_identity("profile_123", "Player One", "Player@One.com")
	assert_that(SaveStore.get_terapixel_user_id()).is_equal("profile_123")
	assert_that(SaveStore.get_terapixel_display_name()).is_equal("Player One")
	assert_that(SaveStore.get_terapixel_email()).is_equal("player@one.com")

	SaveStore.clear_terapixel_identity()
	assert_that(SaveStore.get_terapixel_user_id()).is_equal("")
	assert_that(SaveStore.get_terapixel_display_name()).is_equal("")
	assert_that(SaveStore.get_terapixel_email()).is_equal("")

	SaveStore.set_terapixel_identity(original_user_id, original_name, original_email)
