extends Node

signal interstitial_loaded
signal interstitial_closed
signal rewarded_loaded
signal rewarded_earned
signal rewarded_closed

var interstitial_ready := true
var rewarded_ready := true

func load_interstitial(_ad_unit_id: String) -> void:
    interstitial_ready = true
    emit_signal("interstitial_loaded")

func load_rewarded(_ad_unit_id: String) -> void:
    rewarded_ready = true
    emit_signal("rewarded_loaded")

func show_interstitial(_ad_unit_id: String) -> bool:
    if not interstitial_ready:
        return false
    interstitial_ready = false
    call_deferred("_emit_interstitial_closed")
    return true

func show_rewarded(_ad_unit_id: String) -> bool:
    if not rewarded_ready:
        return false
    rewarded_ready = false
    call_deferred("_emit_rewarded_earned")
    call_deferred("_emit_rewarded_closed")
    return true

func is_rewarded_ready() -> bool:
    return rewarded_ready

func _emit_interstitial_closed() -> void:
    emit_signal("interstitial_closed")

func _emit_rewarded_earned() -> void:
    emit_signal("rewarded_earned")

func _emit_rewarded_closed() -> void:
    emit_signal("rewarded_closed")
