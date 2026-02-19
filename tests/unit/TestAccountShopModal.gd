extends GdUnitTestSuite

var _original_enable_client: bool = true

func before_test() -> void:
	_original_enable_client = bool(ProjectSettings.get_setting("color_crunch/nakama_enable_client", true))
	ProjectSettings.set_setting("color_crunch/nakama_enable_client", false)
	NakamaService.set("_connect_enabled", false)

func after_test() -> void:
	ProjectSettings.set_setting("color_crunch/nakama_enable_client", _original_enable_client)
	NakamaService.set("_connect_enabled", _original_enable_client)

func test_account_modal_input_contract_and_close() -> void:
	var modal_scene: PackedScene = load("res://src/scenes/AccountModal.tscn")
	var modal: Control = modal_scene.instantiate() as Control
	assert_that(modal).is_not_null()
	get_tree().root.add_child(modal)
	await get_tree().process_frame

	var backdrop: Control = modal.get_node("Backdrop") as Control
	var scroll: ScrollContainer = modal.get_node("Panel/VBox/Scroll") as ScrollContainer
	var close_button: Button = modal.get_node("Panel/VBox/Footer/Close") as Button

	assert_that(modal.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	assert_that(modal.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_that(backdrop.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that(scroll).is_not_null()
	assert_that(close_button.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

	close_button.emit_signal("pressed")
	await get_tree().create_timer(0.25).timeout
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

	var email_input: LineEdit = modal.get_node("Panel/VBox/Scroll/Content/Email") as LineEdit
	var send_button: Button = modal.get_node("Panel/VBox/Scroll/Content/SendMagicLink") as Button
	var status_label: Label = modal.get_node("Panel/VBox/Status") as Label
	var username_header: Control = modal.get_node("Panel/VBox/Scroll/Content/UsernameHeader") as Control
	var username_input: LineEdit = modal.get_node("Panel/VBox/Scroll/Content/Username") as LineEdit
	var username_button: Button = modal.get_node("Panel/VBox/Scroll/Content/UpdateUsername") as Button
	var merge_header: Control = modal.get_node("Panel/VBox/Scroll/Content/MergeHeader") as Control
	assert_that(email_input).is_not_null()
	assert_that(send_button).is_not_null()
	assert_that(status_label).is_not_null()
	assert_that(username_header).is_not_null()
	assert_that(username_input).is_not_null()
	assert_that(username_button).is_not_null()
	assert_that(merge_header).is_not_null()
	assert_that(email_input.editable).is_false()
	assert_that(email_input.text).is_equal("linked@example.com")
	assert_that(send_button.text).is_equal("Logout")
	assert_that(status_label.text).is_equal("Logged in as: linked@example.com")
	assert_that(username_header.visible).is_true()
	assert_that(username_input.visible).is_true()
	assert_that(username_button.visible).is_true()
	assert_that(merge_header.visible).is_false()

	modal.queue_free()
	await get_tree().process_frame
	SaveStore.set_terapixel_identity(original_user_id, original_name, original_email)

func test_account_modal_hides_username_and_merge_for_guest() -> void:
	var original_user_id: String = SaveStore.get_terapixel_user_id()
	var original_name: String = SaveStore.get_terapixel_display_name()
	var original_email: String = SaveStore.get_terapixel_email()
	SaveStore.clear_terapixel_identity()

	var modal_scene: PackedScene = load("res://src/scenes/AccountModal.tscn")
	var modal: Control = modal_scene.instantiate() as Control
	assert_that(modal).is_not_null()
	get_tree().root.add_child(modal)
	await get_tree().process_frame

	var username_header: Control = modal.get_node("Panel/VBox/Scroll/Content/UsernameHeader") as Control
	var username_input: LineEdit = modal.get_node("Panel/VBox/Scroll/Content/Username") as LineEdit
	var username_button: Button = modal.get_node("Panel/VBox/Scroll/Content/UpdateUsername") as Button
	var merge_header: Control = modal.get_node("Panel/VBox/Scroll/Content/MergeHeader") as Control
	var merge_input: LineEdit = modal.get_node("Panel/VBox/Scroll/Content/MergeCode") as LineEdit
	var merge_create_button: Button = modal.get_node("Panel/VBox/Scroll/Content/CreateMergeCode") as Button
	var merge_redeem_button: Button = modal.get_node("Panel/VBox/Scroll/Content/RedeemMergeCode") as Button

	assert_that(username_header.visible).is_false()
	assert_that(username_input.visible).is_false()
	assert_that(username_button.visible).is_false()
	assert_that(merge_header.visible).is_false()
	assert_that(merge_input.visible).is_false()
	assert_that(merge_create_button.visible).is_false()
	assert_that(merge_redeem_button.visible).is_false()

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
	var scroll: ScrollContainer = modal.get_node("Panel/VBox/Scroll") as ScrollContainer
	var powerups_box: VBoxContainer = modal.get_node("Panel/VBox/Scroll/Content/Powerups") as VBoxContainer
	var refresh_button: Button = modal.get_node("Panel/VBox/Footer/Actions/RefreshWallet") as Button
	var close_button: Button = modal.get_node("Panel/VBox/Footer/Actions/Close") as Button

	assert_that(modal.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	assert_that(modal.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_that(backdrop.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that(scroll).is_not_null()
	assert_that(powerups_box).is_not_null()
	assert_that(refresh_button).is_not_null()
	assert_that(refresh_button.size.y).is_greater_equal(40.0)
	assert_that(close_button.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

	close_button.emit_signal("pressed")
	await get_tree().create_timer(0.25).timeout
	assert_that(is_instance_valid(modal)).is_false()

func test_shop_modal_close_button_visible_at_720x1280() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.disable_3d = true
	viewport.handle_input_locally = true
	get_tree().root.add_child(viewport)
	var host := Control.new()
	host.anchor_right = 1.0
	host.anchor_bottom = 1.0
	viewport.add_child(host)

	var modal_scene: PackedScene = load("res://src/scenes/ShopModal.tscn")
	var modal: Control = modal_scene.instantiate() as Control
	host.add_child(modal)
	await get_tree().process_frame

	var close_button: Button = modal.get_node("Panel/VBox/Footer/Actions/Close") as Button
	assert_that(close_button).is_not_null()
	assert_that(close_button.visible).is_true()
	assert_that(close_button.size.y).is_greater_equal(48.0)
	var close_rect: Rect2 = close_button.get_global_rect()
	assert_that(close_rect.position.y + close_rect.size.y).is_less_equal(1280.0)

	viewport.queue_free()
	await get_tree().process_frame

func test_shop_modal_theme_actions_fit_row_at_720x1280() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.disable_3d = true
	viewport.handle_input_locally = true
	get_tree().root.add_child(viewport)
	var host := Control.new()
	host.anchor_right = 1.0
	host.anchor_bottom = 1.0
	viewport.add_child(host)

	var modal_scene: PackedScene = load("res://src/scenes/ShopModal.tscn")
	var modal: Control = modal_scene.instantiate() as Control
	host.add_child(modal)
	await get_tree().process_frame
	await get_tree().process_frame

	var row: Control = modal.get_node("Panel/VBox/Scroll/Content/Themes/ThemeNeon/Margin/Row") as Control
	var actions_row: HBoxContainer = modal.get_node("Panel/VBox/Scroll/Content/Themes/ThemeNeon/Margin/Row/ThemeNeonActions") as HBoxContainer
	var buy_button: Button = modal.get_node("Panel/VBox/Scroll/Content/Themes/ThemeNeon/Margin/Row/ThemeNeonActions/ActionButton") as Button
	var ad_button: Button = modal.get_node("Panel/VBox/Scroll/Content/Themes/ThemeNeon/Margin/Row/ThemeNeonActions/UnlockNeonAd") as Button

	assert_that(row).is_not_null()
	assert_that(actions_row).is_not_null()
	assert_that(buy_button).is_not_null()
	assert_that(ad_button).is_not_null()
	assert_that(actions_row.get_child_count()).is_equal(2)

	var row_rect: Rect2 = row.get_global_rect()
	var buy_rect: Rect2 = buy_button.get_global_rect()
	var ad_rect: Rect2 = ad_button.get_global_rect()

	assert_that(buy_rect.size.x).is_greater(40.0)
	assert_that(ad_rect.size.x).is_greater(40.0)
	assert_that(buy_rect.position.y).is_greater_equal(row_rect.position.y - 1.0)
	assert_that(ad_rect.position.y).is_greater_equal(row_rect.position.y - 1.0)
	assert_that(buy_rect.position.y + buy_rect.size.y).is_less_equal(row_rect.position.y + row_rect.size.y + 1.0)
	assert_that(ad_rect.position.y + ad_rect.size.y).is_less_equal(row_rect.position.y + row_rect.size.y + 1.0)
	assert_that(buy_rect.intersects(ad_rect)).is_false()

	viewport.queue_free()
	await get_tree().process_frame

func test_account_modal_uses_username_label_not_bonus() -> void:
	var modal_scene: PackedScene = load("res://src/scenes/AccountModal.tscn")
	var modal: Control = modal_scene.instantiate() as Control
	assert_that(modal).is_not_null()
	get_tree().root.add_child(modal)
	await get_tree().process_frame

	var username_label: Label = modal.get_node("Panel/VBox/Scroll/Content/UsernameHeader/Label") as Label
	assert_that(username_label).is_not_null()
	assert_that(username_label.text).is_equal("Username")

	var labels := modal.find_children("*", "Label", true, false)
	var contains_bonus := false
	for node in labels:
		var label := node as Label
		if label != null and label.text.to_lower().find("bonus") != -1:
			contains_bonus = true
			break
	assert_that(contains_bonus).is_false()

	modal.queue_free()
	await get_tree().process_frame
