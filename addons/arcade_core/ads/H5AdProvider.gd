extends Node

signal interstitial_loaded
signal interstitial_closed
signal rewarded_loaded
signal rewarded_earned
signal rewarded_closed

const DEFAULT_INTERSTITIAL_NAME := "arcadecore_interstitial"
const DEFAULT_REWARDED_NAME := "arcadecore_rewarded"

var _bridge: Object = null
var _interstitial_active := false
var _rewarded_active := false
var _rewarded_viewed := false
var _callbacks: Array = []

func is_supported_environment() -> bool:
	if not OS.has_feature("web"):
		return false
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
	var javascript_bridge: Object = Engine.get_singleton("JavaScriptBridge")
	if javascript_bridge == null or not javascript_bridge.has_method("get_interface"):
		return false
	var h5_bridge: Object = javascript_bridge.call("get_interface", "arcadecoreH5Ads")
	return h5_bridge != null

func requires_ad_unit_ids() -> bool:
	return false

func initialize(_app_id: String) -> void:
	_bridge = _get_h5_bridge()
	if _bridge != null and _bridge.has_method("configure"):
		_bridge.call("configure", true)

func load_interstitial(_ad_unit_id: String) -> void:
	if _get_h5_bridge() != null:
		emit_signal("interstitial_loaded")

func load_rewarded(_ad_unit_id: String) -> void:
	if _get_h5_bridge() != null:
		emit_signal("rewarded_loaded")

func show_interstitial(ad_unit_id: String) -> bool:
	var h5_bridge := _get_h5_bridge()
	if h5_bridge == null or _interstitial_active or _rewarded_active:
		return false

	_interstitial_active = true
	var placement_name := _placement_name(ad_unit_id, DEFAULT_INTERSTITIAL_NAME)
	var before_ad := _keep_callback(Callable(self, "_on_interstitial_before_ad"))
	var after_ad := _keep_callback(Callable(self, "_on_interstitial_after_ad"))
	var done := _keep_callback(Callable(self, "_on_interstitial_done"))
	var accepted := bool(h5_bridge.call("showInterstitial", placement_name, before_ad, after_ad, done))
	if not accepted:
		_interstitial_active = false
		_release_callbacks()
	return accepted

func show_rewarded(ad_unit_id: String) -> bool:
	var h5_bridge := _get_h5_bridge()
	if h5_bridge == null or _rewarded_active or _interstitial_active:
		return false

	_rewarded_active = true
	_rewarded_viewed = false
	var placement_name := _placement_name(ad_unit_id, DEFAULT_REWARDED_NAME)
	var before_ad := _keep_callback(Callable(self, "_on_rewarded_before_ad"))
	var after_ad := _keep_callback(Callable(self, "_on_rewarded_after_ad"))
	var dismissed := _keep_callback(Callable(self, "_on_rewarded_dismissed"))
	var viewed := _keep_callback(Callable(self, "_on_rewarded_viewed"))
	var done := _keep_callback(Callable(self, "_on_rewarded_done"))
	var accepted := bool(h5_bridge.call("showRewarded", placement_name, before_ad, after_ad, dismissed, viewed, done))
	if not accepted:
		_rewarded_active = false
		_rewarded_viewed = false
		_release_callbacks()
	return accepted

func is_rewarded_ready() -> bool:
	return _get_h5_bridge() != null and not _rewarded_active and not _interstitial_active

func _get_h5_bridge() -> Object:
	if _bridge != null:
		return _bridge
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return null
	var javascript_bridge: Object = Engine.get_singleton("JavaScriptBridge")
	if javascript_bridge == null or not javascript_bridge.has_method("get_interface"):
		return null
	_bridge = javascript_bridge.call("get_interface", "arcadecoreH5Ads")
	return _bridge

func _keep_callback(callable: Callable) -> Variant:
	var javascript_bridge: Object = Engine.get_singleton("JavaScriptBridge")
	var callback: Variant = javascript_bridge.call("create_callback", callable)
	_callbacks.append(callback)
	return callback

func _release_callbacks() -> void:
	_callbacks.clear()

func _placement_name(ad_unit_id: String, fallback: String) -> String:
	var clean := ad_unit_id.strip_edges()
	return fallback if clean.is_empty() else clean

func _on_interstitial_before_ad(_args: Array) -> void:
	pass

func _on_interstitial_after_ad(_args: Array) -> void:
	pass

func _on_interstitial_done(_args: Array) -> void:
	_interstitial_active = false
	emit_signal("interstitial_closed")
	_release_callbacks()

func _on_rewarded_before_ad(_args: Array) -> void:
	pass

func _on_rewarded_after_ad(_args: Array) -> void:
	pass

func _on_rewarded_dismissed(_args: Array) -> void:
	_rewarded_viewed = false

func _on_rewarded_viewed(_args: Array) -> void:
	_rewarded_viewed = true
	emit_signal("rewarded_earned")

func _on_rewarded_done(_args: Array) -> void:
	_rewarded_active = false
	_rewarded_viewed = false
	emit_signal("rewarded_closed")
	_release_callbacks()
