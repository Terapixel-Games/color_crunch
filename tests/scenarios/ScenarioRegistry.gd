extends RefCounted

const MERGE_GROWTH = preload("res://tests/scenarios/cc_merge_growth.gd")
const STALL_RECOVERY = preload("res://tests/scenarios/cc_stall_recovery.gd")


func create(scenario_id: String):
	match scenario_id.strip_edges().to_lower():
		"cc_merge_growth":
			return MERGE_GROWTH.new()
		"cc_stall_recovery":
			return STALL_RECOVERY.new()
		_:
			return null


func list_ids() -> PackedStringArray:
	return PackedStringArray([
		"cc_merge_growth",
		"cc_stall_recovery",
	])


func default_id() -> String:
	return "cc_merge_growth"