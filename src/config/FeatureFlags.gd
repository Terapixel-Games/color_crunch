extends Node
class_name FeatureFlags

# Feature flags / config constants
enum TileBlurMode { LITE, HEAVY }
enum TileDesignMode { MODERN, LEGACY }

# Determinism toggles for UAT (override via ProjectSettings at runtime)
const VISUAL_TEST_MODE := false
const AUDIO_TEST_MODE := false

# Performance toggle for tiles
const TILE_BLUR_MODE := TileBlurMode.LITE
const TILE_DESIGN_MODE := TileDesignMode.MODERN
const MIN_MATCH_SIZE := 3

# Audio tuning (95 BPM stems)
const BPM := 95
const COMBO_PEAK_DB := -6.0
const COMBO_FLOOR_DB := -60.0
const COMBO_FADE_SECONDS := 1.25
const COMBO_DECAY_DELAY_SECONDS := 1.20
const COMBO_DECAY_SECONDS := 2.2
const COMBO_DECAY_TARGET_DB := COMBO_FLOOR_DB
const FX_COOLDOWN_SECONDS := 1.5
const GAMEPLAY_CALM_RETURN_DELAY_SECONDS := 1.6
const GAMEPLAY_CALM_FADE_SECONDS := 6.0
const MATCH_HINT_DELAY_SECONDS := 3.0
const GAMEPLAY_MATCHES_NORMALIZER := 12.0
const GAMEPLAY_MATCHES_MOOD_FADE_SECONDS := 0.6
const GAMEPLAY_MATCHES_MAX_CALM_WEIGHT := 0.45
const HINT_PULSE_SPEED_MULTIPLIER := 0.45
const AUDIO_TRACK_ID := "glassgrid"
const AUDIO_TRACK_MANIFEST_PATH := "res://src/audio/tracks.json"
const CLEAR_HIGH_SCORE_ON_BOOT := false
const AD_RETRY_ATTEMPTS := 2
const AD_RETRY_INTERVAL_SECONDS := 0.35
const AD_PRELOAD_POLL_SECONDS := 1.25
const STARFIELD_CALM_DENSITY := 1.9
const STARFIELD_HYPE_DENSITY := 2.8
const STARFIELD_CALM_SPEED := 1.0
const STARFIELD_HYPE_SPEED := 2.0
const STARFIELD_CALM_BRIGHTNESS := 1.42
const STARFIELD_HYPE_BRIGHTNESS := 1.35
const STARFIELD_BEAT_PULSE_DEPTH := 0.2
const STARFIELD_MATCH_PULSE_SECONDS := 0.2
const STARFIELD_MATCH_PULSE_DENSITY_MULT := 1.45
const STARFIELD_MATCH_PULSE_SPEED_MULT := 1.2
const STARFIELD_MATCH_PULSE_BRIGHTNESS_MULT := 1.25
const STARFIELD_HYPE_EMISSION_FLOOR := 0.35
const STARFIELD_CALM_EMISSION_FLOOR := 0.78
const STARFIELD_EMISSION_RAMP_UP_SECONDS := 0.14
const STARFIELD_CALM_POINT_COLOR := Color(0.26, 0.82, 1.0, 1.0)
const STARFIELD_CALM_STREAK_COLOR := Color(0.62, 0.94, 1.0, 1.0)
const STARFIELD_HYPE_POINT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const STARFIELD_HYPE_STREAK_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const STARFIELD_BOOST_POINT_COLOR := Color(1, 1, 1, 1)
const STARFIELD_BOOST_STREAK_COLOR := Color(1, 1, 1, 1)
const HAPTICS_ENABLED := true
const MATCH_CLICK_HAPTIC_DURATION_MS := 14
const MATCH_CLICK_HAPTIC_AMPLITUDE := 0.35
const MATCH_HAPTIC_DURATION_MS := 26
const MATCH_HAPTIC_AMPLITUDE := 0.5
const POWERUP_UNDO_CHARGES := 2
const POWERUP_REMOVE_COLOR_CHARGES := 1
const POWERUP_SHUFFLE_CHARGES := 1
const POWERUP_FLASH_ALPHA := 0.22
const POWERUP_FLASH_SECONDS := 0.24

# Screenshot/UAT
const GOLDEN_RESOLUTION := Vector2i(1170, 2532) # iPhone portrait

