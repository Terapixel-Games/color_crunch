extends GdUnitTestSuite

func test_account_modal_input_contract_and_close() -> void:
	var modal_scene: PackedScene = load("res://src/scenes/AccountModal.tscn")
	var modal: Control = modal_scene.instantiate() as Control
	assert_that(modal).is_not_null()
	get_tree().root.add_child(modal)
	await get_tree().process_frame

	var backdrop: Control = modal.get_node("Backdrop") as Control
	var close_button: Button = modal.get_node("Panel/VBox/Close") as Button

	assert_that(modal.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	assert_that(modal.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_that(backdrop.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that(close_button.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

	close_button.emit_signal("pressed")
	await get_tree().process_frame
	assert_that(is_instance_valid(modal)).is_false()

func test_shop_modal_input_contract_and_close() -> void:
	var modal_scene: PackedScene = load("res://src/scenes/ShopModal.tscn")
	var modal: Control = modal_scene.instantiate() as Control
	assert_that(modal).is_not_null()
	get_tree().root.add_child(modal)
	await get_tree().process_frame

	var backdrop: Control = modal.get_node("Backdrop") as Control
	var close_button: Button = modal.get_node("Panel/VBox/Close") as Button

	assert_that(modal.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	assert_that(modal.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_that(backdrop.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that(close_button.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

	close_button.emit_signal("pressed")
	await get_tree().process_frame
	assert_that(is_instance_valid(modal)).is_false()
