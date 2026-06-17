extends GdUnitTestSuite

func before() -> void:
	ProjectSettings.set_setting("lumarush/tile_blur_mode", FeatureFlags.TileBlurMode.LITE)
	ProjectSettings.set_setting("lumarush/tile_design_mode", FeatureFlags.TileDesignMode.MODERN)
	ProjectSettings.set_setting("lumarush/min_match_size", FeatureFlags.MIN_MATCH_SIZE)
	ProjectSettings.set_setting("lumarush/combo_decay_delay_seconds", FeatureFlags.COMBO_DECAY_DELAY_SECONDS)
	ProjectSettings.set_setting("lumarush/combo_decay_seconds", FeatureFlags.COMBO_DECAY_SECONDS)
	ProjectSettings.set_setting("lumarush/combo_decay_target_db", FeatureFlags.COMBO_DECAY_TARGET_DB)
	ProjectSettings.set_setting("lumarush/match_hint_delay_seconds", FeatureFlags.MATCH_HINT_DELAY_SECONDS)
	ProjectSettings.set_setting("lumarush/gameplay_matches_normalizer", FeatureFlags.GAMEPLAY_MATCHES_NORMALIZER)
	ProjectSettings.set_setting("lumarush/gameplay_matches_mood_fade_seconds", FeatureFlags.GAMEPLAY_MATCHES_MOOD_FADE_SECONDS)
	ProjectSettings.set_setting("lumarush/gameplay_matches_max_calm_weight", FeatureFlags.GAMEPLAY_MATCHES_MAX_CALM_WEIGHT)
	ProjectSettings.set_setting("lumarush/hint_pulse_speed_multiplier", FeatureFlags.HINT_PULSE_SPEED_MULTIPLIER)
	ProjectSettings.set_setting("lumarush/audio_track_id", FeatureFlags.AUDIO_TRACK_ID)
	ProjectSettings.set_setting("lumarush/audio_track_manifest_path", FeatureFlags.AUDIO_TRACK_MANIFEST_PATH)
	ProjectSettings.set_setting("lumarush/clear_high_score_on_boot", FeatureFlags.CLEAR_HIGH_SCORE_ON_BOOT)
	ProjectSettings.set_setting("lumarush/ad_retry_attempts", FeatureFlags.AD_RETRY_ATTEMPTS)
	ProjectSettings.set_setting("lumarush/ad_retry_interval_seconds", FeatureFlags.AD_RETRY_INTERVAL_SECONDS)
	ProjectSettings.set_setting("lumarush/starfield_calm_point_color", FeatureFlags.STARFIELD_CALM_POINT_COLOR)
	ProjectSettings.set_setting("lumarush/starfield_calm_streak_color", FeatureFlags.STARFIELD_CALM_STREAK_COLOR)
	ProjectSettings.set_setting("lumarush/starfield_hype_point_color", FeatureFlags.STARFIELD_HYPE_POINT_COLOR)
	ProjectSettings.set_setting("lumarush/starfield_hype_streak_color", FeatureFlags.STARFIELD_HYPE_STREAK_COLOR)
	ProjectSettings.set_setting("lumarush/haptics_enabled", FeatureFlags.HAPTICS_ENABLED)
	ProjectSettings.set_setting("lumarush/match_click_haptic_duration_ms", FeatureFlags.MATCH_CLICK_HAPTIC_DURATION_MS)
	ProjectSettings.set_setting("lumarush/match_click_haptic_amplitude", FeatureFlags.MATCH_CLICK_HAPTIC_AMPLITUDE)
	ProjectSettings.set_setting("lumarush/match_haptic_duration_ms", FeatureFlags.MATCH_HAPTIC_DURATION_MS)
	ProjectSettings.set_setting("lumarush/match_haptic_amplitude", FeatureFlags.MATCH_HAPTIC_AMPLITUDE)
	ProjectSettings.set_setting("lumarush/powerup_undo_charges", FeatureFlags.POWERUP_UNDO_CHARGES)
	ProjectSettings.set_setting("lumarush/powerup_remove_color_charges", FeatureFlags.POWERUP_REMOVE_COLOR_CHARGES)
	ProjectSettings.set_setting("lumarush/powerup_shuffle_charges", FeatureFlags.POWERUP_SHUFFLE_CHARGES)
	ProjectSettings.set_setting("lumarush/powerup_flash_alpha", FeatureFlags.POWERUP_FLASH_ALPHA)
	ProjectSettings.set_setting("lumarush/powerup_flash_seconds", FeatureFlags.POWERUP_FLASH_SECONDS)

