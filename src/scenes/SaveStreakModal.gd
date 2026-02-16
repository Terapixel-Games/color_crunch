extends Control

@onready var status_label: Label = $Center/Panel/VBox/Status
@onready var save_button: Button = $Center/Panel/VBox/SaveButton
@onready var close_button: Button = $Center/Panel/VBox/Close

var _rewarded_success := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	Typography.style_save_streak(self)
	if not save_button.pressed.is_connected(_on_save_pressed):
		save_button.pressed.connect(_on_save_pressed)
	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if not AdManager.rewarded_earned.is_connected(_on_rewarded_earned):
		AdManager.rewarded_earned.connect(_on_rewarded_earned)
	if not AdManager.rewarded_closed.is_connected(_on_rewarded_closed):
		AdManager.rewarded_closed.connect(_on_rewarded_closed)

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		Typography.style_save_streak(self)

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
	queue_free()

func _on_dim_gui_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touch: bool = event is InputEventScreenTouch and event.pressed
	if click or touch:
		_on_close_pressed()

func _on_rewarded_earned() -> void:
	_rewarded_success = true
	status_label.text = "Streak saved!"
	status_label.add_theme_color_override("font_color", Typography.PRIMARY_TEXT)
	queue_free()

func _on_rewarded_closed() -> void:
	if _rewarded_success:
		return
	status_label.text = "Try again later"
	status_label.add_theme_color_override("font_color", Typography.SECONDARY_TEXT)
	save_button.disabled = false
