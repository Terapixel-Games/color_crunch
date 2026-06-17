extends GdUnitTestSuite

func before() -> void:
	ProjectSettings.set_setting("lumarush/visual_test_mode", true)
	ProjectSettings.set_setting("lumarush/audio_test_mode", true)
	ProjectSettings.set_setting("color_crunch/nakama_enable_client", false)
	ProjectSettings.set_setting("color_crunch/client_events_enabled", false)
	NakamaService._read_runtime_settings()

func after() -> void:
	get_tree().paused = false

func test_pause_overlay_exposes_tutorial_replay_and_input_contract() -> void:
	var scene: PackedScene = load("res://src/scenes/PauseOverlay.tscn") as PackedScene
	var pause: Control = scene.instantiate() as Control
	get_tree().root.add_child(pause)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_that(pause.process_mode).is_equal(Node.PROCESS_MODE_WHEN_PAUSED)
	assert_that(pause.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_that((pause.get_node("Dim") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that((pause.get_node("Panel/VBox") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_that((pause.get_node("Panel/VBox/Resume") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that((pause.get_node("Panel/VBox/Tutorial") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that((pause.get_node("Panel/VBox/Quit") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that((pause.get_node("Panel") as Control).pivot_offset).is_equal((pause.get_node("Panel") as Control).size * 0.5)

	var tutorial_requested := [false]
	pause.connect("tutorial_requested", func() -> void:
		tutorial_requested[0] = true
	)
	(pause.get_node("Panel/VBox/Tutorial") as Button).emit_signal("pressed")
	assert_that(tutorial_requested[0]).is_true()
	await get_tree().process_frame

func test_tutorial_tip_modal_uses_consistent_input_and_pivots() -> void:
	var scene: PackedScene = load("res://addons/arcade_core/ui/TutorialTipModal.tscn") as PackedScene
	var modal: Control = scene.instantiate() as Control
	get_tree().root.add_child(modal)
	modal.call("configure", {
		"title": "Target Tip",
		"message": "This tip points at a control.",
		"show_cancel": true,
		"target_rect": Rect2(Vector2(120, 180), Vector2(80, 64)),
	})
	await get_tree().process_frame
	await get_tree().process_frame

	assert_that(modal.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	assert_that(modal.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_that((modal.get_node("Dim") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that((modal.get_node("Center") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_that((modal.get_node("Center/Panel/ContentMargin") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_that((modal.get_node("Center/Panel/ContentMargin/VBox/Buttons/Cancel") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that((modal.get_node("Center/Panel/ContentMargin/VBox/Buttons/Confirm") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	var panel: Control = modal.get_node("Center/Panel") as Control
	assert_that(panel.pivot_offset).is_equal(panel.size * 0.5)
	assert_that(modal.get_node_or_null("Center/TargetHighlight")).is_not_null()

	var canceled := [false]
	modal.connect("canceled", func(_do_not_show_again: bool) -> void:
		canceled[0] = true
	)
	(modal.get_node("Center/Panel/ContentMargin/VBox/Buttons/Cancel") as Button).emit_signal("pressed")
	assert_that(canceled[0]).is_true()
	await get_tree().process_frame

func test_game_tutorial_first_run_replay_and_overlay_close_behavior() -> void:
	var original_seen: bool = SaveStore.is_tutorial_seen()
	SaveStore.set_tutorial_seen(false)
	var game: Control = await _spawn_game()
	game.call("_close_tutorial", false)
	await get_tree().process_frame

	game.call("_show_tutorial", true)
	await get_tree().process_frame
	assert_that(game.get("_tutorial_overlay")).is_not_null()
	assert_that(int(game.get("_tutorial_step"))).is_equal(0)

	game.call("_advance_tutorial_step")
	assert_that(int(game.get("_tutorial_step"))).is_equal(1)
	game.call("_close_tutorial", true)
	await get_tree().process_frame
	assert_that(SaveStore.is_tutorial_seen()).is_true()

	SaveStore.set_tutorial_seen(false)
	game.call("_show_tutorial", true)
	await get_tree().process_frame
	assert_that(game.get("_tutorial_overlay")).is_not_null()
	game.call("_hide_tutorial_for_overlay")
	await get_tree().process_frame
	assert_that(game.get("_tutorial_overlay")).is_null()
	assert_that(SaveStore.is_tutorial_seen()).is_false()

	await _free_scene(game)
	SaveStore.set_tutorial_seen(original_seen)

func _spawn_game() -> Control:
	var scene: PackedScene = load("res://src/scenes/Game.tscn") as PackedScene
	var game: Control = scene.instantiate() as Control
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	return game

func _free_scene(scene: Node) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
