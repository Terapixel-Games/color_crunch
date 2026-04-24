extends SceneTree

const FRAMEWORK_CASE := "res://tests/framework/TestCase.gd"
var _registered_singletons: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var suite: String = _suite_from_args()
	var root_dir := "res://tests/%s" % suite
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_dir)):
		printerr("[TestRunner] Missing test directory: %s" % root_dir)
		quit(2)
		return

	_register_project_autoloads()

	var scripts: Array[String] = []
	_collect_test_scripts(root_dir, scripts)
	scripts.sort()
	var path_filter := _filter_from_args()
	if not path_filter.is_empty():
		scripts = scripts.filter(func(path: String) -> bool:
			return path.contains(path_filter)
		)

	var total_methods := 0
	var total_failures := 0
	for path in scripts:
		var result: Dictionary = _run_script(path)
		total_methods += int(result.get("methods", 0))
		total_failures += int(result.get("failures", 0))

	print("[TestRunner] suite=%s files=%d tests=%d failures=%d" % [suite, scripts.size(), total_methods, total_failures])
	_dispose_gdunit_runtime()
	_unregister_project_autoloads()
	quit(1 if total_failures > 0 else 0)

func _suite_from_args() -> String:
	var suite := "unit"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			var value := arg.trim_prefix("--suite=").strip_edges().to_lower()
			if value in ["unit", "uat"]:
				suite = value
	return suite

func _filter_from_args() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			return arg.trim_prefix("--filter=").strip_edges()
	return ""

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
	if instance is Node:
		root.add_child(instance as Node)
	if instance.has_method("set_scene_tree"):
		instance.call("set_scene_tree", self)

	var method_names: Array[String] = []
	for method_info in instance.get_method_list():
		var method_name := str(method_info.get("name", ""))
		if method_name.begins_with("test_"):
			method_names.append(method_name)
	method_names.sort()

	var failures := 0
	if instance.has_method("before"):
		instance.call("before")
	for method_name in method_names:
		if instance.has_method("set_active_test_case"):
			instance.call("set_active_test_case", method_name)
		var gdunit_context: Object = _create_gdunit_context("%s::%s" % [path, method_name], instance)
		_set_gdunit_context(gdunit_context)
		if instance.has_method("before_test"):
			instance.call("before_test")
		instance.call(method_name)
		if instance.has_method("after_test"):
			instance.call("after_test")
		failures += _count_gdunit_failures(path, method_name, gdunit_context)
		_clear_gdunit_assert_state()
		if gdunit_context != null:
			gdunit_context.set("test_suite", null)
			if gdunit_context.has_method("dispose"):
				gdunit_context.call("dispose")
		_set_gdunit_context(null)
		if instance.has_method("get_failures"):
			var test_failures: Variant = instance.call("get_failures")
			if test_failures is Array and not (test_failures as Array).is_empty():
				for f in test_failures:
					printerr("[FAIL] %s :: %s :: %s" % [path, method_name, str(f)])
				failures += (test_failures as Array).size()
				if instance.has_method("clear_failures"):
					instance.call("clear_failures")
	if instance.has_method("after"):
		instance.call("after")

	if instance is Node:
		_free_node_now(instance as Node)
	return {"methods": method_names.size(), "failures": failures}

func _create_gdunit_context(test_name: String, suite: Object) -> Object:
	var context_script_path := "res://addons/gdUnit4/src/core/execution/GdUnitExecutionContext.gd"
	if not FileAccess.file_exists(ProjectSettings.globalize_path(context_script_path)):
		return null
	var context_script: Script = load(context_script_path)
	if context_script == null:
		return null
	var context: Object = context_script.new(test_name)
	if context != null:
		context.set("test_suite", suite)
	return context

func _set_gdunit_context(context: Object) -> void:
	var thread_context: Object = _gdunit_thread_context()
	if thread_context != null and thread_context.has_method("set_execution_context"):
		thread_context.call("set_execution_context", context)

