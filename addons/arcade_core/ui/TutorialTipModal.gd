extends Control

signal dismissed(do_not_show_again: bool)

@onready var title_label: Label = $Center/Panel/VBox/Title
@onready var message_label: Label = $Center/Panel/VBox/Message
@onready var confirm_button: Button = $Center/Panel/VBox/Confirm
@onready var do_not_show_toggle: CheckButton = $Center/Panel/VBox/DoNotShow

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_apply_optional_style()

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_apply_optional_style()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_emit_and_close()
		get_viewport().set_input_as_handled()

func configure(config: Dictionary) -> void:
	if title_label:
		title_label.text = str(config.get("title", "Tip"))
	if message_label:
		message_label.text = str(config.get("message", ""))
	if confirm_button:
		confirm_button.text = str(config.get("confirm_text", "Got it"))
	if do_not_show_toggle:
		do_not_show_toggle.text = str(config.get("checkbox_text", "Don't show this again"))
		do_not_show_toggle.visible = bool(config.get("show_checkbox", true))
		do_not_show_toggle.button_pressed = false

func _on_confirm_pressed() -> void:
	_emit_and_close()

func _on_dim_gui_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touch: bool = event is InputEventScreenTouch and event.pressed
	if click or touch:
		_emit_and_close()

func _emit_and_close() -> void:
	var do_not_show_again := false
	if do_not_show_toggle and do_not_show_toggle.visible:
		do_not_show_again = do_not_show_toggle.button_pressed
	dismissed.emit(do_not_show_again)
	queue_free()

func _apply_optional_style() -> void:
	var typography := get_node_or_null("/root/Typography")
	if typography and typography.has_method("style_tutorial_tip"):
		typography.call("style_tutorial_tip", self)
