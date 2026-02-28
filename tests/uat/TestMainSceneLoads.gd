extends "res://tests/framework/TestCase.gd"

func test_main_scene_resource_loads() -> void:
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	assert_true(not main_scene.is_empty(), "application/run/main_scene must be set")
	assert_true(ResourceLoader.exists(main_scene), "Main scene does not exist: %s" % main_scene)
	var packed := load(main_scene)
	assert_true(packed is PackedScene, "Main scene is not a PackedScene: %s" % main_scene)
	if packed is PackedScene:
		var instance := (packed as PackedScene).instantiate()
		assert_true(instance != null, "Main scene instantiate() returned null")
		if instance is Node:
			(instance as Node).queue_free()