func _clear_gdunit_assert_state() -> void:
	var thread_context: Object = _gdunit_thread_context()
	if thread_context != null and thread_context.has_method("clear_assert"):
		thread_context.call("clear_assert")

func _gdunit_thread_context() -> Object:
	var thread_manager_path := "res://addons/gdUnit4/src/core/thread/GdUnitThreadManager.gd"
	if not FileAccess.file_exists(ProjectSettings.globalize_path(thread_manager_path)):
		return null
	var thread_manager_script: Script = load(thread_manager_path)
	if thread_manager_script == null:
		return null
	return thread_manager_script.get_current_context()

func _count_gdunit_failures(path: String, method_name: String, context: Object) -> int:
	if context == null or not context.has_method("collect_reports"):
		return 0
	var reports: Variant = context.call("collect_reports", true)
	if not (reports is Array):
		return 0
	var failures := 0
	for report in reports as Array:
		if not (report is Object):
			continue
		var report_object := report as Object
		var failed := bool(report_object.call("is_failure")) if report_object.has_method("is_failure") else false
		var errored := bool(report_object.call("is_error")) if report_object.has_method("is_error") else false
		var orphaned := bool(report_object.call("is_orphan")) if report_object.has_method("is_orphan") else false
		if failed or errored or orphaned:
			var message := str(report_object.call("message")) if report_object.has_method("message") else str(report_object)
			printerr("[FAIL] %s :: %s :: %s" % [path, method_name, message])
			failures += 1
	return failures

func _dispose_gdunit_runtime() -> void:
	var tools_path := "res://addons/gdUnit4/src/core/GdUnitTools.gd"
	if not FileAccess.file_exists(ProjectSettings.globalize_path(tools_path)):
		return
	var tools_script: Script = load(tools_path)
	if tools_script == null or not tools_script.has_method("dispose_all"):
		return
	tools_script.call("dispose_all")

func _register_project_autoloads() -> void:
	for entry in _autoload_entries_from_project_file():
		var singleton_name: String = str(entry.get("name", ""))
		if Engine.has_singleton(singleton_name):
			continue
		if root.get_node_or_null(singleton_name) != null:
			continue
		var resource_path: String = str(entry.get("path", ""))
		var resource: Resource = load(resource_path)
		var instance: Object = null
		if resource is PackedScene:
			instance = (resource as PackedScene).instantiate()
		elif resource is Script:
			instance = (resource as Script).new()
		if instance == null:
			printerr("[TestRunner] Failed to instantiate autoload %s from %s" % [singleton_name, resource_path])
			continue
		if instance is Node:
			var node: Node = instance as Node
			node.name = singleton_name
			root.add_child(node)
		Engine.register_singleton(singleton_name, instance)
		_registered_singletons.append(singleton_name)

func _unregister_project_autoloads() -> void:
	for singleton_name in _registered_singletons:
		if Engine.has_singleton(singleton_name):
			var singleton: Object = Engine.get_singleton(singleton_name)
			Engine.unregister_singleton(singleton_name)
			if singleton is Node:
				_free_node_now(singleton as Node)
	_registered_singletons.clear()

func _free_node_now(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()

func _autoload_entries_from_project_file() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var project_path: String = ProjectSettings.globalize_path("res://project.godot")
	if not FileAccess.file_exists(project_path):
		return entries
	var file: FileAccess = FileAccess.open(project_path, FileAccess.READ)
	if file == null:
		return entries
	var in_autoload_section := false
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with(";"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			in_autoload_section = line == "[autoload]"
			continue
		if not in_autoload_section or not line.contains("="):
			continue
		var split_index: int = line.find("=")
		var singleton_name: String = line.substr(0, split_index).strip_edges()
		var resource_path: String = line.substr(split_index + 1).strip_edges().trim_prefix("\"").trim_suffix("\"").trim_prefix("*")
		if not singleton_name.is_empty() and not resource_path.is_empty():
			entries.append({
				"name": singleton_name,
				"path": resource_path,
			})
	return entries
