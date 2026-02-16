extends GdUnitTestSuite

func test_button_pivot_is_centered_on_ready_and_resize() -> void:
	var button := LiquidGlassButton.new()
	button.size = Vector2(220.0, 90.0)
	get_tree().root.add_child(button)
	await get_tree().process_frame
	assert_that(button.pivot_offset).is_equal(button.size * 0.5)

	button.size = Vector2(300.0, 110.0)
	await get_tree().process_frame
	assert_that(button.pivot_offset).is_equal(button.size * 0.5)

	button.queue_free()
