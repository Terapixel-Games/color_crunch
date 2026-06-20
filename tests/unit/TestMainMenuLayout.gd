extends GdUnitTestSuite

func test_menu_panel_is_centered_in_viewport() -> void:
	var scene: PackedScene = load("res://src/scenes/MainMenu.tscn") as PackedScene
	var menu: Control = scene.instantiate() as Control
	assert_that(menu).is_not_null()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	var panel: Control = menu.get_node_or_null("UI/RootMargin/Layout/Center/PanelShell/Panel") as Control
	if panel == null:
		panel = menu.get_node_or_null("UI/Panel") as Control
	var box: Control = menu.get_node_or_null("UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox") as Control
	if box == null:
		box = menu.get_node_or_null("UI/VBox") as Control
	assert_that(panel).is_not_null()
	assert_that(box).is_not_null()
	var audio_button: Control = menu.get_node_or_null("UI/RootMargin/Layout/TopBar/Audio") as Control
	var mode_button: Button = menu.get_node_or_null("UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/SecondaryOptions/OptionRow/ModeToggle") as Button
	var title: Label = menu.get_node_or_null("UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/Title") as Label
	var logo_art: TextureRect = menu.get_node_or_null("UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/VBox/LogoArt") as TextureRect
	assert_that(audio_button).is_not_null()
	assert_that(mode_button).is_not_null()
	assert_that(title).is_not_null()
	assert_that(logo_art).is_not_null()
	assert_that(mode_button.visible).is_false()
	assert_that(mode_button.disabled).is_true()
	assert_that(mode_button.focus_mode).is_equal(Control.FOCUS_NONE)
	assert_that(title.visible).is_false()
	assert_that(logo_art.visible).is_true()
	assert_that(logo_art.texture).is_not_null()
	assert_that(logo_art.texture.resource_path).is_equal("res://assets/marketing/logo_horizontal.png")
	var viewport_center: Vector2 = menu.get_viewport_rect().size * 0.5
	var panel_center: Vector2 = panel.global_position + (panel.size * 0.5)
	var box_center: Vector2 = box.global_position + (box.size * 0.5)

	assert_that(absf(panel_center.x - viewport_center.x)).is_less_equal(8.0)
	assert_that(absf(panel_center.y - viewport_center.y)).is_less_equal(8.0)
	assert_that(absf(box_center.x - panel_center.x)).is_less_equal(8.0)
	assert_that(absf(box_center.y - panel_center.y)).is_less_equal(8.0)

	menu.queue_free()
