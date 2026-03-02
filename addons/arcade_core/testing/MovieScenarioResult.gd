extends RefCounted
class_name MovieScenarioResult

const REQUIRED_KEYS := [
	"actions_total",
	"score_final",
	"runs_started",
	"runs_finished",
]


static func make_base(context: Dictionary) -> Dictionary:
	return {
		"game_id": str(context.get("game_id", "")),
		"scenario_id": str(context.get("scenario_id", "")),
		"seed": int(context.get("seed", 0)),
		"frames_run": 0,
		"actions_total": 0,
		"score_final": 0,
		"runs_started": 0,
		"runs_finished": 0,
		"invariants_passed": false,
		"checkpoint_passed_count": 0,
		"checkpoint_failed_count": 0,
		"status": "failed",
		"errors": [],
	}


static func apply_metrics(result: Dictionary, metrics: Dictionary) -> void:
	for key in metrics.keys():
		result[key] = metrics[key]
	for key in REQUIRED_KEYS:
		if not result.has(key):
			result[key] = 0


static func add_error(result: Dictionary, message: String) -> void:
	if not result.has("errors") or typeof(result["errors"]) != TYPE_ARRAY:
		result["errors"] = []
	var errors: Array = result["errors"]
	errors.append(message)
	result["errors"] = errors


static func finalize(result: Dictionary) -> void:
	var errors: Array = result.get("errors", [])
	if errors.is_empty() and bool(result.get("invariants_passed", false)):
		result["status"] = "ok"
	else:
		result["status"] = "failed"
