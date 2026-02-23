extends Node

func submit_run(
	score: int,
	metadata: Dictionary,
	mode_id: String,
	powerups_used: int,
	coins_spent: int,
	run_id: String,
	run_duration_ms: int
) -> Dictionary:
	var normalized_mode := mode_id.strip_edges().to_upper()
	if normalized_mode.is_empty():
		normalized_mode = "PURE"
	return await NakamaService.submit_score(
		score,
		metadata,
		normalized_mode,
		powerups_used,
		coins_spent,
		run_id,
		run_duration_ms
	)

func refresh_mode(mode_id: String, limit: int = 5) -> Dictionary:
	var normalized_mode := mode_id.strip_edges().to_upper()
	if normalized_mode.is_empty():
		normalized_mode = "PURE"
	var high_score_result: Dictionary = await NakamaService.refresh_my_high_score(normalized_mode)
	var leaderboard_result: Dictionary = await NakamaService.refresh_leaderboard(limit, normalized_mode)
	return {
		"ok": bool(high_score_result.get("ok", false)) and bool(leaderboard_result.get("ok", false)),
		"high_score": high_score_result,
		"leaderboard": leaderboard_result,
	}

func submit_and_refresh(
	score: int,
	metadata: Dictionary,
	mode_id: String,
	powerups_used: int,
	coins_spent: int,
	run_id: String,
	run_duration_ms: int,
	limit: int = 5
) -> Dictionary:
	var submit_result: Dictionary = await submit_run(
		score,
		metadata,
		mode_id,
		powerups_used,
		coins_spent,
		run_id,
		run_duration_ms
	)
	if not submit_result.get("ok", false):
		return {
			"ok": false,
			"submit": submit_result,
			"refresh": {},
		}
	var refresh_result: Dictionary = await refresh_mode(mode_id, limit)
	return {
		"ok": bool(refresh_result.get("ok", false)),
		"submit": submit_result,
		"refresh": refresh_result,
	}
