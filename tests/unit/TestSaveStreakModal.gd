extends GdUnitTestSuite

func test_modal_mouse_filters_capture_input() -> void:
	var modal_scene: PackedScene = load("res://src/scenes/SaveStreakModal.tscn")
	var modal: Control = modal_scene.instantiate() as Control
	assert_that(modal).is_not_null()
	get_tree().root.add_child(modal)
	await get_tree().process_frame
	assert_that(modal.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)

	var dim: Control = modal.get_node("Dim") as Control
	var center: Control = modal.get_node("Center") as Control
	var panel: Control = modal.get_node("Center/Panel") as Control
	var box: Control = modal.get_node("Center/Panel/VBox") as Control

	assert_that(modal.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_that(dim.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that(center.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_that(panel.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_that(box.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

	modal.queue_free()

func test_close_button_dismisses_modal() -> void:
	var modal_scene: PackedScene = load("res://src/scenes/SaveStreakModal.tscn")
	var modal: Control = modal_scene.instantiate() as Control
	assert_that(modal).is_not_null()
	get_tree().root.add_child(modal)
	await get_tree().process_frame

	var close_button: Button = modal.get_node("Center/Panel/VBox/Close") as Button
	assert_that(close_button).is_not_null()
	close_button.emit_signal("pressed")
	await get_tree().process_frame

	assert_that(is_instance_valid(modal)).is_false()
