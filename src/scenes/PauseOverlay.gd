extends Control

signal resume
signal quit

@onready var panel: Control = $Panel
@onready var modal_vbox: VBoxContainer = $Panel/VBox
@onready var top_inset: Control = $Panel/VBox/TopInset
@onready var title_label: Label = $Panel/VBox/Title
@onready var resume_button: Button = $Panel/VBox/Resume
@onready var quit_button: Button = $Panel/VBox/Quit
@onready var bottom_inset: Control = $Panel/VBox/BottomInset

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	Typography.style_pause_overlay(self)
	_layout_modal()
	call_deferred("_layout_modal")
	_refresh_panel_pivot()
	call_deferred("_refresh_panel_pivot")

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		Typography.style_pause_overlay(self)
		_layout_modal()
		_refresh_panel_pivot()

func _on_resume_pressed() -> void:
	emit_signal("resume")
	queue_free()

func _on_quit_pressed() -> void:
	emit_signal("quit")
	queue_free()

func _layout_modal() -> void:
	if panel == null or modal_vbox == null:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var outer_margin : float = clamp(viewport_size.x * 0.04, 18.0, 28.0)
	var panel_width : float = clamp(viewport_size.x - (outer_margin * 2.0), 320.0, 560.0)
	var max_panel_height : float = clamp(viewport_size.y - (outer_margin * 2.0), 280.0, 560.0)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(panel_width, max_panel_height)
	panel.position = (viewport_size - panel.size) * 0.5

	var margin_x : float = clamp(panel_width * 0.07, 22.0, 34.0)
	var panel_inner_width : float = max(220.0, panel_width - (margin_x * 2.0))
	var content_inset : float = clamp(panel_inner_width * 0.03, 12.0, 20.0)
	var content_width : float = clamp(panel_inner_width - (content_inset * 2.0), 220.0, panel_inner_width)
	var inside_edge_padding := margin_x + content_inset

	if top_inset != null:
		top_inset.custom_minimum_size.y = inside_edge_padding
	if bottom_inset != null:
		bottom_inset.custom_minimum_size.y = inside_edge_padding

	_apply_centered_content_width("Panel/VBox/Title", content_width)
	_apply_centered_content_width("Panel/VBox/Resume", content_width)
	_apply_centered_content_width("Panel/VBox/Quit", content_width)

	var button_height : float = clamp(max_panel_height * 0.18, 84.0, 108.0)
	if resume_button != null:
		resume_button.custom_minimum_size.y = button_height
	if quit_button != null:
		quit_button.custom_minimum_size.y = button_height

	var vbox_separation := float(modal_vbox.get_theme_constant("separation"))
	var total_height := 0.0
	var visible_children := 0
	for child in modal_vbox.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		visible_children += 1
		total_height += control.get_combined_minimum_size().y

	var gap_count : int = max(0, visible_children - 1)
	var target_panel_height := total_height + (vbox_separation * float(gap_count))
	panel.size = Vector2(panel_width, min(target_panel_height, max_panel_height))
	panel.position = (viewport_size - panel.size) * 0.5

func _apply_centered_content_width(path: String, width: float) -> void:
	var control := get_node_or_null(path) as Control
	if control == null:
		return
	control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	control.custom_minimum_size.x = width

func _refresh_panel_pivot() -> void:
	if panel == null:
		return
	if panel.size.x <= 0.0 or panel.size.y <= 0.0:
		return
	panel.pivot_offset = panel.size * 0.5
