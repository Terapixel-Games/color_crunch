extends GdUnitTestSuite

const PRISM_COLOR_PICKER_SCRIPT := preload("res://src/scenes/PrismColorPicker.gd")

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
	assert_that(modal.z_index).is_greater(10)
	assert_that(modal.z_as_relative).is_false()
	assert_that((modal.get_node("Dim") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that((modal.get_node("Center") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_that((modal.get_node("Center/Panel/ContentMargin") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_that((modal.get_node("Center/Panel/Close") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that((modal.get_node("Center/Panel/ContentMargin/VBox/Buttons/Cancel") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that((modal.get_node("Center/Panel/ContentMargin/VBox/Buttons/Confirm") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	var panel: Control = modal.get_node("Center/Panel") as Control
	var close_button: Control = modal.get_node("Center/Panel/Close") as Control
	assert_that(panel.pivot_offset).is_equal(panel.size * 0.5)
	assert_that(close_button.pivot_offset).is_equal(close_button.size * 0.5)
	assert_that(modal.get_node_or_null("Center/TargetHighlight")).is_not_null()

	var canceled := [false]
	modal.connect("canceled", func(_do_not_show_again: bool) -> void:
		canceled[0] = true
	)
	(modal.get_node("Center/Panel/ContentMargin/VBox/Buttons/Cancel") as Button).emit_signal("pressed")
	assert_that(canceled[0]).is_true()
	await get_tree().process_frame

func test_tutorial_tip_modal_keeps_long_tip_inside_panel_on_square_viewport() -> void:
	var original_size: Vector2i = get_tree().root.size
	var original_scale_size: Vector2i = get_tree().root.content_scale_size
	get_tree().root.size = Vector2i(640, 640)
	get_tree().root.content_scale_size = Vector2i(640, 640)

	var scene: PackedScene = load("res://addons/arcade_core/ui/TutorialTipModal.tscn") as PackedScene
	var modal: Control = scene.instantiate() as Control
	get_tree().root.add_child(modal)
	modal.call("configure", {
		"title": "Leaderboard Mode Update",
		"message": "Using power-ups moves this run to the Open leaderboard. Only games without power-up usage are posted to the Pure leaderboard.",
		"confirm_text": "Got it",
		"checkbox_text": "Don't show this again",
		"show_checkbox": true,
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var panel: Control = modal.get_node("Center/Panel") as Control
	var title: Control = modal.get_node("Center/Panel/ContentMargin/VBox/Title") as Control
	var message: Control = modal.get_node("Center/Panel/ContentMargin/VBox/Message") as Control
	var checkbox: Control = modal.get_node("Center/Panel/ContentMargin/VBox/DoNotShow") as Control
	var buttons: Control = modal.get_node("Center/Panel/ContentMargin/VBox/Buttons") as Control
	var close_button: Control = modal.get_node("Center/Panel/Close") as Control
	var panel_rect: Rect2 = panel.get_global_rect()
	var close_rect: Rect2 = close_button.get_global_rect()
	_assert_rect_inside(title.get_global_rect(), panel_rect)
	_assert_rect_inside(message.get_global_rect(), panel_rect)
	_assert_rect_inside(checkbox.get_global_rect(), panel_rect)
	_assert_rect_inside(buttons.get_global_rect(), panel_rect)
	_assert_rect_inside(close_rect, panel_rect)
	assert_that(title.get_global_rect().end.y).is_less_equal(message.get_global_rect().position.y + 1.0)
	assert_that(message.get_global_rect().end.y).is_less_equal(checkbox.get_global_rect().position.y + 1.0)
	assert_that(checkbox.get_global_rect().end.y).is_less_equal(buttons.get_global_rect().position.y + 1.0)
	assert_that(title.get_global_rect().end.x).is_less_equal(close_rect.position.x + 1.0)
	assert_that(panel_rect.end.y - buttons.get_global_rect().end.y).is_greater_equal(12.0)
	assert_that(checkbox.size.x).is_less_equal(340.0)
	assert_that(panel.size.x).is_greater_equal(500.0)

	modal.queue_free()
	await get_tree().process_frame
	get_tree().root.size = original_size
	get_tree().root.content_scale_size = original_scale_size

func test_tutorial_tip_modal_close_button_cancels_without_confirming() -> void:
	var scene: PackedScene = load("res://addons/arcade_core/ui/TutorialTipModal.tscn") as PackedScene
	var modal: Control = scene.instantiate() as Control
	get_tree().root.add_child(modal)
	modal.call("configure", {
		"title": "Open Run",
		"message": "Power-ups opt this run out of Pure.",
		"confirm_text": "Got it",
		"show_checkbox": true,
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var confirmed := [false]
	var canceled := [false]
	modal.connect("confirmed", func(_do_not_show_again: bool) -> void:
		confirmed[0] = true
	)
	modal.connect("canceled", func(_do_not_show_again: bool) -> void:
		canceled[0] = true
	)
	(modal.get_node("Center/Panel/Close") as Button).emit_signal("pressed")
	assert_that(confirmed[0]).is_false()
	assert_that(canceled[0]).is_true()
	await get_tree().process_frame

func test_game_tutorial_button_labels_fit_portrait_and_tap_anywhere_state() -> void:
	var original_size: Vector2i = get_tree().root.size
	var original_scale_size: Vector2i = get_tree().root.content_scale_size
	var original_seen: bool = SaveStore.is_tutorial_seen()
	get_tree().root.size = Vector2i(720, 1280)
	get_tree().root.content_scale_size = Vector2i(720, 1280)
	SaveStore.set_tutorial_seen(false)

	var game: Control = await _spawn_game()
	game.call("_show_tutorial", true)
	await get_tree().process_frame
	await get_tree().process_frame

	var panel: Control = game.get_node("UI/TutorialOverlay/Panel") as Control
	var skip_button: Button = game.get_node("UI/TutorialOverlay/Panel/Margin/VBox/Buttons/Skip") as Button
	var next_button: Button = game.get_node("UI/TutorialOverlay/Panel/Margin/VBox/Buttons/Next") as Button
	_assert_rect_inside(skip_button.get_global_rect(), panel.get_global_rect())
	_assert_rect_inside(next_button.get_global_rect(), panel.get_global_rect())
	_assert_button_text_fits(skip_button)
	_assert_button_text_fits(next_button)
	assert_that(skip_button.get_global_rect().intersects(next_button.get_global_rect())).is_false()

	game.call("_advance_tutorial_step")
	game.call("_advance_tutorial_step")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_that(next_button.text).is_equal("Tap Anywhere")
	_assert_button_text_fits(next_button)
	_assert_rect_inside(next_button.get_global_rect(), panel.get_global_rect())

	await _free_scene(game)
	SaveStore.set_tutorial_seen(original_seen)
	get_tree().root.size = original_size
	get_tree().root.content_scale_size = original_scale_size

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

func test_game_timer_chip_is_inside_top_hud_portrait_and_landscape() -> void:
	var original_size: Vector2i = get_tree().root.size
	var original_scale_size: Vector2i = get_tree().root.content_scale_size
	var viewports: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(1280, 720)]
	for viewport in viewports:
		get_tree().root.size = viewport
		get_tree().root.content_scale_size = viewport
		var game: Control = await _spawn_game()
		await get_tree().process_frame
		await get_tree().process_frame

		var top_bar_bg: Control = game.get_node("UI/TopBarBg") as Control
		var top_bar: Control = game.get_node("UI/TopBar") as Control
		var score_box: Control = game.get_node("UI/TopBar/ScoreBox") as Control
		var pause_button: Control = game.get_node("UI/TopBar/Pause") as Control
		var timer_chip: Control = game.get_node("UI/TopBar/RoundTimerChip") as Control
		var timer_value: Label = game.get_node("UI/TopBar/RoundTimerChip/Margin/VBox/Value") as Label

		assert_that(timer_chip.get_parent()).is_equal(top_bar)
		_assert_rect_inside(timer_chip.get_global_rect(), top_bar_bg.get_global_rect().grow(2.0))
		assert_that(timer_chip.get_global_rect().intersects(score_box.get_global_rect())).is_false()
		assert_that(timer_chip.get_global_rect().intersects(pause_button.get_global_rect())).is_false()
		assert_that(timer_value.text.begins_with("Time")).is_false()
		assert_that(timer_value.get_theme_font_size("font_size")).is_greater_equal(24)

		await _free_scene(game)
	get_tree().root.size = original_size
	get_tree().root.content_scale_size = original_scale_size

func test_prism_color_picker_input_contract_and_selection() -> void:
	var picker: Control = _make_prism_picker()
	get_tree().root.add_child(picker)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_that(picker.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	assert_that(picker.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_that(picker.z_index).is_greater(10)
	assert_that(picker.z_as_relative).is_false()
	assert_that((picker.get_node("Backdrop") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that((picker.get_node("Center") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_that((picker.get_node("Center/Panel") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_that((picker.get_node("Center/Panel/ContentMargin") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_that((picker.get_node("Center/Panel/ContentMargin/VBox") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_that((picker.get_node("Center/Panel/ContentMargin/VBox/Scroll/Grid") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_that((picker.get_node("Center/Panel/Close") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that((picker.get_node("Center/Panel/ContentMargin/VBox/Buttons/Cancel") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that((picker.get_node("Center/Panel/ContentMargin/VBox/Scroll/Grid/Level2") as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

	var selected_level := [-1]
	var closed := [false]
	picker.color_selected.connect(func(level: int) -> void:
		selected_level[0] = level
	)
	picker.closed.connect(func() -> void:
		closed[0] = true
	)
	(picker.get_node("Center/Panel/ContentMargin/VBox/Scroll/Grid/Level2") as Button).emit_signal("pressed")
	assert_that(selected_level[0]).is_equal(2)
	assert_that(closed[0]).is_true()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_that(is_instance_valid(picker)).is_false()

func test_prism_color_picker_close_button_cancels_without_selection() -> void:
	var picker: Control = _make_prism_picker()
	get_tree().root.add_child(picker)
	await get_tree().process_frame
	await get_tree().process_frame

	var selected := [false]
	var closed := [false]
	picker.color_selected.connect(func(_level: int) -> void:
		selected[0] = true
	)
	picker.closed.connect(func() -> void:
		closed[0] = true
	)
	(picker.get_node("Center/Panel/Close") as Button).emit_signal("pressed")
	assert_that(selected[0]).is_false()
	assert_that(closed[0]).is_true()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_that(is_instance_valid(picker)).is_false()

func test_prism_color_picker_layout_stays_inside_portrait_and_landscape() -> void:
	var original_size: Vector2i = get_tree().root.size
	var original_scale_size: Vector2i = get_tree().root.content_scale_size
	var viewports: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(1280, 720)]
	for viewport in viewports:
		get_tree().root.size = viewport
		get_tree().root.content_scale_size = viewport
		var picker: Control = _make_prism_picker()
		get_tree().root.add_child(picker)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		var bounds := Rect2(Vector2.ZERO, Vector2(viewport))
		var panel: Control = picker.get_node("Center/Panel") as Control
		var close_button: Control = picker.get_node("Center/Panel/Close") as Control
		var buttons: Control = picker.get_node("Center/Panel/ContentMargin/VBox/Buttons") as Control
		_assert_rect_inside(panel.get_global_rect(), bounds)
		_assert_rect_inside(close_button.get_global_rect(), panel.get_global_rect())
		_assert_rect_inside(buttons.get_global_rect(), panel.get_global_rect())

		picker.queue_free()
		await get_tree().process_frame
	get_tree().root.size = original_size
	get_tree().root.content_scale_size = original_scale_size

func _spawn_game() -> Control:
	var scene: PackedScene = load("res://src/scenes/Game.tscn") as PackedScene
	var game: Control = scene.instantiate() as Control
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	return game

func _make_prism_picker() -> Control:
	var picker: Control = PRISM_COLOR_PICKER_SCRIPT.new() as Control
	picker.configure([
		{
			"level": 1,
			"label": "MINT",
			"count": 6,
			"color": Color(0.56, 0.95, 0.86, 0.96),
			"font_color": Color(0.04, 0.10, 0.18, 1.0),
		},
		{
			"level": 2,
			"label": "LIME",
			"count": 4,
			"color": Color(0.52, 0.96, 0.62, 0.96),
			"font_color": Color(0.04, 0.10, 0.18, 1.0),
		},
		{
			"level": 5,
			"label": "SKY",
			"count": 2,
			"color": Color(0.44, 0.78, 0.98, 0.96),
			"font_color": Color(0.04, 0.10, 0.18, 1.0),
		},
	])
	return picker

func _free_scene(scene: Node) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _assert_rect_inside(inner: Rect2, outer: Rect2, epsilon: float = 1.0) -> void:
	assert_that(inner.position.x).is_greater_equal(outer.position.x - epsilon)
	assert_that(inner.position.y).is_greater_equal(outer.position.y - epsilon)
	assert_that(inner.end.x).is_less_equal(outer.end.x + epsilon)
	assert_that(inner.end.y).is_less_equal(outer.end.y + epsilon)

func _assert_button_text_fits(button: Button, horizontal_padding: float = 28.0) -> void:
	assert_that(button).is_not_null()
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var available_width: float = max(button.custom_minimum_size.x, button.size.x) - horizontal_padding
	assert_that(text_width).is_less_equal(available_width)
