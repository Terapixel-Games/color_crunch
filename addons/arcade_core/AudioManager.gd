extends Node

@export var sfx_bus := "SFX"
@export var pool_size := 8
@export var default_sfx_volume_db := 0.0

var _players: Array[AudioStreamPlayer] = []
var _idx := 0

func _ready() -> void:
    _ensure_bus_exists(sfx_bus)
    for i in range(pool_size):
        var p := AudioStreamPlayer.new()
        p.bus = sfx_bus
        add_child(p)
        _players.append(p)

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
    if stream == null or _players.is_empty():
        return
    if not bool(SaveManager.get_setting("sfx_enabled", true)):
        return

    var p := _players[_idx]
    _idx = (_idx + 1) % _players.size()

    p.stop()
    p.stream = stream
    p.volume_db = default_sfx_volume_db + volume_db
    p.pitch_scale = pitch
    p.play()

func stop_all_sfx() -> void:
    for p in _players:
        p.stop()

func set_sfx_enabled(enabled: bool) -> void:
    SaveManager.set_setting("sfx_enabled", enabled)

func set_music_enabled(enabled: bool) -> void:
    SaveManager.set_setting("music_enabled", enabled)
    var bus_idx := AudioServer.get_bus_index("Music")
    if bus_idx != -1:
        AudioServer.set_bus_mute(bus_idx, not enabled)

func is_sfx_enabled() -> bool:
    return bool(SaveManager.get_setting("sfx_enabled", true))

func is_music_enabled() -> bool:
    return bool(SaveManager.get_setting("music_enabled", true))

func _ensure_bus_exists(bus_name: String) -> void:
    if AudioServer.get_bus_index(bus_name) != -1:
        return
    var idx := AudioServer.get_bus_count()
    AudioServer.add_bus(idx)
    AudioServer.set_bus_name(idx, bus_name)