static func _setting(name: String, default_value: Variant) -> Variant:
	var color_key := "color_crunch/%s" % name
	if ProjectSettings.has_setting(color_key):
		return ProjectSettings.get_setting(color_key)
	var legacy_key := "lumarush/%s" % name
	if ProjectSettings.has_setting(legacy_key):
		return ProjectSettings.get_setting(legacy_key)
	return default_value

static func _setting_color(name: String, default_value: Color) -> Color:
	var value: Variant = _setting(name, default_value)
	return value if value is Color else default_value

static func is_visual_test_mode() -> bool:
	return bool(_setting("visual_test_mode", VISUAL_TEST_MODE))

static func is_audio_test_mode() -> bool:
	return bool(_setting("audio_test_mode", AUDIO_TEST_MODE))

static func tile_blur_mode() -> int:
	return int(_setting("tile_blur_mode", TILE_BLUR_MODE))

static func tile_design_mode() -> int:
	var value: int = int(_setting("tile_design_mode", TILE_DESIGN_MODE))
	return clamp(value, TileDesignMode.MODERN, TileDesignMode.LEGACY)

static func min_match_size() -> int:
	return max(2, int(_setting("min_match_size", MIN_MATCH_SIZE)))

static func combo_decay_delay_seconds() -> float:
	return float(_setting("combo_decay_delay_seconds", COMBO_DECAY_DELAY_SECONDS))

static func combo_decay_seconds() -> float:
	return float(_setting("combo_decay_seconds", COMBO_DECAY_SECONDS))

static func combo_decay_target_db() -> float:
	return float(_setting("combo_decay_target_db", COMBO_DECAY_TARGET_DB))

static func gameplay_calm_return_delay_seconds() -> float:
	return float(_setting("gameplay_calm_return_delay_seconds", GAMEPLAY_CALM_RETURN_DELAY_SECONDS))

static func gameplay_calm_fade_seconds() -> float:
	return float(_setting("gameplay_calm_fade_seconds", GAMEPLAY_CALM_FADE_SECONDS))

static func match_hint_delay_seconds() -> float:
	return float(_setting("match_hint_delay_seconds", MATCH_HINT_DELAY_SECONDS))

static func gameplay_matches_normalizer() -> float:
	return max(1.0, float(_setting("gameplay_matches_normalizer", GAMEPLAY_MATCHES_NORMALIZER)))

static func gameplay_matches_mood_fade_seconds() -> float:
	return max(0.0, float(_setting("gameplay_matches_mood_fade_seconds", GAMEPLAY_MATCHES_MOOD_FADE_SECONDS)))

static func gameplay_matches_max_calm_weight() -> float:
	return clamp(float(_setting("gameplay_matches_max_calm_weight", GAMEPLAY_MATCHES_MAX_CALM_WEIGHT)), 0.0, 1.0)

static func hint_pulse_speed_multiplier() -> float:
	return max(0.1, float(_setting("hint_pulse_speed_multiplier", HINT_PULSE_SPEED_MULTIPLIER)))

static func audio_track_id() -> String:
	return str(_setting("audio_track_id", AUDIO_TRACK_ID))

static func audio_track_manifest_path() -> String:
	return str(_setting("audio_track_manifest_path", AUDIO_TRACK_MANIFEST_PATH))

static func clear_high_score_on_boot() -> bool:
	return bool(_setting("clear_high_score_on_boot", CLEAR_HIGH_SCORE_ON_BOOT))

static func ad_retry_attempts() -> int:
	return max(0, int(_setting("ad_retry_attempts", AD_RETRY_ATTEMPTS)))

static func ad_retry_interval_seconds() -> float:
	return max(0.05, float(_setting("ad_retry_interval_seconds", AD_RETRY_INTERVAL_SECONDS)))

static func ad_preload_poll_seconds() -> float:
	return max(0.2, float(_setting("ad_preload_poll_seconds", AD_PRELOAD_POLL_SECONDS)))

static func starfield_calm_density() -> float:
	return max(0.2, float(_setting("starfield_calm_density", STARFIELD_CALM_DENSITY)))

static func starfield_hype_density() -> float:
	return max(0.2, float(_setting("starfield_hype_density", STARFIELD_HYPE_DENSITY)))

static func starfield_calm_speed() -> float:
	return max(0.1, float(_setting("starfield_calm_speed", STARFIELD_CALM_SPEED)))

static func starfield_hype_speed() -> float:
	return max(0.1, float(_setting("starfield_hype_speed", STARFIELD_HYPE_SPEED)))

static func starfield_calm_brightness() -> float:
	return max(0.1, float(_setting("starfield_calm_brightness", STARFIELD_CALM_BRIGHTNESS)))

