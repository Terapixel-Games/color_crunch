extends SceneTree

const REGISTRY_SCRIPT = preload("res://tests/scenarios/ScenarioRegistry.gd")
const RUNNER_SCRIPT = preload("res://addons/arcade_core/testing/MovieScenarioRunner.gd")
const PERSONA_SCRIPT = preload("res://addons/arcade_core/testing/ActorPersona.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var options: Dictionary = _parse_options()
	var registry = REGISTRY_SCRIPT.new()
	var scenario_id: String = str(options.get("scenario_id", "")).strip_edges().to_lower()
	if scenario_id.is_empty():
		scenario_id = registry.default_id()
	var scenario = registry.create(scenario_id)
	if scenario == null:
		_fail_and_quit("unknown scenario_id: %s" % scenario_id, options)
		return

	_apply_runtime_settings()
	var main_scene_path: String = str(ProjectSettings.get_setting("application/run/main_scene", "")).strip_edges()
	if main_scene_path.is_empty():
		_fail_and_quit("application/run/main_scene is not configured", options)
		return
	var scene_err: Error = change_scene_to_file(main_scene_path)
	if scene_err != OK:
		_fail_and_quit("failed to load main scene: %s" % main_scene_path, options)
		return
	for _i in range(4):
		await process_frame

	var context := {
		"game_id": "color_crunch",
		"scenario_id": scenario_id,
		"seed": int(options.get("seed", 0)),
		"frames": int(options.get("frames", 1800)),
		"fps": float(options.get("fps", 60.0)),
		"strictness": str(options.get("strictness", "hybrid")),
		"actor_persona": PERSONA_SCRIPT.resolve(str(options.get("persona", "balanced"))),
		"mode": str(options.get("mode", "uat")),
		"scene_tree": self,
		"main_scene": current_scene,
	}

	var runner = RUNNER_SCRIPT.new()
	var result: Dictionary = await runner.run(self, scenario, context)
	result["actor_persona"] = str(context["actor_persona"].get("id", "balanced"))
	_write_metrics_if_requested(str(options.get("metrics_json", "")), result)
	print("[ScenarioDriver] %s" % JSON.stringify(result))
	quit(0 if str(result.get("status", "failed")) == "ok" else 1)


func _apply_runtime_settings() -> void:
	ProjectSettings.set_setting("color_crunch/nakama_enable_client", false)
	ProjectSettings.set_setting("color_crunch/use_mock_ads", true)


func _parse_options() -> Dictionary:
	var out := {
		"mode": "uat",
		"scenario_id": "",
		"seed": 0,
		"frames": 1800,
		"metrics_json": "",
		"strictness": "hybrid",
		"fps": 60.0,
		"persona": "balanced",
	}
	for raw_arg in OS.get_cmdline_user_args():
		var arg: String = str(raw_arg).strip_edges()
		if not arg.begins_with("--"):
			continue
		if not arg.contains("="):
			continue
		var split_index: int = arg.find("=")
		if split_index <= 2:
			continue
		var key: String = arg.substr(2, split_index - 2).strip_edges().to_lower()
		var value: String = arg.substr(split_index + 1).strip_edges()
		match key:
			"mode", "scenario_id", "metrics_json", "strictness", "persona":
				out[key] = value
			"seed", "frames":
				if value.is_valid_int():
					out[key] = int(value)
			"fps":
				if value.is_valid_float():
					out[key] = float(value)
	return out


func _write_metrics_if_requested(path: String, result: Dictionary) -> void:
	var target_path: String = path.strip_edges()
	target_path = target_path.trim_prefix("\"").trim_suffix("\"")
	target_path = target_path.replace("\\", "/")
	if target_path.is_empty():
		return
	if target_path.begins_with("res://") or target_path.begins_with("user://"):
		target_path = ProjectSettings.globalize_path(target_path)
	elif not target_path.is_absolute_path():
		target_path = ProjectSettings.globalize_path("user://%s" % target_path)
	var dir_path: String = target_path.get_base_dir()
	if not dir_path.is_empty():
		var mk_err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
		if mk_err != OK:
			printerr("[ScenarioDriver] metrics mkdir failed path=%s err=%d" % [dir_path, mk_err])
			return
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		printerr(
			"[ScenarioDriver] metrics open failed path=%s err=%d" % [
				target_path,
				FileAccess.get_open_error(),
			]
		)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.flush()


func _fail_and_quit(message: String, options: Dictionary) -> void:
	var result := {
		"game_id": "color_crunch",
		"scenario_id": str(options.get("scenario_id", "")),
		"seed": int(options.get("seed", 0)),
		"frames_run": 0,
		"actions_total": 0,
		"score_final": 0,
		"runs_started": 0,
		"runs_finished": 0,
		"invariants_passed": false,
		"checkpoint_passed_count": 0,
		"checkpoint_failed_count": 0,
		"status": "failed",
		"errors": [message],
	}
	_write_metrics_if_requested(str(options.get("metrics_json", "")), result)
	printerr("[ScenarioDriver] %s" % message)
	quit(1)
