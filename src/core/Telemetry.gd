extends Node

const MAX_BUFFER := 200

var _session_id: String = ""
var _session_started_unix: int = 0
var _first_run_started_unix: int = 0
var _events: Array[Dictionary] = []

func _ready() -> void:
	_session_started_unix = Time.get_unix_time_from_system()
	_session_id = _build_session_id()
	track("session_start", {
		"session_id": _session_id,
		"is_authenticated": NakamaService.get_is_authenticated(),
	}, false)

func track(name: String, properties: Dictionary = {}, requires_auth: bool = true) -> void:
	var event_name := name.strip_edges().to_lower()
	if event_name.is_empty():
		return
	var payload := {
		"name": event_name,
		"event_time": Time.get_unix_time_from_system(),
		"session_id": _session_id,
		"properties": properties.duplicate(true),
	}
	_events.append(payload)
	if _events.size() > MAX_BUFFER:
		_events.pop_front()
	if Log and Log.has_method("d"):
		Log.d("telemetry.%s" % event_name, properties)
	if NakamaService and NakamaService.has_method("track_client_event"):
		NakamaService.track_client_event(event_name, properties, requires_auth)

func mark_mode_selected(mode_id: String, source: String = "ui") -> void:
	track("mode_selected", {
		"mode": mode_id.strip_edges().to_upper(),
		"source": source,
	}, false)

func mark_run_start(mode_id: String, is_daily_challenge: bool = false) -> void:
	if _first_run_started_unix <= 0:
		_first_run_started_unix = Time.get_unix_time_from_system()
		var seconds_to_gameplay: int = max(0, _first_run_started_unix - _session_started_unix)
		SaveStore.record_first_run_seconds(seconds_to_gameplay)
		track("first_run_timing", {"seconds_to_gameplay": seconds_to_gameplay}, false)
	track("run_start", {
		"mode": mode_id.strip_edges().to_upper(),
		"is_daily_challenge": is_daily_challenge,
	}, true)

func mark_run_end(
	score: int,
	mode_id: String,
	powerups_used: int,
	run_duration_ms: int,
	completed_by_gameplay: bool
) -> void:
	SaveStore.record_run_duration_ms(run_duration_ms)
	track("run_end", {
		"score": max(0, score),
		"mode": mode_id.strip_edges().to_upper(),
		"powerups_used": max(0, powerups_used),
		"run_duration_ms": max(0, run_duration_ms),
		"completed_by_gameplay": completed_by_gameplay,
	}, true)

func mark_powerup_used(powerup_type: String, mode_id: String, remaining: int) -> void:
	track("powerup_used", {
		"powerup_type": powerup_type.strip_edges().to_lower(),
		"mode": mode_id.strip_edges().to_upper(),
		"remaining": max(0, remaining),
	}, true)

func mark_scene_loaded(scene_name: String, load_started_msec: int) -> void:
	var elapsed := Time.get_ticks_msec() - load_started_msec
	track("scene_load", {
		"scene": scene_name,
		"elapsed_ms": max(0, elapsed),
	}, false)

func get_kpi_snapshot() -> Dictionary:
	return {
		"session_length_sec": max(0, Time.get_unix_time_from_system() - _session_started_unix),
		"avg_run_duration_sec": SaveStore.get_average_run_duration_seconds(),
		"avg_first_run_seconds": SaveStore.get_average_first_run_seconds(),
	}

func _build_session_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var raw := "%s:%s:%s" % [
		SaveStore.get_or_create_nakama_device_id(),
		Time.get_unix_time_from_system(),
		rng.randi(),
	]
	return raw.sha256_text().substr(0, 24)
