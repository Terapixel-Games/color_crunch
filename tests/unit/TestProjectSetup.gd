extends GdUnitTestSuite

func test_project_name_and_main_scene() -> void:
	assert_that(String(ProjectSettings.get_setting("application/config/name"))).is_equal("Color Crunch")
	assert_that(String(ProjectSettings.get_setting("application/run/main_scene"))).is_equal("res://src/scenes/MainMenu.tscn")

func test_required_autoloads_are_registered() -> void:
	assert_that(String(ProjectSettings.get_setting("autoload/SaveStore"))).is_equal("*res://src/data/SaveStore.gd")
	assert_that(String(ProjectSettings.get_setting("autoload/StreakManager"))).is_equal("*res://src/data/StreakManager.gd")
	assert_that(String(ProjectSettings.get_setting("autoload/AdManager"))).is_equal("*res://src/ads/AdManager.gd")
	assert_that(String(ProjectSettings.get_setting("autoload/MusicManager"))).is_equal("*res://src/audio/MusicManager.gd")
	assert_that(String(ProjectSettings.get_setting("autoload/BackgroundMood"))).is_equal("*res://src/visual/BackgroundMood.gd")
	assert_that(String(ProjectSettings.get_setting("autoload/VFXManager"))).is_equal("*res://src/vfx/VFXManager.gd")
	assert_that(String(ProjectSettings.get_setting("autoload/RunManager"))).is_equal("*res://src/core/RunManager.gd")
	assert_that(String(ProjectSettings.get_setting("autoload/NakamaService"))).is_equal("*res://src/network/NakamaService.gd")

func test_mobile_portrait_and_stretch_settings() -> void:
	assert_that(int(ProjectSettings.get_setting("display/window/handheld/orientation"))).is_equal(1)
	assert_that(String(ProjectSettings.get_setting("display/window/stretch/mode"))).is_equal("canvas_items")
	assert_that(String(ProjectSettings.get_setting("display/window/stretch/aspect"))).is_equal("keep_width")

func test_required_addons_exist() -> void:
	var gdunit_path: String = ProjectSettings.globalize_path("res://addons/gdUnit4")
	var admob_path: String = ProjectSettings.globalize_path("res://addons/AdmobPlugin")
	assert_that(DirAccess.dir_exists_absolute(gdunit_path)).is_true()
	assert_that(DirAccess.dir_exists_absolute(admob_path)).is_true()

func test_color_crunch_backend_defaults_exist() -> void:
	assert_that(bool(ProjectSettings.get_setting("color_crunch/nakama_enable_client"))).is_false()
	assert_that(String(ProjectSettings.get_setting("color_crunch/nakama_base_url"))).is_equal("http://127.0.0.1:7350")
	assert_that(String(ProjectSettings.get_setting("color_crunch/nakama_server_key"))).is_equal("colorcrunch-dev-key")
	assert_that(int(ProjectSettings.get_setting("color_crunch/nakama_leaderboard_limit"))).is_equal(10)
	assert_that(String(ProjectSettings.get_setting("color_crunch/platform"))).is_equal("terapixel")
	assert_that(String(ProjectSettings.get_setting("color_crunch/export_target"))).is_equal("web")
