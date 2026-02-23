extends Node

var _stack: Array[Node] = []

func open_scene(scene: PackedScene, parent: Node, config: Dictionary = {}) -> Node:
	if scene == null or parent == null:
		return null
	var modal := scene.instantiate()
	parent.add_child(modal)
	_register_modal(modal)
	if modal and modal.has_method("configure") and not config.is_empty():
		modal.call("configure", config)
	return modal

func open_path(scene_path: String, parent: Node, config: Dictionary = {}) -> Node:
	if scene_path.strip_edges().is_empty():
		return null
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return null
	return open_scene(scene, parent, config)

func close_top() -> void:
	if _stack.is_empty():
		return
	var modal: Node = _stack.pop_back() as Node
	if is_instance_valid(modal):
		modal.queue_free()

func close_all() -> void:
	while not _stack.is_empty():
		close_top()

func get_open_count() -> int:
	return _stack.size()

func _register_modal(modal: Node) -> void:
	if modal == null:
		return
	_stack.append(modal)
	modal.tree_exited.connect(func() -> void:
		_stack.erase(modal)
	)
