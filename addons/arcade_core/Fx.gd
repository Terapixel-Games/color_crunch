extends Node

const META_BASE_SCALE := &"arcade_fx_base_scale"
const META_PUNCH_TWEEN := &"arcade_fx_punch_tween"
const META_BASE_MODULATE := &"arcade_fx_base_modulate"
const META_FLASH_TWEEN := &"arcade_fx_flash_tween"

var _freeze_until_ms := 0
var _freeze_restore_time_scale := 1.0
var _freeze_active := false

var _shake_until_ms := 0
var _shake_started_ms := 0
var _shake_strength := 0.0
var _camera: Camera2D = null
var _camera_base_offset := Vector2.ZERO

func _ready() -> void:
    # Keep running even while hit-freeze sets Engine.time_scale to 0.
    process_mode = Node.PROCESS_MODE_ALWAYS

func bind_camera(cam: Camera2D) -> void:
    if cam == null:
        return
    _camera = cam
    _camera_base_offset = cam.offset

func impact(freeze_duration: float = 0.04, shake_duration: float = 0.12, shake_strength_px: float = 5.0) -> void:
    hit_freeze(freeze_duration)
    micro_shake(shake_duration, shake_strength_px)

func hit_freeze(duration: float) -> void:
    if duration <= 0.0:
        return

    var now_ms := Time.get_ticks_msec()
    var target_until := now_ms + int(round(duration * 1000.0))
    _freeze_until_ms = max(_freeze_until_ms, target_until)

    if not _freeze_active:
        _freeze_restore_time_scale = Engine.time_scale
        Engine.time_scale = 0.0
        _freeze_active = true

func micro_shake(duration: float, strength_px: float) -> void:
    if duration <= 0.0 or strength_px <= 0.0:
        return

    var now_ms := Time.get_ticks_msec()
    _shake_started_ms = now_ms
    _shake_until_ms = max(_shake_until_ms, now_ms + int(round(duration * 1000.0)))
    _shake_strength = max(_shake_strength, strength_px)

func punch(target: CanvasItem, strength: float = 0.08, press_duration: float = 0.05, release_duration: float = 0.10) -> void:
    if target == null or not is_instance_valid(target):
        return
    if strength <= 0.0:
        return

    var base_scale: Vector2 = target.scale
    if target.has_meta(META_BASE_SCALE):
        var existing := target.get_meta(META_BASE_SCALE)
        if existing is Vector2:
            base_scale = existing
    else:
        target.set_meta(META_BASE_SCALE, base_scale)

    if target.has_meta(META_PUNCH_TWEEN):
        var active_tween := target.get_meta(META_PUNCH_TWEEN)
        if active_tween is Tween and is_instance_valid(active_tween):
            (active_tween as Tween).kill()

    if not target.is_inside_tree():
        target.scale = base_scale
        return

    var tween := target.create_tween()
    target.set_meta(META_PUNCH_TWEEN, tween)
    tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(target, "scale", base_scale * (1.0 + strength), max(0.01, press_duration))
    tween.tween_property(target, "scale", base_scale, max(0.01, release_duration))

func flash(target: CanvasItem, flash_color: Color = Color(1.0, 1.0, 1.0, 0.35), duration: float = 0.14) -> void:
    if target == null or not is_instance_valid(target):
        return

    var base_modulate: Color = target.modulate
    if target.has_meta(META_BASE_MODULATE):
        var existing := target.get_meta(META_BASE_MODULATE)
        if existing is Color:
            base_modulate = existing
    else:
        target.set_meta(META_BASE_MODULATE, base_modulate)

    if target.has_meta(META_FLASH_TWEEN):
        var active_tween := target.get_meta(META_FLASH_TWEEN)
        if active_tween is Tween and is_instance_valid(active_tween):
            (active_tween as Tween).kill()

    if not target.is_inside_tree():
        target.modulate = base_modulate
        return

    var alpha: float = clampf(flash_color.a, 0.0, 1.0)
    var peak: Color = base_modulate.lerp(Color(flash_color.r, flash_color.g, flash_color.b, base_modulate.a), alpha)
    var tween := target.create_tween()
    target.set_meta(META_FLASH_TWEEN, tween)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(target, "modulate", peak, max(0.01, duration * 0.45))
    tween.tween_property(target, "modulate", base_modulate, max(0.01, duration * 0.55))

func _process(_delta: float) -> void:
    var now_ms := Time.get_ticks_msec()
    _update_hit_freeze(now_ms)
    _update_camera_shake(now_ms)

func _update_hit_freeze(now_ms: int) -> void:
    if not _freeze_active:
        return
    if now_ms < _freeze_until_ms:
        return

    Engine.time_scale = _freeze_restore_time_scale
    _freeze_active = false
    _freeze_until_ms = 0
    _freeze_restore_time_scale = 1.0

func _update_camera_shake(now_ms: int) -> void:
    if _camera == null or not is_instance_valid(_camera):
        _camera = null
        return

    if _shake_until_ms > now_ms:
        var total_ms: int = maxi(1, _shake_until_ms - _shake_started_ms)
        var remaining_ms: int = maxi(0, _shake_until_ms - now_ms)
        var falloff: float = clampf(float(remaining_ms) / float(total_ms), 0.0, 1.0)
        var amplitude: float = _shake_strength * falloff
        var ox: float = randf_range(-amplitude, amplitude)
        var oy: float = randf_range(-amplitude, amplitude)
        _camera.offset = _camera_base_offset + Vector2(ox, oy)
    else:
        _shake_until_ms = 0
        _shake_started_ms = 0
        _shake_strength = 0.0
        _camera.offset = _camera_base_offset

func _exit_tree() -> void:
    if _freeze_active:
        Engine.time_scale = _freeze_restore_time_scale
    else:
        Engine.time_scale = 1.0
    _freeze_active = false
    _freeze_until_ms = 0
    _freeze_restore_time_scale = 1.0

    _shake_until_ms = 0
    _shake_started_ms = 0
    _shake_strength = 0.0

    if _camera != null:
        _camera.offset = _camera_base_offset
