extends Node

const BOOT_SCENE := "res://src/scenes/Boot.tscn"
const MENU_SCENE := "res://src/scenes/MainMenu.tscn"
const GAME_SCENE := "res://src/scenes/Game.tscn"
const RESULTS_SCENE := "res://src/scenes/Results.tscn"

const WEEKLY_TIER_POINTS := [0, 1200, 3200, 6200, 9800, 14500]
const RIVAL_NAME_POOL := [
	"Nova-17",
	"PulseFox",
	"LumaByte",
	"ShiftRay",
	"ArcDash",
	"VantaLoop",
	"PrismAce",
	"NightWire",
]

var last_score := 0
var last_run_completed_by_gameplay := true
var last_run_id := ""
var last_run_powerups_used: int = 0
var last_run_coins_spent: int = 0
var last_run_leaderboard_mode: String = "PURE"
var last_run_selected_mode: String = "PURE"
var last_run_daily_challenge: bool = false
var last_run_powerup_breakdown: Dictionary = {}
var last_run_duration_ms: int = 0
var last_weekly_snapshot: Dictionary = {}
var last_rival_snapshot: Dictionary = {}
var _run_started_at_unix: int = 0
var _pending_daily_seed: int = -1

func goto_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func start_game() -> void:
	last_run_selected_mode = SaveStore.get_preferred_mode()
	last_run_daily_challenge = SaveStore.get_daily_challenge_enabled()
	last_run_powerups_used = 0
	last_run_coins_spent = 0
	last_run_leaderboard_mode = last_run_selected_mode
	last_run_powerup_breakdown = {}
	last_run_duration_ms = 0
	_run_started_at_unix = Time.get_unix_time_from_system()
	_pending_daily_seed = _daily_seed_for_today() if last_run_daily_challenge else -1
	if Telemetry and Telemetry.has_method("mark_run_start"):
		Telemetry.mark_run_start(last_run_selected_mode, last_run_daily_challenge)
	get_tree().change_scene_to_file(GAME_SCENE)

func set_run_leaderboard_context(powerups_used: int, coins_spent: int = 0, powerup_breakdown: Dictionary = {}) -> void:
	last_run_powerups_used = max(0, powerups_used)
	last_run_coins_spent = max(0, coins_spent)
	last_run_leaderboard_mode = "OPEN" if (last_run_powerups_used > 0 or last_run_selected_mode == "OPEN") else "PURE"
	last_run_powerup_breakdown = powerup_breakdown.duplicate(true)

func end_game(score: int, completed_by_gameplay: bool = true) -> void:
	last_score = score
	last_run_completed_by_gameplay = completed_by_gameplay
	last_run_id = "cc-run-%d_%d" % [Time.get_unix_time_from_system(), randi()]
	var started_at := _run_started_at_unix
	if started_at <= 0:
		started_at = Time.get_unix_time_from_system()
	last_run_duration_ms = int(max(0, (Time.get_unix_time_from_system() - started_at) * 1000))
	if Telemetry and Telemetry.has_method("mark_run_end"):
		Telemetry.mark_run_end(
			score,
			last_run_leaderboard_mode,
			last_run_powerups_used,
			last_run_duration_ms,
			completed_by_gameplay
		)
	SaveStore.set_high_score(score)
	_update_social_loop(score)
	StreakManager.record_game_play()
	AdManager.on_game_finished()
	_update_unlock_progress()
	get_tree().change_scene_to_file(RESULTS_SCENE)

func set_selected_mode(mode_id: String, source: String = "ui") -> void:
	var mode := mode_id.strip_edges().to_upper()
	if mode != "OPEN":
		mode = "PURE"
	SaveStore.set_preferred_mode(mode)
	last_run_selected_mode = mode
	if Telemetry and Telemetry.has_method("mark_mode_selected"):
		Telemetry.mark_mode_selected(mode, source)

func get_selected_mode() -> String:
	return SaveStore.get_preferred_mode()

func set_daily_challenge_enabled(enabled: bool) -> void:
	SaveStore.set_daily_challenge_enabled(enabled)

func consume_pending_daily_seed() -> int:
	var seed := _pending_daily_seed
	_pending_daily_seed = -1
	return seed

func _daily_seed_for_today() -> int:
	var now_dict := Time.get_datetime_dict_from_system()
	return int(now_dict["year"]) * 10000 + int(now_dict["month"]) * 100 + int(now_dict["day"])

func _update_unlock_progress() -> void:
	var games_played: int = max(0, int(SaveStore.data.get("games_played", 0)))
	var progress: float = clamp(float(games_played) / 40.0, 0.0, 1.0)
	SaveStore.set_unlock_progress(progress)

func get_weekly_snapshot() -> Dictionary:
	return last_weekly_snapshot.duplicate(true)

func get_rival_snapshot() -> Dictionary:
	return last_rival_snapshot.duplicate(true)

