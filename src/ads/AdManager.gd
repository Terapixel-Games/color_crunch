extends Node

signal rewarded_earned
signal rewarded_closed
signal rewarded_powerup_earned

const FeatureFlagsScript := preload("res://src/config/FeatureFlags.gd")
const MockAdProviderScript := preload("res://src/ads/MockAdProvider.gd")
const AdmobProviderScript := preload("res://src/ads/AdmobProvider.gd")
const AdCadenceScript := preload("res://src/ads/AdCadence.gd")

const APP_ID := "ca-app-pub-8413230766502262~3818991626"
const INTERSTITIAL_ID := "ca-app-pub-8413230766502262/8010460026"
const REWARDED_ID := "ca-app-pub-8413230766502262/6744537862"

var provider: Object
var _last_interstitial_shown_games_played: int = -1
var _interstitial_retry_active: bool = false
var _interstitial_retry_game_count: int = -1
var _rewarded_retry_active: bool = false
var _active_rewarded_context: String = ""
var _rewarded_preload_loop_active: bool = false

func _ready() -> void:
	_initialize_provider_async()

func _exit_tree() -> void:
	_rewarded_preload_loop_active = false

func _initialize_provider_async() -> void:
	if provider != null:
		return
	var forced_mock: bool = bool(ProjectSettings.get_setting("lumarush/use_mock_ads", Engine.is_editor_hint()))
	if DisplayServer.get_name() == "headless":
		forced_mock = true
	var has_admob_singleton: bool = Engine.has_singleton("AdmobPlugin")
	if not forced_mock and not has_admob_singleton:
		var retries: int = 10
		while retries > 0 and not has_admob_singleton:
			await get_tree().create_timer(0.2).timeout
			has_admob_singleton = Engine.has_singleton("AdmobPlugin")
			retries -= 1
	var use_mock: bool = forced_mock or (not has_admob_singleton)
	if use_mock:
		provider = MockAdProviderScript.new()
		if not forced_mock:
			push_warning("AdManager: using MockAdProvider (singleton=%s, forced=%s)." % [str(has_admob_singleton), str(forced_mock)])
	else:
		provider = AdmobProviderScript.new()
		add_child(provider)
		provider.configure(APP_ID, INTERSTITIAL_ID, REWARDED_ID)
	_bind_provider()

func _bind_provider() -> void:
	if provider == null:
		return
	provider.connect("interstitial_loaded", Callable(self, "_on_interstitial_loaded"))
	provider.connect("interstitial_closed", Callable(self, "_on_interstitial_closed"))
	provider.connect("rewarded_loaded", Callable(self, "_on_rewarded_loaded"))
	provider.connect("rewarded_earned", Callable(self, "_on_rewarded_earned"))
	provider.connect("rewarded_closed", Callable(self, "_on_rewarded_closed"))
	provider.load_interstitial(INTERSTITIAL_ID)
	provider.load_rewarded(REWARDED_ID)
	if not FeatureFlagsScript.is_visual_test_mode() and DisplayServer.get_name() != "headless":
		_start_rewarded_preload_loop()

func on_game_finished() -> void:
	SaveStore.increment_games_played()

func maybe_show_interstitial() -> void:
	var games := int(SaveStore.data["games_played"])
	if _last_interstitial_shown_games_played == games:
		return
	var n := AdCadenceScript.interstitial_every_n_games(StreakManager.get_streak_days())
	if n <= 0:
		return
	if games % n != 0:
		return
	if _show_interstitial_now(games):
		return
	_start_interstitial_retry(games)

func show_rewarded_for_save() -> bool:
	_ensure_provider_available()
	if _active_rewarded_context != "":
		return false
	_active_rewarded_context = "save_streak"
	if _show_rewarded_now():
		return true
	return _start_rewarded_retry()

func show_rewarded_for_powerup() -> bool:
	_ensure_provider_available()
	if _active_rewarded_context != "":
		return false
	_active_rewarded_context = "powerup"
	if _show_rewarded_now():
		return true
	return _start_rewarded_retry()

func _on_interstitial_loaded() -> void:
	if _interstitial_retry_active:
		_show_interstitial_now(_interstitial_retry_game_count)

