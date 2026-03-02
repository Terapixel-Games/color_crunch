extends "res://tests/framework/TestCase.gd"


func test_scenario_driver_merge_growth_uat_mode() -> void:
	var run: Dictionary = _run_driver("cc_merge_growth", 900, 7711, "balanced")
	assert_equal(run.get("code", -1), 0, "merge growth scenario driver should succeed")


func test_scenario_driver_stall_recovery_uat_mode() -> void:
	var run: Dictionary = _run_driver("cc_stall_recovery", 1200, 7712, "manic")
	assert_equal(run.get("code", -1), 0, "stall recovery scenario driver should succeed")


func _run_driver(scenario_id: String, frames: int, seed: int, persona: String) -> Dictionary:
	var exe_path: String = OS.get_executable_path()
	var project_path: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var args := PackedStringArray([
		"--headless",
		"--path", project_path,
		"--script", "res://tools/capture/ScenarioDriver.gd",
		"--",
		"--mode=uat",
		"--strictness=hybrid",
		"--persona=%s" % persona,
		"--scenario_id=%s" % scenario_id,
		"--frames=%d" % frames,
		"--seed=%d" % seed,
	])
	var code: int = OS.execute(exe_path, args, output, true)
	if code != 0:
		fail("driver output: %s" % "\n".join(output))
	return {"code": code, "output": output}