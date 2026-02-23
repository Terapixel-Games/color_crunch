extends Node
class_name UiFx

static func fade_in(node: CanvasItem, duration: float = 0.2) -> Tween:
	if node == null:
		return null
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, max(0.01, duration))
	return tween

static func pop(node: CanvasItem, peak_scale: float = 1.06, duration: float = 0.16) -> Tween:
	if node == null:
		return null
	var base_scale := node.scale
	var tween := node.create_tween()
	tween.tween_property(node, "scale", base_scale * Vector2(peak_scale, peak_scale), duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", base_scale, duration * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

static func slide_from_y(node: Control, offset: float = 18.0, duration: float = 0.22) -> Tween:
	if node == null:
		return null
	var target_y := node.position.y
	node.position.y += offset
	var tween := node.create_tween()
	tween.tween_property(node, "position:y", target_y, max(0.01, duration)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween
