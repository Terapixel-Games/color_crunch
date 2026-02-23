extends GdUnitTestSuite

func before() -> void:
	ProjectSettings.set_setting("lumarush/visual_test_mode", true)
	ProjectSettings.set_setting("lumarush/audio_test_mode", true)
	ProjectSettings.set_setting("lumarush/use_mock_ads", true)
	ProjectSettings.set_setting("color_crunch/nakama_enable_client", false)
	ProjectSettings.set_setting("color_crunch/client_events_enabled", false)
	NakamaService._read_runtime_settings()

func test_main_menu_track_cycle_updates_selection() -> void:
	var scene: PackedScene = load("res://src/scenes/MainMenu.tscn") as PackedScene
	var menu: Control = scene.instantiate() as Control
	get_tree().root.add_child(menu)
	await get_tree().process_frame

	var tracks: Array[Dictionary] = MusicManager.get_available_tracks()
	if tracks.size() > 1:
		var before: String = str(SaveStore.data.get("selected_track_id", ""))
		menu._cycle_track(1)
		await get_tree().process_frame
		var after: String = str(SaveStore.data.get("selected_track_id", ""))
		assert_that(after).is_not_equal(before)
	else:
		assert_that(tracks.size()).is_equal(1)

	await _free_scene(menu)

func test_main_menu_start_starts_game_scene() -> void:
	var scene: PackedScene = load("res://src/scenes/MainMenu.tscn") as PackedScene
	var menu: Control = scene.instantiate() as Control
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	menu._on_start_pressed()
	await get_tree().process_frame
	assert_that(get_tree().current_scene).is_not_null()
	assert_that(String(get_tree().current_scene.scene_file_path)).is_equal("res://src/scenes/Game.tscn")
	await _free_scene(get_tree().current_scene)
	await _free_scene(menu)

func _free_scene(scene: Node) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
