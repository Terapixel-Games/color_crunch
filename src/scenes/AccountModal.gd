extends Control

@onready var status_label: Label = $Panel/VBox/Status
@onready var email_input: LineEdit = $Panel/VBox/Email
@onready var merge_code_input: LineEdit = $Panel/VBox/MergeCode
@onready var username_input: LineEdit = $Panel/VBox/Username
@onready var username_button: Button = $Panel/VBox/UpdateUsername

var _polling_magic_link := false
var _username_cost := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Typography.style_save_streak(self)
	ThemeManager.apply_to_scene(get_tree().current_scene)
	username_input.text = NakamaService.get_username()
	_refresh_username_policy()

func _on_send_magic_link_pressed() -> void:
	var email := email_input.text.strip_edges().to_lower()
	if email.is_empty():
		status_label.text = "Enter an email address."
		return
	status_label.text = "Sending magic link..."
	var result: Dictionary = await NakamaService.start_magic_link(email)
	if not result.get("ok", false):
		status_label.text = "Magic link unavailable."
		return
	status_label.text = "Magic link sent. Check your email."
	if not _polling_magic_link:
		_polling_magic_link = true
		_poll_magic_link_completion()

func _on_create_merge_code_pressed() -> void:
	status_label.text = "Creating merge code..."
	var result: Dictionary = await NakamaService.create_account_merge_code()
	if not result.get("ok", false):
		status_label.text = "Unable to create merge code."
		return
	var data: Dictionary = result.get("data", {})
	var code := str(data.get("merge_code", ""))
	merge_code_input.text = code
	status_label.text = "Merge code ready."

func _on_redeem_merge_code_pressed() -> void:
	var code := merge_code_input.text.strip_edges()
	if code.is_empty():
		status_label.text = "Enter merge code."
		return
	status_label.text = "Redeeming merge code..."
	var result: Dictionary = await NakamaService.redeem_account_merge_code(code)
	if not result.get("ok", false):
		status_label.text = "Merge failed or conflict."
		return
	status_label.text = "Accounts merged."

func _on_close_pressed() -> void:
	queue_free()

func _on_update_username_pressed() -> void:
	var desired := username_input.text.strip_edges().to_lower()
	if desired.is_empty():
		status_label.text = "Enter a username."
		return
	if _username_cost > 0 and NakamaService.get_coin_balance() < _username_cost:
		status_label.text = "Need %d coins to change username." % _username_cost
		return
	status_label.text = "Updating username..."
	var result: Dictionary = await NakamaService.update_username(desired)
	if not result.get("ok", false):
		status_label.text = _extract_error_message(result, "Username update failed.")
		return
	var data: Dictionary = result.get("data", {})
	var changed := bool(data.get("changed", true))
	if changed:
		username_input.text = str(data.get("username", desired))
		if int(data.get("coinCost", 0)) > 0:
			status_label.text = "Username updated. -%d coins." % int(data.get("coinCost", 0))
		else:
			status_label.text = "Username updated."
	else:
		status_label.text = "Username unchanged."
	_refresh_username_policy()

func _poll_magic_link_completion() -> void:
	var attempts := 0
	while is_inside_tree() and _polling_magic_link and attempts < 20:
		attempts += 1
		var result: Dictionary = await NakamaService.get_magic_link_status(true)
		if result.get("ok", false):
			var data: Dictionary = result.get("data", {})
			if bool(data.get("completed", false)):
				var status := str(data.get("status", "ok"))
				status_label.text = "Magic link completed: %s" % status
				_polling_magic_link = false
				return
		await get_tree().create_timer(3.0).timeout
	if _polling_magic_link:
		status_label.text = "Waiting for email link click..."
	_polling_magic_link = false

func _refresh_username_policy() -> void:
	var result: Dictionary = await NakamaService.get_username_status()
	if not result.get("ok", false):
		_username_cost = 0
		username_button.text = "Update Username"
		return
	var data: Dictionary = result.get("data", {})
	var username := str(data.get("username", "")).strip_edges()
	if not username.is_empty():
		username_input.text = username
	var free_available := bool(data.get("freeChangeAvailable", true))
	_username_cost = int(data.get("nextChangeCostCoins", 0))
	if free_available:
		username_button.text = "Set Username (Free)"
	else:
		username_button.text = "Change Username (%d coins)" % _username_cost

func _extract_error_message(result: Dictionary, fallback: String) -> String:
	var body_text := str(result.get("body", ""))
	if body_text.is_empty():
		return fallback
	var parsed: Variant = JSON.parse_string(body_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		var row: Dictionary = parsed
		if row.has("message"):
			return str(row.get("message"))
		if row.has("error"):
			return str(row.get("error"))
	return fallback
