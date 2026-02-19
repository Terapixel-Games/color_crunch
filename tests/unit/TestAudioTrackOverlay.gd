extends GdUnitTestSuite

func _create_root_host() -> Control:
	var host := Control.new()
	host.anchor_right = 1.0
	host.anchor_bottom = 1.0
	get_tree().root.add_child(host)
	return host

func _free_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.free()
	await get_tree().process_frame

func test_audio_track_overlay_input_contract_and_close() -> void:
	var host := _create_root_host()
	var scene: PackedScene = load("res://src/scenes/AudioTrackOverlay.tscn") as PackedScene
	var overlay: AudioTrackOverlay = scene.instantiate() as AudioTrackOverlay
	assert_that(overlay).is_not_null()
	host.add_child(overlay)
	await get_tree().process_frame

	var backdrop: Control = overlay.get_node("Backdrop") as Control
	var close_button: Button = overlay.get_node("Center/Panel/Margin/VBox/Close") as Button

	assert_that(overlay.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	assert_that(overlay.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	assert_that(backdrop.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_that(close_button.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

	close_button.emit_signal("pressed")
	await get_tree().process_frame
	assert_that(is_instance_valid(overlay)).is_false()
	await _free_node(host)

func test_audio_track_overlay_emits_track_selected_signal() -> void:
	var host := _create_root_host()
	var scene: PackedScene = load("res://src/scenes/AudioTrackOverlay.tscn") as PackedScene
	var overlay: AudioTrackOverlay = scene.instantiate() as AudioTrackOverlay
	assert_that(overlay).is_not_null()
	host.add_child(overlay)
	await get_tree().process_frame

	overlay.setup(["Off", "Neon Drift"], 0)
	await get_tree().process_frame

	var result := {"index": -1}
	overlay.track_selected.connect(func(_track_name: String, index: int) -> void:
		result["index"] = index
	)

	var selector: Control = overlay.get_node("Center/Panel/Margin/VBox/TrackSelector") as Control
	selector.emit_signal("track_changed", "Neon Drift", 1)
	await get_tree().process_frame

	assert_that(int(result["index"])).is_equal(1)
	await _free_node(host)