func test_tile_blur_mode_default_lite() -> void:
	assert_that(FeatureFlags.tile_blur_mode()).is_equal(FeatureFlags.TileBlurMode.LITE)

func test_tile_blur_mode_override_heavy() -> void:
	ProjectSettings.set_setting("lumarush/tile_blur_mode", FeatureFlags.TileBlurMode.HEAVY)
	assert_that(FeatureFlags.tile_blur_mode()).is_equal(FeatureFlags.TileBlurMode.HEAVY)

func test_tile_design_mode_default_and_override() -> void:
	assert_that(FeatureFlags.tile_design_mode()).is_equal(FeatureFlags.TileDesignMode.MODERN)
	ProjectSettings.set_setting("lumarush/tile_design_mode", FeatureFlags.TileDesignMode.LEGACY)
	assert_that(FeatureFlags.tile_design_mode()).is_equal(FeatureFlags.TileDesignMode.LEGACY)
	ProjectSettings.set_setting("lumarush/tile_design_mode", 999)
	assert_that(FeatureFlags.tile_design_mode()).is_equal(FeatureFlags.TileDesignMode.LEGACY)

func test_min_match_size_default_and_override() -> void:
	assert_that(FeatureFlags.min_match_size()).is_equal(FeatureFlags.MIN_MATCH_SIZE)
	ProjectSettings.set_setting("lumarush/min_match_size", 4)
	assert_that(FeatureFlags.min_match_size()).is_equal(4)
	ProjectSettings.set_setting("lumarush/min_match_size", 1)
	assert_that(FeatureFlags.min_match_size()).is_equal(2)

func test_combo_decay_config_overrides() -> void:
	assert_that(FeatureFlags.combo_decay_delay_seconds()).is_equal(FeatureFlags.COMBO_DECAY_DELAY_SECONDS)
	assert_that(FeatureFlags.combo_decay_seconds()).is_equal(FeatureFlags.COMBO_DECAY_SECONDS)
	assert_that(FeatureFlags.combo_decay_target_db()).is_equal(FeatureFlags.COMBO_DECAY_TARGET_DB)
	ProjectSettings.set_setting("lumarush/combo_decay_delay_seconds", 0.6)
	ProjectSettings.set_setting("lumarush/combo_decay_seconds", 3.4)
	ProjectSettings.set_setting("lumarush/combo_decay_target_db", -24.0)
	assert_that(FeatureFlags.combo_decay_delay_seconds()).is_equal(0.6)
	assert_that(FeatureFlags.combo_decay_seconds()).is_equal(3.4)
	assert_that(FeatureFlags.combo_decay_target_db()).is_equal(-24.0)

func test_match_hint_delay_default_and_override() -> void:
	assert_that(FeatureFlags.match_hint_delay_seconds()).is_equal(FeatureFlags.MATCH_HINT_DELAY_SECONDS)
	ProjectSettings.set_setting("lumarush/match_hint_delay_seconds", 5.5)
	assert_that(FeatureFlags.match_hint_delay_seconds()).is_equal(5.5)

