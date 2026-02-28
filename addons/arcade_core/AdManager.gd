extends Node

signal rewarded_earned
signal rewarded_closed
signal rewarded_powerup_earned

const LOCAL_CFG := "res://configs/AdMob.local.txt"
const AdCadenceScript := preload("res://addons/arcade_core/AdCadence.gd")
const MOCK_PROVIDER_PATH := "res://addons/arcade_core/ads/MockAdProvider.gd"

@export var ad_retry_attempts := 2
@export var ad_retry_interval_seconds := 0.35
@export var ad_preload_poll_seconds := 1.25
@export var use_mock_ads := true

var app_id := ""
var interstitial_id := ""
var rewarded_id := ""

var provider: Object = null
var _last_interstitial_shown_games_played := -1
var _interstitial_retry_active := false
var _interstitial_retry_game_count := -1
var _rewarded_retry_active := false
var _active_rewarded_context := ""
var _rewarded_preload_loop_active := false
var _owns_provider := false

func _ready() -> void:
    _load_local_cfg()
    _ensure_fallback_ad_unit_ids()
    _initialize_provider()

func _exit_tree() -> void:
    _rewarded_preload_loop_active = false
    _interstitial_retry_active = false
    _rewarded_retry_active = false
    _active_rewarded_context = ""
    _disconnect_provider_signals()
    if _owns_provider and provider is Node and is_instance_valid(provider):
        var provider_node: Node = provider as Node
        if provider_node.get_parent() == self:
            if provider_node.is_inside_tree():
                provider_node.queue_free()
            else:
                provider_node.free()
        elif not provider_node.is_inside_tree():
            provider_node.free()
    provider = null
    _owns_provider = false

func _load_local_cfg() -> void:
    if not FileAccess.file_exists(LOCAL_CFG):
        return

    var f := FileAccess.open(LOCAL_CFG, FileAccess.READ)
    if f == null:
        return

    while not f.eof_reached():
        var line := f.get_line().strip_edges()
        if line.begins_with("#") or line == "":
            continue

        var parts := line.split("=", false, 2)
        if parts.size() != 2:
            continue

        var k := parts[0].strip_edges()
        var v := parts[1].strip_edges()

        match k:
            "APP_ID": app_id = v
            "INTERSTITIAL": interstitial_id = v
            "REWARDED": rewarded_id = v

    f.close()

func _ensure_fallback_ad_unit_ids() -> void:
    if app_id.is_empty():
        app_id = "mock-app-id"
    if interstitial_id.is_empty():
        interstitial_id = "mock-interstitial-id"
    if rewarded_id.is_empty():
        rewarded_id = "mock-rewarded-id"

func _initialize_provider() -> void:
    if provider != null:
        return

    if not use_mock_ads:
        push_warning("AdManager: no real provider wired yet; falling back to MockAdProvider.")
    var script: Script = load(MOCK_PROVIDER_PATH)
    if script == null:
        return
    provider = script.new()
    _owns_provider = true
    if provider is Node:
        var provider_node: Node = provider as Node
        if provider_node.get_parent() == null:
            add_child(provider_node)
    _bind_provider()

func set_provider(custom_provider: Object) -> void:
    if custom_provider == null:
        return
    _disconnect_provider_signals()
    _owns_provider = false
    provider = custom_provider
    _bind_provider()

func _bind_provider() -> void:
    if provider == null:
        return

    var on_interstitial_loaded := Callable(self, "_on_interstitial_loaded")
    var on_interstitial_closed := Callable(self, "_on_interstitial_closed")
    var on_rewarded_loaded := Callable(self, "_on_rewarded_loaded")
    var on_rewarded_earned := Callable(self, "_on_rewarded_earned")
    var on_rewarded_closed := Callable(self, "_on_rewarded_closed")
    if not provider.is_connected("interstitial_loaded", on_interstitial_loaded):
        provider.connect("interstitial_loaded", on_interstitial_loaded)
    if not provider.is_connected("interstitial_closed", on_interstitial_closed):
        provider.connect("interstitial_closed", on_interstitial_closed)
    if not provider.is_connected("rewarded_loaded", on_rewarded_loaded):
        provider.connect("rewarded_loaded", on_rewarded_loaded)
    if not provider.is_connected("rewarded_earned", on_rewarded_earned):
        provider.connect("rewarded_earned", on_rewarded_earned)
    if not provider.is_connected("rewarded_closed", on_rewarded_closed):
        provider.connect("rewarded_closed", on_rewarded_closed)

    if provider.has_method("initialize"):
        provider.call("initialize", app_id)
    if provider.has_method("load_interstitial"):
        provider.call("load_interstitial", interstitial_id)
    if provider.has_method("load_rewarded"):
        provider.call("load_rewarded", rewarded_id)

    _start_rewarded_preload_loop()

func on_game_finished() -> void:
    SaveManager.increment_games_played()
    StreakManager.record_game_play()

func maybe_show_interstitial() -> void:
    var games := SaveManager.games_played()
    if _last_interstitial_shown_games_played == games:
        return

    var n: int = int(AdCadenceScript.interstitial_every_n_games(StreakManager.get_streak_days()))
    if n <= 0:
        return
    if games % n != 0:
        return

    if _show_interstitial_now(games):
        return
    _start_interstitial_retry(games)

func show_rewarded_for_save() -> bool:
    if _active_rewarded_context != "":
        return false
    _active_rewarded_context = "save_streak"

    if _show_rewarded_now():
        return true
    return _start_rewarded_retry()

