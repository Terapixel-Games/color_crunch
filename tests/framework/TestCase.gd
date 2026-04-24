extends Node

var scene_tree: SceneTree = null
var _failures: Array[String] = []

func fail(message: String) -> void:
	_failures.append(message)

func assert_true(condition: bool, message: String) -> void:
	if not condition:
		fail(message)

func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		fail("%s | expected=%s actual=%s" % [message, str(expected), str(actual)])

func get_failures() -> Array[String]:
	return _failures.duplicate()

func clear_failures() -> void:
	_failures.clear()

func set_scene_tree(tree: SceneTree) -> void:
	scene_tree = tree