func get_active_rival_target() -> int:
	_refresh_social_week_if_needed()
	return int(SaveStore.data.get("social_rival_target", _baseline_rival_target()))

func _update_social_loop(score: int) -> void:
	_refresh_social_week_if_needed()

	var week_points_before: int = int(SaveStore.data.get("social_week_points", 0))
	var week_best_before: int = int(SaveStore.data.get("social_week_best", 0))
	var rival_target_before: int = int(SaveStore.data.get("social_rival_target", _baseline_rival_target()))
	var rival_name: String = str(SaveStore.data.get("social_rival_name", "Nova-17"))

	var points_gained: int = max(0, score)
	points_gained += max(0, StreakManager.get_streak_days() * 12)
	if last_run_selected_mode == "PURE":
		points_gained += int(round(float(score) * 0.15))
	var week_points_after: int = week_points_before + points_gained
	var week_best_after: int = max(week_best_before, score)

	var rival_cleared: bool = score >= rival_target_before
	var rival_target_after: int = rival_target_before
	if rival_cleared:
		week_points_after += 320
		rival_target_after = max(_round_up_step(score + 280, 50), rival_target_before + 200)

	var tier_before: int = _weekly_tier_for_points(week_points_before)
	var tier_after: int = _weekly_tier_for_points(week_points_after)
	var next_tier_points: int = _next_weekly_tier_points(tier_after)

	SaveStore.data["social_week_points"] = week_points_after
	SaveStore.data["social_week_best"] = week_best_after
	SaveStore.data["social_week_tier"] = tier_after
	SaveStore.data["social_rival_target"] = rival_target_after
	SaveStore.data["social_rival_name"] = rival_name
	SaveStore.save()

	last_weekly_snapshot = {
		"week_key": str(SaveStore.data.get("social_week_key", _week_key())),
		"points_before": week_points_before,
		"points_after": week_points_after,
		"points_gained": points_gained,
		"tier_before": tier_before,
		"tier_after": tier_after,
		"next_tier_points": next_tier_points,
		"to_next_tier": max(0, next_tier_points - week_points_after),
		"week_best": week_best_after,
	}
	last_rival_snapshot = {
		"name": rival_name,
		"target_before": rival_target_before,
		"target_after": rival_target_after,
		"delta_after": max(0, rival_target_after - score),
		"cleared": rival_cleared,
	}

func _refresh_social_week_if_needed() -> void:
	var week_key: String = _week_key()
	var stored_week_key: String = str(SaveStore.data.get("social_week_key", ""))
	if stored_week_key == week_key:
		if int(SaveStore.data.get("social_rival_target", 0)) <= 0:
			SaveStore.data["social_rival_target"] = _baseline_rival_target()
		if str(SaveStore.data.get("social_rival_name", "")).is_empty():
			SaveStore.data["social_rival_name"] = _rival_name_for_week(week_key)
		return

	var carried_best: int = max(
		int(SaveStore.data.get("high_score", 0)),
		int(SaveStore.data.get("social_week_best", 0))
	)
	SaveStore.data["social_week_key"] = week_key
	SaveStore.data["social_week_points"] = 0
	SaveStore.data["social_week_tier"] = 0
	SaveStore.data["social_week_best"] = 0
	SaveStore.data["social_rival_name"] = _rival_name_for_week(week_key)
	SaveStore.data["social_rival_target"] = _baseline_rival_target(carried_best)
	SaveStore.save()

func _week_key() -> String:
	var date: Dictionary = Time.get_date_dict_from_system()
	var year: int = int(date.get("year", 1970))
	var month: int = int(date.get("month", 1))
	var day: int = int(date.get("day", 1))
	var week: int = int(ceil(float(day + (month - 1) * 30) / 7.0))
	week = clampi(week, 1, 53)
	return "%04d-W%02d" % [year, week]

func _rival_name_for_week(week_key: String) -> String:
	var hash_source: int = abs(week_key.hash())
	var index: int = hash_source % RIVAL_NAME_POOL.size()
	return RIVAL_NAME_POOL[index]

func _baseline_rival_target(seed_score: int = -1) -> int:
	var source_score: int = seed_score
	if source_score < 0:
		source_score = max(
			int(SaveStore.data.get("high_score", 0)),
			int(SaveStore.data.get("social_week_best", 0))
		)
	return max(450, _round_up_step(source_score + 220, 50))

func _weekly_tier_for_points(points: int) -> int:
	var out: int = 0
	for i in range(WEEKLY_TIER_POINTS.size()):
		if points >= int(WEEKLY_TIER_POINTS[i]):
			out = i
	return out

func _next_weekly_tier_points(tier: int) -> int:
	var next_index: int = clampi(tier + 1, 0, WEEKLY_TIER_POINTS.size() - 1)
	return int(WEEKLY_TIER_POINTS[next_index])

func _round_up_step(value: int, step: int) -> int:
	var safe_step: int = maxi(step, 1)
	return int(ceil(float(max(value, 1)) / float(safe_step))) * safe_step
