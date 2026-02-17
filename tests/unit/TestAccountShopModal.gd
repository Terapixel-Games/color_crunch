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

func test_account_modal_shows_logout_for_linked_profile() -> void:
	var original_user_id: String = SaveStore.get_terapixel_user_id()
	var original_name: String = SaveStore.get_terapixel_display_name()
	var original_email: String = SaveStore.get_terapixel_email()
	SaveStore.set_terapixel_identity("profile_linked_1", "Linked", "linked@example.com")

	var modal_scene: PackedScene = load("res://src/scenes/AccountModal.tscn")
	var modal: Control = modal_scene.instantiate() as Control
	assert_that(modal).is_not_null()
	get_tree().root.add_child(modal)
	await get_tree().process_frame

	var email_input: LineEdit = modal.get_node("Panel/VBox/Email") as LineEdit
	var send_button: Button = modal.get_node("Panel/VBox/SendMagicLink") as Button
	assert_that(email_input).is_not_null()
	assert_that(send_button).is_not_null()
	assert_that(email_input.editable).is_false()
	assert_that(email_input.text).is_equal("linked@example.com")
	assert_that(send_button.text).is_equal("Logout")

	modal.queue_free()
	await get_tree().process_frame
	SaveStore.set_terapixel_identity(original_user_id, original_name, original_email)

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
