extends Node

const FeatureFlagsScript := preload("res://src/config/FeatureFlags.gd")
const LOGO_STING_SECONDS := 0.75
var _boot_started_msec: int = Time.get_ticks_msec()

func _ready() -> void:
	if FeatureFlagsScript.clear_high_score_on_boot():
		SaveStore.clear_high_score()
	MusicManager.start_all_synced()
	_play_logo_sting()
	call_deferred("_go_menu")

func _go_menu() -> void:
	await get_tree().create_timer(LOGO_STING_SECONDS).timeout
	Telemetry.mark_scene_loaded("boot", _boot_started_msec)
	RunManager.goto_menu()

func _play_logo_sting() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LogoStingLayer"
	add_child(layer)
	var label := Label.new()
	label.text = "TeraPixel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 1.0))
	label.modulate.a = 0.0
	layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.2)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.finished.connect(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
	)
