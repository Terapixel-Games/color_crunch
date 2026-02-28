extends GdUnitTestSuite

const BACKGROUND_CONTROLLER_SCRIPT := preload("res://addons/arcade_core/Background/AC_BackgroundController.gd")

func test_load_profile_changes_active_profile_name() -> void:
	var controller := await _spawn_controller()

	controller.load_profile("neon_arcade")
	await get_tree().process_frame
	assert_that(controller.active_profile_name).is_equal("neon_arcade")

	controller.queue_free()

func test_set_tier_clamps_to_minimum() -> void:
	var controller := await _spawn_controller()

	controller.set_tier(-7)
	assert_that(controller._tier).is_equal(1)
	controller.set_tier(6)
	assert_that(controller._tier).is_equal(6)

	controller.queue_free()

func test_set_combo_intensity_clamps_and_eases() -> void:
	var controller := await _spawn_controller()

	controller.set_combo_intensity(5.0)
	assert_that(controller._combo_target).is_equal(1.0)
	for i in range(10):
		controller._process(0.1)
	assert_that(controller._combo_current).is_greater(0.0)
	assert_that(controller._combo_current).is_less_equal(1.0)

	controller.set_combo_intensity(-1.0)
	assert_that(controller._combo_target).is_equal(0.0)
	for i in range(14):
		controller._process(0.1)
	assert_that(controller._combo_current).is_less_equal(0.1)

	controller.queue_free()

func test_layer_toggles_work_without_crash() -> void:
	var controller := await _spawn_controller()
	controller.load_profile("neon_arcade")
	controller.set_tier(5)
	await get_tree().process_frame

	var viewport_root := _viewport_root(controller)
	var grid := viewport_root.get_node("Grid") as ColorRect
	var sweep := viewport_root.get_node("Sweep") as CanvasItem
	var flow := viewport_root.get_node("FlowParticles") as CanvasItem

	controller.set_enabled_layer("grid", false)
	controller.set_enabled_layer("sweep", false)
	controller.set_enabled_layer("flow_particles", false)
	assert_that(grid.visible).is_false()
	assert_that(sweep.visible).is_false()
	assert_that(flow.visible).is_false()

	controller.set_enabled_layer("grid", true)
	controller.set_enabled_layer("sweep", true)
	controller.set_enabled_layer("flow_particles", true)
	assert_that(grid.visible).is_true()
	assert_that(sweep.visible).is_true()
	assert_that(flow.visible).is_true()

	controller.queue_free()

func _spawn_controller():
	var controller := BACKGROUND_CONTROLLER_SCRIPT.new()
	get_tree().root.add_child(controller)
	await get_tree().process_frame
	return controller

func _viewport_root(controller: Node) -> Control:
	var canvas := controller.get_child(0) as CanvasLayer
	return canvas.get_node("ViewportRoot") as Control
