extends GdUnitTestSuite

func test_menu_panel_is_centered_in_viewport() -> void:
	var scene: PackedScene = load("res://src/scenes/MainMenu.tscn") as PackedScene
	var menu: Control = scene.instantiate() as Control
	assert_that(menu).is_not_null()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	var panel: Control = menu.get_node("UI/Panel") as Control
	var box: Control = menu.get_node("UI/VBox") as Control
	assert_that(panel).is_not_null()
	assert_that(box).is_not_null()
	var viewport_center: Vector2 = menu.get_viewport_rect().size * 0.5
	var panel_center: Vector2 = panel.global_position + (panel.size * 0.5)
	var box_center: Vector2 = box.global_position + (box.size * 0.5)

	assert_that(absf(panel_center.x - viewport_center.x)).is_less_equal(1.0)
	assert_that(absf(panel_center.y - viewport_center.y)).is_less_equal(1.0)
	assert_that(absf(box_center.x - panel_center.x)).is_less_equal(1.0)
	assert_that(absf(box_center.y - panel_center.y)).is_less_equal(1.0)

	menu.queue_free()