static func starfield_hype_brightness() -> float:
	return max(0.1, float(_setting("starfield_hype_brightness", STARFIELD_HYPE_BRIGHTNESS)))

static func starfield_beat_pulse_depth() -> float:
	return clamp(float(_setting("starfield_beat_pulse_depth", STARFIELD_BEAT_PULSE_DEPTH)), 0.0, 1.0)

static func starfield_match_pulse_seconds() -> float:
	return max(0.05, float(_setting("starfield_match_pulse_seconds", STARFIELD_MATCH_PULSE_SECONDS)))

static func starfield_match_pulse_density_mult() -> float:
	return max(1.0, float(_setting("starfield_match_pulse_density_mult", STARFIELD_MATCH_PULSE_DENSITY_MULT)))

static func starfield_match_pulse_speed_mult() -> float:
	return max(1.0, float(_setting("starfield_match_pulse_speed_mult", STARFIELD_MATCH_PULSE_SPEED_MULT)))

static func starfield_match_pulse_brightness_mult() -> float:
	return max(1.0, float(_setting("starfield_match_pulse_brightness_mult", STARFIELD_MATCH_PULSE_BRIGHTNESS_MULT)))

static func starfield_hype_emission_floor() -> float:
	return clamp(float(_setting("starfield_hype_emission_floor", STARFIELD_HYPE_EMISSION_FLOOR)), 0.0, 1.0)

static func starfield_calm_emission_floor() -> float:
	return clamp(float(_setting("starfield_calm_emission_floor", STARFIELD_CALM_EMISSION_FLOOR)), 0.0, 1.0)

static func starfield_emission_ramp_up_seconds() -> float:
	return max(0.0, float(_setting("starfield_emission_ramp_up_seconds", STARFIELD_EMISSION_RAMP_UP_SECONDS)))

static func starfield_calm_point_color() -> Color:
	return _setting_color("starfield_calm_point_color", STARFIELD_CALM_POINT_COLOR)

static func starfield_calm_streak_color() -> Color:
	return _setting_color("starfield_calm_streak_color", STARFIELD_CALM_STREAK_COLOR)

static func starfield_hype_point_color() -> Color:
	return _setting_color("starfield_hype_point_color", STARFIELD_HYPE_POINT_COLOR)

static func starfield_hype_streak_color() -> Color:
	return _setting_color("starfield_hype_streak_color", STARFIELD_HYPE_STREAK_COLOR)

static func starfield_boost_point_color() -> Color:
	return _setting_color("starfield_boost_point_color", STARFIELD_BOOST_POINT_COLOR)

static func starfield_boost_streak_color() -> Color:
	return _setting_color("starfield_boost_streak_color", STARFIELD_BOOST_STREAK_COLOR)

static func haptics_enabled() -> bool:
	return bool(_setting("haptics_enabled", HAPTICS_ENABLED))

static func match_haptic_duration_ms() -> int:
	return max(0, int(_setting("match_haptic_duration_ms", MATCH_HAPTIC_DURATION_MS)))

static func match_haptic_amplitude() -> float:
	return clamp(float(_setting("match_haptic_amplitude", MATCH_HAPTIC_AMPLITUDE)), 0.0, 1.0)

static func match_click_haptic_duration_ms() -> int:
	return max(0, int(_setting("match_click_haptic_duration_ms", MATCH_CLICK_HAPTIC_DURATION_MS)))

static func match_click_haptic_amplitude() -> float:
	return clamp(float(_setting("match_click_haptic_amplitude", MATCH_CLICK_HAPTIC_AMPLITUDE)), 0.0, 1.0)

static func powerup_undo_charges() -> int:
	return max(0, int(_setting("powerup_undo_charges", POWERUP_UNDO_CHARGES)))

static func powerup_remove_color_charges() -> int:
	return max(0, int(_setting("powerup_remove_color_charges", POWERUP_REMOVE_COLOR_CHARGES)))

static func powerup_shuffle_charges() -> int:
	return max(0, int(_setting("powerup_shuffle_charges", POWERUP_SHUFFLE_CHARGES)))

static func powerup_flash_alpha() -> float:
	return clamp(float(_setting("powerup_flash_alpha", POWERUP_FLASH_ALPHA)), 0.0, 1.0)

static func powerup_flash_seconds() -> float:
	return max(0.05, float(_setting("powerup_flash_seconds", POWERUP_FLASH_SECONDS)))
