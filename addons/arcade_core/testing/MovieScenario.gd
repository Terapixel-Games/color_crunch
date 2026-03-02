extends RefCounted
class_name MovieScenario

var _context: Dictionary = {}


func setup(context: Dictionary) -> void:
	_context = context.duplicate(true)


func step(_frame: int, _delta: float) -> void:
	pass


func collect_metrics() -> Dictionary:
	return {}


func get_invariants() -> Array[Dictionary]:
	return []


func get_checkpoints() -> Array[Dictionary]:
	return []


func is_complete() -> bool:
	return false


func context() -> Dictionary:
	return _context.duplicate(true)


func actor_persona() -> Dictionary:
	var raw: Variant = _context.get("actor_persona", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return (raw as Dictionary).duplicate(true)
