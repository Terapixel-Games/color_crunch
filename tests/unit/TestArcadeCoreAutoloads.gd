extends "res://tests/framework/TestCase.gd"

func test_arcadecore_singletons_exist() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load("res://project.godot")
	assert_equal(err, OK, "project.godot should load for autoload checks")
	if err != OK:
		return
	var autoloads: Dictionary = {}
	for key in cfg.get_section_keys("autoload"):
		autoloads[str(key)] = cfg.get_value("autoload", str(key), "")
	assert_true(autoloads.has("SaveManager"), "Missing SaveManager autoload")
	assert_true(autoloads.has("StreakManager"), "Missing StreakManager autoload")
	assert_true(autoloads.has("AudioManager"), "Missing AudioManager autoload")
	assert_true(autoloads.has("Fx"), "Missing Fx autoload")
	assert_true(autoloads.has("AdManager"), "Missing AdManager autoload")

func test_multiresolution_display_defaults() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load("res://project.godot")
	assert_equal(err, OK, "project.godot should load for display checks")
	if err != OK:
		return

	assert_equal(int(cfg.get_value("display", "window/size/viewport_width", 0)), 1080, "Viewport width should default to 1080")
	assert_equal(int(cfg.get_value("display", "window/size/viewport_height", 0)), 1920, "Viewport height should default to 1920")
	assert_true(bool(cfg.get_value("display", "window/size/resizable", false)), "Window should be resizable")
	assert_equal(str(cfg.get_value("display", "window/stretch/mode", "")), "canvas_items", "Stretch mode should be canvas_items")
	assert_equal(str(cfg.get_value("display", "window/stretch/aspect", "")), "expand", "Stretch aspect should be expand")

func test_save_manager_basics() -> void:
	var script: Script = load("res://addons/arcade_core/SaveManager.gd")
	assert_true(script != null, "SaveManager script failed to load")
	if script == null:
		return
	var save_manager: Node = script.new()
	save_manager.call("load_save")
	save_manager.call("set_best", "arcadecore_smoke_score", 123)
	var value: int = int(save_manager.call("get_best", "arcadecore_smoke_score", 0))
	assert_equal(value, 123, "SaveManager get/set best failed")

func test_admanager_compat_aliases_exist() -> void:
	var admanager_path := "res://addons/arcade_core/AdManager.gd"
	assert_true(ResourceLoader.exists(admanager_path), "AdManager script missing")
	if not ResourceLoader.exists(admanager_path):
		return
	var text := FileAccess.get_file_as_string(admanager_path)
	assert_true(text.find("func show_rewarded_for_powerup()") >= 0, "AdManager.show_rewarded_for_powerup() missing")
	assert_true(text.find("func show_rewarded_continue()") >= 0, "AdManager.show_rewarded_continue() missing")
