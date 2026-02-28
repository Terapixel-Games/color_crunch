extends GdUnitTestSuite

const TMP_PROFILE_PATH := "user://ac_background_profiles_test.json"
const BACKGROUND_PROFILES_SCRIPT := preload("res://addons/arcade_core/Background/AC_BackgroundProfiles.gd")
const BACKGROUND_PROFILE_SCRIPT := preload("res://addons/arcade_core/Background/AC_BackgroundProfile.gd")

func before_test() -> void:
	BACKGROUND_PROFILES_SCRIPT.clear_cache()

func after_test() -> void:
	if FileAccess.file_exists(TMP_PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PROFILE_PATH))
	BACKGROUND_PROFILES_SCRIPT.clear_cache()

func test_loader_parses_json_and_applies_defaults() -> void:
	_write_profile_json("""
{
	"profiles": {
		"minimal": {
			"gradient": {"base_color_a": "#112233"},
			"parallax_layers": [{"velocity": [1, 2]}],
			"flow_particles": {"enabled": false}
		}
	}
}
""")

	var profiles: Dictionary = BACKGROUND_PROFILES_SCRIPT.load_profiles(TMP_PROFILE_PATH)
	assert_that(profiles.has("minimal")).is_true()

	var profile: Variant = profiles["minimal"]
	assert_that(profile.profile_name).is_equal("minimal")
	assert_that(profile.gradient["base_color_a"]).is_equal("#112233")
	assert_that(profile.gradient["base_color_b"]).is_equal(BACKGROUND_PROFILE_SCRIPT.DEFAULT_GRADIENT["base_color_b"])
	assert_that(profile.parallax_layers.size()).is_equal(1)
	assert_that(profile.parallax_layers[0]["velocity"]).is_equal(Vector2(1.0, 2.0))
	assert_that(profile.parallax_layers[0]["alpha"]).is_equal(0.2)
	assert_that(profile.flow_particles["enabled"]).is_false()
	assert_that(profile.flow_particles["count"]).is_equal(BACKGROUND_PROFILE_SCRIPT.DEFAULT_FLOW["count"])
	assert_that(profile.grid["enabled"]).is_equal(BACKGROUND_PROFILE_SCRIPT.DEFAULT_GRID["enabled"])
	assert_that(profile.sweep["enabled"]).is_equal(BACKGROUND_PROFILE_SCRIPT.DEFAULT_SWEEP["enabled"])

func test_loader_falls_back_to_builtin_profiles_for_missing_file() -> void:
	var missing_path := "user://ac_background_profiles_missing.json"
	if FileAccess.file_exists(missing_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(missing_path))

	var profiles: Dictionary = BACKGROUND_PROFILES_SCRIPT.load_profiles(missing_path)
	assert_that(profiles.has("calm_puzzle")).is_true()
	assert_that(profiles.has("neon_arcade")).is_true()
	assert_that(profiles.has("synth_grid")).is_true()

func _write_profile_json(contents: String) -> void:
	var file := FileAccess.open(TMP_PROFILE_PATH, FileAccess.WRITE)
	assert_that(file).is_not_null()
	file.store_string(contents.strip_edges())
	file.close()