func test_gameplay_matches_mood_config_overrides() -> void:
	assert_that(FeatureFlags.gameplay_matches_normalizer()).is_equal(FeatureFlags.GAMEPLAY_MATCHES_NORMALIZER)
	assert_that(FeatureFlags.gameplay_matches_mood_fade_seconds()).is_equal(FeatureFlags.GAMEPLAY_MATCHES_MOOD_FADE_SECONDS)
	assert_that(FeatureFlags.gameplay_matches_max_calm_weight()).is_equal(FeatureFlags.GAMEPLAY_MATCHES_MAX_CALM_WEIGHT)
	ProjectSettings.set_setting("lumarush/gameplay_matches_normalizer", 20.0)
	ProjectSettings.set_setting("lumarush/gameplay_matches_mood_fade_seconds", 1.2)
	ProjectSettings.set_setting("lumarush/gameplay_matches_max_calm_weight", 0.35)
	assert_that(FeatureFlags.gameplay_matches_normalizer()).is_equal(20.0)
	assert_that(FeatureFlags.gameplay_matches_mood_fade_seconds()).is_equal(1.2)
	assert_that(FeatureFlags.gameplay_matches_max_calm_weight()).is_equal(0.35)
	ProjectSettings.set_setting("lumarush/gameplay_matches_max_calm_weight", 3.0)
	assert_that(FeatureFlags.gameplay_matches_max_calm_weight()).is_equal(1.0)

func test_hint_pulse_speed_config_overrides() -> void:
	assert_that(FeatureFlags.hint_pulse_speed_multiplier()).is_equal(FeatureFlags.HINT_PULSE_SPEED_MULTIPLIER)
	ProjectSettings.set_setting("lumarush/hint_pulse_speed_multiplier", 1.75)
	assert_that(FeatureFlags.hint_pulse_speed_multiplier()).is_equal(1.75)
	ProjectSettings.set_setting("lumarush/hint_pulse_speed_multiplier", -5.0)
	assert_that(FeatureFlags.hint_pulse_speed_multiplier()).is_equal(0.1)

func test_audio_track_config_overrides() -> void:
	assert_that(FeatureFlags.audio_track_id()).is_equal(FeatureFlags.AUDIO_TRACK_ID)
	assert_that(FeatureFlags.audio_track_manifest_path()).is_equal(FeatureFlags.AUDIO_TRACK_MANIFEST_PATH)
	ProjectSettings.set_setting("lumarush/audio_track_id", "alt")
	ProjectSettings.set_setting("lumarush/audio_track_manifest_path", "res://tmp/tracks.json")
	assert_that(FeatureFlags.audio_track_id()).is_equal("alt")
	assert_that(FeatureFlags.audio_track_manifest_path()).is_equal("res://tmp/tracks.json")

func test_clear_high_score_flag_override() -> void:
	assert_that(FeatureFlags.clear_high_score_on_boot()).is_equal(FeatureFlags.CLEAR_HIGH_SCORE_ON_BOOT)
	ProjectSettings.set_setting("lumarush/clear_high_score_on_boot", true)
	assert_that(FeatureFlags.clear_high_score_on_boot()).is_true()

func test_powerup_flags_override() -> void:
	assert_that(FeatureFlags.powerup_undo_charges()).is_equal(FeatureFlags.POWERUP_UNDO_CHARGES)
	assert_that(FeatureFlags.powerup_remove_color_charges()).is_equal(FeatureFlags.POWERUP_REMOVE_COLOR_CHARGES)
	assert_that(FeatureFlags.powerup_shuffle_charges()).is_equal(FeatureFlags.POWERUP_SHUFFLE_CHARGES)
	ProjectSettings.set_setting("lumarush/powerup_undo_charges", 3)
	ProjectSettings.set_setting("lumarush/powerup_remove_color_charges", 2)
	ProjectSettings.set_setting("lumarush/powerup_shuffle_charges", 4)
	assert_that(FeatureFlags.powerup_undo_charges()).is_equal(3)
	assert_that(FeatureFlags.powerup_remove_color_charges()).is_equal(2)
	assert_that(FeatureFlags.powerup_shuffle_charges()).is_equal(4)

func test_powerup_flash_flags_override() -> void:
	assert_that(FeatureFlags.powerup_flash_alpha()).is_equal(FeatureFlags.POWERUP_FLASH_ALPHA)
	assert_that(FeatureFlags.powerup_flash_seconds()).is_equal(FeatureFlags.POWERUP_FLASH_SECONDS)
	ProjectSettings.set_setting("lumarush/powerup_flash_alpha", 1.5)
	ProjectSettings.set_setting("lumarush/powerup_flash_seconds", 0.01)
	assert_that(FeatureFlags.powerup_flash_alpha()).is_equal(1.0)
	assert_that(FeatureFlags.powerup_flash_seconds()).is_equal(0.05)