func show_rewarded_for_powerup() -> bool:
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
            emit_signal("rewarded_earned")
        _:
            emit_signal("rewarded_earned")

func _on_rewarded_closed() -> void:
    _rewarded_retry_active = false
    _active_rewarded_context = ""
    emit_signal("rewarded_closed")

func _show_interstitial_now(games: int) -> bool:
    if provider == null or interstitial_id.is_empty():
        return false

    var shown := bool(provider.call("show_interstitial", interstitial_id))
    if shown:
        _last_interstitial_shown_games_played = games
        _interstitial_retry_active = false
        _interstitial_retry_game_count = -1
    return shown

func _show_rewarded_now() -> bool:
    if provider == null or rewarded_id.is_empty():
        return false

    var shown := bool(provider.call("show_rewarded", rewarded_id))
    if shown:
        _rewarded_retry_active = false
    return shown

func _start_interstitial_retry(games: int) -> void:
    if _interstitial_retry_active:
        return
    if ad_retry_attempts <= 0:
        return

    _interstitial_retry_active = true
    _interstitial_retry_game_count = games
    _retry_interstitial_async(games, ad_retry_attempts)

func _start_rewarded_retry() -> bool:
    if _rewarded_retry_active:
        return true
    if ad_retry_attempts <= 0:
        _active_rewarded_context = ""
        return false

    _rewarded_retry_active = true
    _retry_rewarded_async(ad_retry_attempts)
    return true

func _retry_interstitial_async(games: int, retries_left: int) -> void:
    while _interstitial_retry_active and retries_left > 0 and _last_interstitial_shown_games_played != games:
        provider.call("load_interstitial", interstitial_id)
        await get_tree().create_timer(ad_retry_interval_seconds).timeout
        if _show_interstitial_now(games):
            return
        retries_left -= 1

    _interstitial_retry_active = false
    _interstitial_retry_game_count = -1

func _retry_rewarded_async(retries_left: int) -> void:
    var had_context := _active_rewarded_context != ""

    while _rewarded_retry_active and retries_left > 0:
        provider.call("load_rewarded", rewarded_id)
        await get_tree().create_timer(ad_retry_interval_seconds).timeout
        if _show_rewarded_now():
            return
        retries_left -= 1

    _rewarded_retry_active = false
    _active_rewarded_context = ""
    if had_context:
        emit_signal("rewarded_closed")

func _start_rewarded_preload_loop() -> void:
    if _rewarded_preload_loop_active:
        return
    if _is_headless_runtime():
        return
    if _is_mock_provider_active():
        return
    _rewarded_preload_loop_active = true
    _rewarded_preload_loop()

func _rewarded_preload_loop() -> void:
    while _rewarded_preload_loop_active and is_inside_tree() and provider != null:
        var is_ready := false
        if provider.has_method("is_rewarded_ready"):
            is_ready = bool(provider.call("is_rewarded_ready"))

        if not is_ready and _active_rewarded_context == "":
            provider.call("load_rewarded", rewarded_id)

        await get_tree().create_timer(ad_preload_poll_seconds).timeout

func preload_ads() -> void:
    if provider == null:
        return
    provider.call("load_interstitial", interstitial_id)
    provider.call("load_rewarded", rewarded_id)

func show_rewarded_continue() -> bool:
    return show_rewarded_for_powerup()

func show_interstitial_if_ready() -> bool:
    var games := SaveManager.games_played()
    return _show_interstitial_now(games)

func show_rewarded_if_ready(on_rewarded: Callable) -> bool:
    if _active_rewarded_context != "":
        return false
    _active_rewarded_context = "direct_callback"

    if on_rewarded.is_valid():
        rewarded_earned.connect(on_rewarded, CONNECT_ONE_SHOT)
    if _show_rewarded_now():
        return true

    if on_rewarded.is_valid() and rewarded_earned.is_connected(on_rewarded):
        rewarded_earned.disconnect(on_rewarded)
    _active_rewarded_context = ""
    return false

func _disconnect_provider_signals() -> void:
    if provider == null:
        return
    var on_interstitial_loaded := Callable(self, "_on_interstitial_loaded")
    var on_interstitial_closed := Callable(self, "_on_interstitial_closed")
    var on_rewarded_loaded := Callable(self, "_on_rewarded_loaded")
    var on_rewarded_earned := Callable(self, "_on_rewarded_earned")
    var on_rewarded_closed := Callable(self, "_on_rewarded_closed")
    if provider.is_connected("interstitial_loaded", on_interstitial_loaded):
        provider.disconnect("interstitial_loaded", on_interstitial_loaded)
    if provider.is_connected("interstitial_closed", on_interstitial_closed):
        provider.disconnect("interstitial_closed", on_interstitial_closed)
    if provider.is_connected("rewarded_loaded", on_rewarded_loaded):
        provider.disconnect("rewarded_loaded", on_rewarded_loaded)
    if provider.is_connected("rewarded_earned", on_rewarded_earned):
        provider.disconnect("rewarded_earned", on_rewarded_earned)
    if provider.is_connected("rewarded_closed", on_rewarded_closed):
        provider.disconnect("rewarded_closed", on_rewarded_closed)

func _is_mock_provider_active() -> bool:
    if provider == null:
        return false
    if provider is Node:
        var provider_node: Node = provider as Node
        var provider_script: Script = provider_node.get_script() as Script
        if provider_script != null:
            return provider_script.resource_path == MOCK_PROVIDER_PATH
    return false

func _is_headless_runtime() -> bool:
    return DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server")