func _on_interstitial_closed() -> void:
	MusicManager.set_ads_paused(false)
	MusicManager.set_ads_ducked(false)
	_interstitial_retry_active = false
	_interstitial_retry_game_count = -1

func _on_rewarded_loaded() -> void:
	if _rewarded_retry_active:
		_show_rewarded_now()

func _on_rewarded_earned() -> void:
	match _active_rewarded_context:
		"save_streak":
			StreakManager.apply_rewarded_save()
			emit_signal("rewarded_earned")
		"powerup":
			emit_signal("rewarded_powerup_earned")
		_:
			emit_signal("rewarded_earned")

func _on_rewarded_closed() -> void:
	MusicManager.set_ads_paused(false)
	MusicManager.set_ads_ducked(false)
	_rewarded_retry_active = false
	_active_rewarded_context = ""
	emit_signal("rewarded_closed")

func _show_interstitial_now(games: int) -> bool:
	if provider == null:
		return false
	if provider.show_interstitial(INTERSTITIAL_ID):
		_last_interstitial_shown_games_played = games
		_interstitial_retry_active = false
		_interstitial_retry_game_count = -1
		MusicManager.set_ads_ducked(true)
		MusicManager.set_ads_paused(true)
		return true
	return false

func _show_rewarded_now() -> bool:
	if provider == null:
		return false
	var shown: bool = provider.show_rewarded(REWARDED_ID)
	if shown:
		_rewarded_retry_active = false
		MusicManager.set_ads_ducked(true)
		MusicManager.set_ads_paused(true)
	return shown

func _start_interstitial_retry(games: int) -> void:
	if _interstitial_retry_active:
		return
	var retries: int = FeatureFlagsScript.ad_retry_attempts()
	if retries <= 0:
		push_warning("AdManager: interstitial opportunity missed (ad not ready).")
		return
	_interstitial_retry_active = true
	_interstitial_retry_game_count = games
	_retry_interstitial_async(games, retries)

func _start_rewarded_retry() -> bool:
	if _rewarded_retry_active:
		return true
	var retries: int = FeatureFlagsScript.ad_retry_attempts()
	if retries <= 0:
		_active_rewarded_context = ""
		return false
	_rewarded_retry_active = true
	_retry_rewarded_async(retries)
	return true

func _retry_interstitial_async(games: int, retries_left: int) -> void:
	while _interstitial_retry_active and retries_left > 0 and _last_interstitial_shown_games_played != games:
		if provider == null:
			break
		provider.load_interstitial(INTERSTITIAL_ID)
		await get_tree().create_timer(FeatureFlagsScript.ad_retry_interval_seconds()).timeout
		if _show_interstitial_now(games):
			return
		retries_left -= 1
	if _interstitial_retry_active and _last_interstitial_shown_games_played != games:
		push_warning("AdManager: interstitial retries exhausted.")
	_interstitial_retry_active = false
	_interstitial_retry_game_count = -1

func _retry_rewarded_async(retries_left: int) -> void:
	var had_active_context: bool = _active_rewarded_context != ""
	while _rewarded_retry_active and retries_left > 0:
		if provider == null:
			break
		provider.load_rewarded(REWARDED_ID)
		await get_tree().create_timer(FeatureFlagsScript.ad_retry_interval_seconds()).timeout
		if _show_rewarded_now():
			return
		retries_left -= 1
	_rewarded_retry_active = false
	_active_rewarded_context = ""
	if had_active_context:
		emit_signal("rewarded_closed")

func _start_rewarded_preload_loop() -> void:
	if _rewarded_preload_loop_active:
		return
	_rewarded_preload_loop_active = true
	_rewarded_preload_loop()

func _rewarded_preload_loop() -> void:
	while _rewarded_preload_loop_active and is_inside_tree() and provider != null:
		var is_ready: bool = false
		if provider.has_method("is_rewarded_ready"):
			is_ready = bool(provider.call("is_rewarded_ready"))
		if not is_ready and _active_rewarded_context == "":
			provider.load_rewarded(REWARDED_ID)
		await get_tree().create_timer(FeatureFlagsScript.ad_preload_poll_seconds()).timeout

func _ensure_provider_available() -> void:
	if provider != null:
		return
	provider = MockAdProviderScript.new()
	_bind_provider()