func test_haptics_flags_override() -> void:
	assert_that(FeatureFlags.haptics_enabled()).is_equal(FeatureFlags.HAPTICS_ENABLED)
	assert_that(FeatureFlags.match_click_haptic_duration_ms()).is_equal(FeatureFlags.MATCH_CLICK_HAPTIC_DURATION_MS)
	assert_that(FeatureFlags.match_click_haptic_amplitude()).is_equal(FeatureFlags.MATCH_CLICK_HAPTIC_AMPLITUDE)
	assert_that(FeatureFlags.match_haptic_duration_ms()).is_equal(FeatureFlags.MATCH_HAPTIC_DURATION_MS)
	assert_that(FeatureFlags.match_haptic_amplitude()).is_equal(FeatureFlags.MATCH_HAPTIC_AMPLITUDE)
	ProjectSettings.set_setting("lumarush/haptics_enabled", false)
	ProjectSettings.set_setting("lumarush/match_click_haptic_duration_ms", -3)
	ProjectSettings.set_setting("lumarush/match_click_haptic_amplitude", 9.0)
	ProjectSettings.set_setting("lumarush/match_haptic_duration_ms", -2)
	ProjectSettings.set_setting("lumarush/match_haptic_amplitude", 4.0)
	assert_that(FeatureFlags.haptics_enabled()).is_false()
	assert_that(FeatureFlags.match_click_haptic_duration_ms()).is_equal(0)
	assert_that(FeatureFlags.match_click_haptic_amplitude()).is_equal(1.0)
	assert_that(FeatureFlags.match_haptic_duration_ms()).is_equal(0)
	assert_that(FeatureFlags.match_haptic_amplitude()).is_equal(1.0)

func test_ad_retry_flags_override() -> void:
	assert_that(FeatureFlags.ad_retry_attempts()).is_equal(FeatureFlags.AD_RETRY_ATTEMPTS)
	assert_that(FeatureFlags.ad_retry_interval_seconds()).is_equal(FeatureFlags.AD_RETRY_INTERVAL_SECONDS)
	ProjectSettings.set_setting("lumarush/ad_retry_attempts", -5)
	ProjectSettings.set_setting("lumarush/ad_retry_interval_seconds", 0.0)
	assert_that(FeatureFlags.ad_retry_attempts()).is_equal(0)
	assert_that(FeatureFlags.ad_retry_interval_seconds()).is_equal(0.05)

func test_starfield_mode_color_overrides() -> void:
	assert_that(FeatureFlags.starfield_calm_point_color()).is_equal(FeatureFlags.STARFIELD_CALM_POINT_COLOR)
	assert_that(FeatureFlags.starfield_hype_point_color()).is_equal(FeatureFlags.STARFIELD_HYPE_POINT_COLOR)
	ProjectSettings.set_setting("lumarush/starfield_calm_point_color", Color(0.2, 0.8, 1.0, 1.0))
	ProjectSettings.set_setting("lumarush/starfield_hype_point_color", Color(1.0, 1.0, 1.0, 1.0))
	assert_that(FeatureFlags.starfield_calm_point_color()).is_equal(Color(0.2, 0.8, 1.0, 1.0))
	assert_that(FeatureFlags.starfield_hype_point_color()).is_equal(Color(1.0, 1.0, 1.0, 1.0))

func test_color_crunch_settings_override_lumarush_fallbacks() -> void:
	ProjectSettings.set_setting("lumarush/tile_blur_mode", FeatureFlags.TileBlurMode.HEAVY)
	ProjectSettings.set_setting("color_crunch/tile_blur_mode", FeatureFlags.TileBlurMode.LITE)
	assert_that(FeatureFlags.tile_blur_mode()).is_equal(FeatureFlags.TileBlurMode.LITE)
	ProjectSettings.clear("color_crunch/tile_blur_mode")
	assert_that(FeatureFlags.tile_blur_mode()).is_equal(FeatureFlags.TileBlurMode.HEAVY)
	ProjectSettings.set_setting("lumarush/tile_blur_mode", FeatureFlags.TileBlurMode.LITE)
