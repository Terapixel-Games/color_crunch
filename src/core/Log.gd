extends Node

const DEFAULT_ENABLED := false

var _enabled: bool = DEFAULT_ENABLED

func _ready() -> void:
	_enabled = _resolve_enabled()

func is_enabled() -> bool:
	return _enabled

func set_enabled(value: bool) -> void:
	_enabled = value

func d(message: String, context: Dictionary = {}) -> void:
	if not _enabled:
		return
	if context.is_empty():
		print("[ColorCrunch] %s" % message)
		return
	print("[ColorCrunch] %s | %s" % [message, JSON.stringify(context)])

func _resolve_enabled() -> bool:
	var from_env := OS.get_environment("COLOR_CRUNCH_DEBUG_LOGGING").strip_edges().to_lower()
	if from_env in ["1", "true", "yes", "on"]:
		return true
	if from_env in ["0", "false", "no", "off"]:
		return false
	if ProjectSettings.has_setting("color_crunch/debug_logging_enabled"):
		return bool(ProjectSettings.get_setting("color_crunch/debug_logging_enabled"))
	return DEFAULT_ENABLED
