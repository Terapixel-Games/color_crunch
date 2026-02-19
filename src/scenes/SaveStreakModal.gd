extends Control

@onready var panel: Control = $Center/Panel
@onready var modal_vbox: VBoxContainer = $Center/Panel/VBox
@onready var top_inset: Control = $Center/Panel/VBox/TopInset
@onready var status_label: Label = $Center/Panel/VBox/Status
@onready var save_button: Button = $Center/Panel/VBox/SaveButton
@onready var close_button: Button = $Center/Panel/VBox/Close
@onready var bottom_inset: Control = $Center/Panel/VBox/BottomInset

var _rewarded_success := false
var _is_closing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	Typography.style_save_streak(self)
	_layout_modal()
	call_deferred("_layout_modal")
	_refresh_panel_pivot()
	call_deferred("_refresh_panel_pivot")
	if not save_button.pressed.is_connected(_on_save_pressed):
		save_button.pressed.connect(_on_save_pressed)
	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if not AdManager.rewarded_earned.is_connected(_on_rewarded_earned):
		AdManager.rewarded_earned.connect(_on_rewarded_earned)
	if not AdManager.rewarded_closed.is_connected(_on_rewarded_closed):
		AdManager.rewarded_closed.connect(_on_rewarded_closed)

func _exit_tree() -> void:
	if save_button and save_button.pressed.is_connected(_on_save_pressed):
		save_button.pressed.disconnect(_on_save_pressed)
	if close_button and close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.disconnect(_on_close_pressed)
	if AdManager.rewarded_earned.is_connected(_on_rewarded_earned):
		AdManager.rewarded_earned.disconnect(_on_rewarded_earned)
	if AdManager.rewarded_closed.is_connected(_on_rewarded_closed):
		AdManager.rewarded_closed.disconnect(_on_rewarded_closed)

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		Typography.style_save_streak(self)
		_layout_modal()
		_refresh_panel_pivot()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_save_pressed() -> void:
	status_label.text = "Loading ad..."
	status_label.add_theme_color_override("font_color", Typography.SECONDARY_TEXT)
	save_button.disabled = true
	if not AdManager.show_rewarded_for_save():
		status_label.text = "Ad not ready"
		status_label.add_theme_color_override("font_color", Typography.SECONDARY_TEXT)
		save_button.disabled = false

func _on_close_pressed() -> void:
	_request_close()

func _on_dim_gui_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touch: bool = event is InputEventScreenTouch and event.pressed
	if click or touch:
		_on_close_pressed()

func _on_rewarded_earned() -> void:
	if _is_closing:
		return
	_rewarded_success = true
	status_label.text = "Streak saved!"
	status_label.add_theme_color_override("font_color", Typography.PRIMARY_TEXT)
	_request_close()

func _on_rewarded_closed() -> void:
	if _is_closing:
		return
	if _rewarded_success:
		return
	status_label.text = "Try again later"
	status_label.add_theme_color_override("font_color", Typography.SECONDARY_TEXT)
	save_button.disabled = false

func _request_close() -> void:
	if _is_closing:
		return
	_is_closing = true
	call_deferred("_close_now")

func _close_now() -> void:
	if not is_inside_tree():
		return
	queue_free()

func _layout_modal() -> void:
	if panel == null or modal_vbox == null:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var outer_margin : float = clamp(viewport_size.x * 0.04, 18.0, 28.0)
	var panel_width : float = clamp(viewport_size.x - (outer_margin * 2.0), 420.0, 640.0)
	var max_panel_height : float = clamp(viewport_size.y - (outer_margin * 2.0), 320.0, 760.0)
	var margin_x : float = clamp(panel_width * 0.07, 24.0, 36.0)
	var panel_inner_width : float = max(260.0, panel_width - (margin_x * 2.0))
	var content_inset : float = clamp(panel_inner_width * 0.03, 12.0, 20.0)
	var content_width : float = clamp(panel_inner_width - (content_inset * 2.0), 260.0, panel_inner_width)
	var inside_edge_padding := margin_x + content_inset

	modal_vbox.offset_left = margin_x
	modal_vbox.offset_top = 0.0
	modal_vbox.offset_right = -margin_x
	modal_vbox.offset_bottom = 0.0

	if top_inset != null:
		top_inset.custom_minimum_size.y = inside_edge_padding
	if bottom_inset != null:
		bottom_inset.custom_minimum_size.y = inside_edge_padding

	_apply_centered_content_width("Center/Panel/VBox/Title", content_width)
	_apply_centered_content_width("Center/Panel/VBox/Status", content_width)
	_apply_centered_content_width("Center/Panel/VBox/SaveButton", content_width)
	_apply_centered_content_width("Center/Panel/VBox/Close", content_width)

	var button_height : float = clamp(max_panel_height * 0.15, 84.0, 108.0)
	if save_button != null:
		save_button.custom_minimum_size.y = button_height
	if close_button != null:
		close_button.custom_minimum_size.y = button_height

	var vbox_separation := float(modal_vbox.get_theme_constant("separation"))
	var total_height := 0.0
	var visible_children := 0
	for child in modal_vbox.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		visible_children += 1
		total_height += control.get_combined_minimum_size().y

	var gap_count : float = max(0, visible_children - 1)
	var target_panel_height := total_height + (vbox_separation * float(gap_count))
	var panel_height : float = min(target_panel_height, max_panel_height)
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.size = panel.custom_minimum_size

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
