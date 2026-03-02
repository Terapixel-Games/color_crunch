extends RefCounted
class_name ActorPersona

const PRESETS := {
	"calm": {
		"id": "calm",
		"gameplay_action_interval_frames": 10,
		"action_interval_frames": 10,
		"menu_action_interval_frames": 24,
		"menu_settle_frames": 20,
		"results_hold_frames": 180,
		"restart_interval_frames": 720,
		"powerup_interval_frames": 360,
		"draw_bias": 0.35,
	},
	"balanced": {
		"id": "balanced",
		"gameplay_action_interval_frames": 6,
		"action_interval_frames": 6,
		"menu_action_interval_frames": 12,
		"menu_settle_frames": 10,
		"results_hold_frames": 90,
		"restart_interval_frames": 480,
		"powerup_interval_frames": 240,
		"draw_bias": 0.20,
	},
	"manic": {
		"id": "manic",
		"gameplay_action_interval_frames": 2,
		"action_interval_frames": 2,
		"menu_action_interval_frames": 5,
		"menu_settle_frames": 3,
		"results_hold_frames": 24,
		"restart_interval_frames": 240,
		"powerup_interval_frames": 120,
		"draw_bias": 0.08,
	},
}


static func resolve(persona_id: String, overrides: Dictionary = {}) -> Dictionary:
	var normalized: String = persona_id.strip_edges().to_lower()
	if not PRESETS.has(normalized):
		normalized = "balanced"
	var base: Dictionary = (PRESETS[normalized] as Dictionary).duplicate(true)
	for key in overrides.keys():
		base[key] = overrides[key]
	return base
