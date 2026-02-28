extends "res://tests/framework/TestCase.gd"

func test_fx_exposes_game_feel_helpers() -> void:
	var fx_script: Script = load("res://addons/arcade_core/Fx.gd")
	assert_true(fx_script != null, "Fx script failed to load")
	if fx_script == null:
		return

	var fx: Node = fx_script.new()
	assert_true(fx.has_method("impact"), "Fx.impact() helper missing")
	assert_true(fx.has_method("punch"), "Fx.punch() helper missing")
	assert_true(fx.has_method("flash"), "Fx.flash() helper missing")
	fx.free()

func test_fx_helpers_are_safe_off_tree() -> void:
	var fx_script: Script = load("res://addons/arcade_core/Fx.gd")
	assert_true(fx_script != null, "Fx script failed to load")
	if fx_script == null:
		return
	var fx: Node = fx_script.new()

	var control := Control.new()
	control.scale = Vector2(1.2, 1.2)
	control.modulate = Color(0.8, 0.9, 1.0, 1.0)

	fx.call("punch", control, 0.10, 0.05, 0.10)
	assert_equal(control.scale, Vector2(1.2, 1.2), "Fx.punch() should no-op for nodes outside the tree")

	fx.call("flash", control, Color(1.0, 1.0, 1.0, 0.35), 0.12)
	assert_equal(control.modulate, Color(0.8, 0.9, 1.0, 1.0), "Fx.flash() should no-op for nodes outside the tree")

	control.free()
	fx.free()
