extends RefCounted
class_name MovieScenarioRunner

const RESULT_SCRIPT := preload("res://addons/arcade_core/testing/MovieScenarioResult.gd")


func run(scene_tree: SceneTree, scenario: Object, context: Dictionary) -> Dictionary:
	var ctx: Dictionary = context.duplicate(true)
	var result: Dictionary = RESULT_SCRIPT.make_base(ctx)
	var frames_requested: int = maxi(1, int(ctx.get("frames", 1800)))
	var fps: float = maxf(1.0, float(ctx.get("fps", 60.0)))
	var strictness: String = str(ctx.get("strictness", "hybrid")).strip_edges().to_lower()

	ctx["frames_requested"] = frames_requested
	ctx["fps"] = fps
	if scenario == null or not scenario.has_method("setup"):
		RESULT_SCRIPT.add_error(result, "scenario instance is invalid or missing setup()")
		RESULT_SCRIPT.finalize(result)
		return result
	scenario.call("setup", ctx)

	var frames_run := 0
	while frames_run < frames_requested:
		scenario.call("step", frames_run, 1.0 / fps)
		frames_run += 1
		await scene_tree.process_frame
		if scenario.has_method("is_complete") and bool(scenario.call("is_complete")):
			break

	result["frames_run"] = frames_run
	var raw_metrics: Variant = scenario.call("collect_metrics")
	var metrics: Dictionary = {}
	if typeof(raw_metrics) == TYPE_DICTIONARY:
		metrics = (raw_metrics as Dictionary).duplicate(true)
	metrics["frames_run"] = frames_run
	RESULT_SCRIPT.apply_metrics(result, metrics)

	var raw_invariants: Variant = scenario.call("get_invariants")
	var invariants: Array[Dictionary] = []
	if typeof(raw_invariants) == TYPE_ARRAY:
		invariants = raw_invariants
	var invariant_eval: Dictionary = _evaluate_rules(invariants, metrics)
	result["invariants_passed"] = int(invariant_eval.get("failed_count", 0)) == 0
	for line in invariant_eval.get("messages", []):
		RESULT_SCRIPT.add_error(result, str(line))

	var checkpoint_eval := {
		"passed_count": 0,
		"failed_count": 0,
		"messages": [],
	}
	var checkpoints: Array[Dictionary] = []
	var raw_checkpoints: Variant = scenario.call("get_checkpoints")
	if typeof(raw_checkpoints) == TYPE_ARRAY:
		checkpoints = raw_checkpoints
	if strictness != "invariants":
		checkpoint_eval = _evaluate_rules(checkpoints, metrics)
		result["checkpoint_passed_count"] = int(checkpoint_eval.get("passed_count", 0))
		result["checkpoint_failed_count"] = int(checkpoint_eval.get("failed_count", 0))
		for line in checkpoint_eval.get("messages", []):
			RESULT_SCRIPT.add_error(result, str(line))
	if strictness == "deterministic" and checkpoints.is_empty():
		RESULT_SCRIPT.add_error(
			result,
			"deterministic strictness requires scenario checkpoints, but none were provided"
		)

	RESULT_SCRIPT.finalize(result)
	return result


func _evaluate_rules(rules: Array[Dictionary], metrics: Dictionary) -> Dictionary:
	var passed_count := 0
	var failed_count := 0
	var messages: Array[String] = []

	for index in range(rules.size()):
		var rule: Dictionary = rules[index]
		var rule_id: String = str(rule.get("id", "rule_%d" % index))
		var ok := false
		var detail: String = ""

		if rule.has("ok"):
			ok = bool(rule.get("ok", false))
			detail = str(rule.get("message", "explicit rule failed"))
		elif rule.has("metric") and rule.has("op") and rule.has("value"):
			var metric_key: String = str(rule.get("metric", ""))
			var op: String = str(rule.get("op", "==")).strip_edges()
			var expected: Variant = rule.get("value")
			if not metrics.has(metric_key):
				ok = false
				detail = "missing metric '%s'" % metric_key
			else:
				var actual: Variant = metrics.get(metric_key)
				ok = _compare_values(actual, op, expected)
				if not ok:
					detail = "metric '%s' expected %s %s but got %s" % [
						metric_key,
						op,
						str(expected),
						str(actual),
					]
		else:
			ok = false
			detail = "rule is missing either 'ok' or ('metric','op','value')"

		if ok:
			passed_count += 1
		else:
			failed_count += 1
			if detail.is_empty():
				detail = str(rule.get("message", "rule failed"))
			messages.append("[%s] %s" % [rule_id, detail])

	return {
		"passed_count": passed_count,
		"failed_count": failed_count,
		"messages": messages,
	}


func _compare_values(actual: Variant, op: String, expected: Variant) -> bool:
	match op:
		"==":
			return actual == expected
		"!=":
			return actual != expected
		">", ">=", "<", "<=":
			if not _is_numeric(actual) or not _is_numeric(expected):
				return false
			var a: float = float(actual)
			var b: float = float(expected)
			match op:
				">":
					return a > b
				">=":
					return a >= b
				"<":
					return a < b
				"<=":
					return a <= b
		_:
			return false
	return false


func _is_numeric(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
