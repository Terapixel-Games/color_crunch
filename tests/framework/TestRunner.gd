extends SceneTree

const FRAMEWORK_CASE := "res://tests/framework/TestCase.gd"

func _init() -> void:
	var suite: String = _suite_from_args()
	var root_dir := "res://tests/%s" % suite
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_dir)):
		printerr("[TestRunner] Missing test directory: %s" % root_dir)
		quit(2)
		return

	var scripts: Array[String] = []
	_collect_test_scripts(root_dir, scripts)
	scripts.sort()

	var total_methods := 0
	var total_failures := 0
	for path in scripts:
		var result: Dictionary = _run_script(path)
		total_methods += int(result.get("methods", 0))
		total_failures += int(result.get("failures", 0))

	print("[TestRunner] suite=%s files=%d tests=%d failures=%d" % [suite, scripts.size(), total_methods, total_failures])
	quit(1 if total_failures > 0 else 0)

func _suite_from_args() -> String:
	var suite := "unit"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			var value := arg.trim_prefix("--suite=").strip_edges().to_lower()
			if value in ["unit", "uat"]:
				suite = value
	return suite

func _collect_test_scripts(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var child := "%s/%s" % [dir_path, name]
		if dir.current_is_dir():
			_collect_test_scripts(child, out)
		elif name.ends_with(".gd"):
			out.append(child)
	dir.list_dir_end()

func _run_script(path: String) -> Dictionary:
	var script: Script = load(path)
	if script == null:
		printerr("[TestRunner] Failed to load %s" % path)
		return {"methods": 0, "failures": 1}
	if script is GDScript and not (script as GDScript).can_instantiate():
		printerr("[TestRunner] Script failed to compile: %s" % path)
		return {"methods": 0, "failures": 1}

	var instance: Object = script.new()
	if instance == null:
		printerr("[TestRunner] Failed to instantiate %s" % path)
		return {"methods": 0, "failures": 1}
	if instance.has_method("set_scene_tree"):
		instance.call("set_scene_tree", self)

	var method_names: Array[String] = []
	for method_info in instance.get_method_list():
		var method_name := str(method_info.get("name", ""))
		if method_name.begins_with("test_"):
			method_names.append(method_name)
	method_names.sort()

	var failures := 0
	for method_name in method_names:
		instance.call(method_name)
		if instance.has_method("get_failures"):
			var test_failures: Variant = instance.call("get_failures")
			if test_failures is Array and not (test_failures as Array).is_empty():
				for f in test_failures:
					printerr("[FAIL] %s :: %s :: %s" % [path, method_name, str(f)])
				failures += (test_failures as Array).size()
				if instance.has_method("clear_failures"):
					instance.call("clear_failures")

	return {"methods": method_names.size(), "failures": failures}
