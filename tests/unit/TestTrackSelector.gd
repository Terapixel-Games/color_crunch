extends GdUnitTestSuite

func test_track_wraparound_left_and_right() -> void:
	var scene: PackedScene = load("res://ui/components/TrackSelector.tscn") as PackedScene
	var selector: TrackSelectorControl = scene.instantiate() as TrackSelectorControl
	assert_that(selector).is_not_null()
	get_tree().root.add_child(selector)
	selector.size = Vector2(420.0, 120.0)
	await get_tree().process_frame

	selector.tracks = ["A", "B", "C"]
	selector.current_index = 0
	selector.cycle_track(-1)
	assert_that(selector.current_index).is_equal(2)

	selector.current_index = 2
	selector.cycle_track(1)
	assert_that(selector.current_index).is_equal(0)

	selector.queue_free()

func test_marquee_decision_helper_conditions() -> void:
	assert_that(TrackSelectorControl.should_run_marquee(true, 240.0, 120.0, 3)).is_true()
	assert_that(TrackSelectorControl.should_run_marquee(false, 240.0, 120.0, 3)).is_false()
	assert_that(TrackSelectorControl.should_run_marquee(true, 100.0, 180.0, 3)).is_false()
	assert_that(TrackSelectorControl.should_run_marquee(true, 240.0, 120.0, 0)).is_false()

func test_marquee_starts_only_when_expanded_and_overflowing() -> void:
	var scene: PackedScene = load("res://ui/components/TrackSelector.tscn") as PackedScene
	var selector: TrackSelectorControl = scene.instantiate() as TrackSelectorControl
	assert_that(selector).is_not_null()
	get_tree().root.add_child(selector)
	selector.size = Vector2(360.0, 110.0)
	await get_tree().process_frame

	selector.tracks = ["This is a very long track name that should overflow the selector clip area"]
	selector.current_index = 0
	selector.set_expanded(true)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_that(selector.is_marquee_active()).is_true()

	selector.set_expanded(false)
	await get_tree().process_frame
	assert_that(selector.is_marquee_active()).is_false()

	selector.tracks = ["Short"]
	selector.set_expanded(true)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_that(selector.is_marquee_active()).is_false()

	selector.queue_free()
