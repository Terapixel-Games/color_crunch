extends Control

@onready var status_label: Label = $Panel/VBox/Status
@onready var backdrop: ColorRect = $Backdrop
@onready var panel: Control = $Panel
@onready var panel_vbox: VBoxContainer = $Panel/VBox
@onready var top_inset: Control = $Panel/VBox/TopInset
@onready var header_title: Label = $Panel/VBox/Header/Title
@onready var header_bar: Control = $Panel/VBox/Header
@onready var scroll_container: ScrollContainer = $Panel/VBox/Scroll
@onready var scroll_content: Control = $Panel/VBox/Scroll/Content
@onready var footer_panel: PanelContainer = $Panel/VBox/Footer
@onready var close_button: Button = $Panel/VBox/Footer/Close
@onready var bottom_inset: Control = $Panel/VBox/BottomInset
@onready var email_input: LineEdit = $Panel/VBox/Scroll/Content/Email
@onready var send_magic_link_button: Button = $Panel/VBox/Scroll/Content/SendMagicLink
@onready var username_header: Control = $Panel/VBox/Scroll/Content/UsernameHeader
@onready var merge_code_input: LineEdit = $Panel/VBox/Scroll/Content/MergeCode
@onready var username_input: LineEdit = $Panel/VBox/Scroll/Content/Username
@onready var username_button: Button = $Panel/VBox/Scroll/Content/UpdateUsername
@onready var merge_header: Control = $Panel/VBox/Scroll/Content/MergeHeader
@onready var merge_create_button: Button = $Panel/VBox/Scroll/Content/CreateMergeCode
@onready var merge_redeem_button: Button = $Panel/VBox/Scroll/Content/RedeemMergeCode

var _polling_magic_link := false
var _username_cost := 0
var _magic_link_token := ""
var _closing := false
var _open_tween: Tween
var _close_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Typography.style_save_streak(self)
	header_title.text = "Account"
	_layout_modal()
	call_deferred("_layout_modal")
	_refresh_panel_pivot()
	call_deferred("_refresh_panel_pivot")
	_play_open_animation()
	ThemeManager.apply_to_scene(get_tree().current_scene)
	username_input.text = NakamaService.get_username()
	_set_merge_section_visible(false)
	_refresh_account_controls()
	if not NakamaService.auth_state_changed.is_connected(_on_auth_state_changed):
		NakamaService.auth_state_changed.connect(_on_auth_state_changed)

func _on_send_magic_link_pressed() -> void:
	if NakamaService.is_linked_account():
		status_label.text = "Logging out..."
		NakamaService.track_client_event("account.logout_clicked", {}, true)
		var logout_result: Dictionary = await NakamaService.logout()
		if not logout_result.get("ok", false):
			status_label.text = "Logout failed. Please try again."
			NakamaService.track_client_event("account.logout_failed_ui", {
				"error": _extract_error_message(logout_result, "unknown"),
			}, true)
			return
		_polling_magic_link = false
		_magic_link_token = ""
		email_input.text = ""
		status_label.text = "Logged out. You are on a guest profile."
		NakamaService.track_client_event("account.logout_completed_ui", {}, true)
		_refresh_account_controls()
		return

	var email := email_input.text.strip_edges().to_lower()
	if email.is_empty():
		status_label.text = "Enter an email address."
		NakamaService.track_client_event("account.magic_link_start_rejected", {
			"reason": "missing_email",
		}, true)
		return
	NakamaService.track_client_event("account.magic_link_start_clicked", {
		"email_domain": _safe_email_domain(email),
	}, true)
	status_label.text = "Sending magic link..."
	var result: Dictionary = await NakamaService.start_magic_link(email)
	if not result.get("ok", false):
		status_label.text = _format_magic_link_error(result)
		NakamaService.track_client_event("account.magic_link_start_failed_ui", {
			"email_domain": _safe_email_domain(email),
			"error": _extract_error_message(result, "unknown"),
		}, true)
		return
	_magic_link_token = _extract_magic_link_token(result)
	status_label.text = "Magic link sent. Check your email."
	NakamaService.track_client_event("account.magic_link_start_success_ui", {
		"email_domain": _safe_email_domain(email),
		"token_returned": not _magic_link_token.is_empty(),
	}, true)
	if not _polling_magic_link:
		_polling_magic_link = true
		_poll_magic_link_completion(_magic_link_token)

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
	if _closing:
		return
	_closing = true
	if is_instance_valid(_open_tween):
		_open_tween.kill()
	_close_tween = create_tween()
	_close_tween.set_parallel(true)
	_close_tween.tween_property(panel, "scale", Vector2(0.98, 0.98), 0.14)
	_close_tween.tween_property(panel, "modulate:a", 0.0, 0.14)
	_close_tween.tween_property(backdrop, "modulate:a", 0.0, 0.14)
	_close_tween.finished.connect(queue_free)

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

func _poll_magic_link_completion(ml_token: String = "") -> void:
	var attempts := 0
	while is_inside_tree() and _polling_magic_link and attempts < 20:
		attempts += 1
		if not ml_token.is_empty():
			var complete_result: Dictionary = await NakamaService.complete_magic_link(ml_token)
			if complete_result.get("ok", false):
				var complete_data: Dictionary = complete_result.get("data", {})
				var complete_status := str(complete_data.get("status", complete_data.get("link_status", ""))).strip_edges().to_lower()
				var completed := bool(complete_data.get("completed", false)) or (not complete_status.is_empty() and complete_status != "pending")
				if completed:
					if complete_status.is_empty():
						complete_status = "ok"
					status_label.text = "Magic link completed: %s" % complete_status
					NakamaService.track_client_event("account.magic_link_completed_ui", {
						"path": "complete_rpc",
						"status": complete_status,
						"attempts": attempts,
					}, true)
					_polling_magic_link = false
					_refresh_account_controls()
					return
		var result: Dictionary = await NakamaService.get_magic_link_status(true)
		if result.get("ok", false):
			var data: Dictionary = result.get("data", {})
			if bool(data.get("completed", false)):
				var status := str(data.get("status", "ok"))
				status_label.text = "Magic link completed: %s" % status
				NakamaService.track_client_event("account.magic_link_completed_ui", {
					"path": "status_rpc",
					"status": status,
					"attempts": attempts,
				}, true)
				_polling_magic_link = false
				_refresh_account_controls()
				return
		await get_tree().create_timer(3.0).timeout
	if _polling_magic_link:
		status_label.text = "Waiting for email link click..."
		NakamaService.track_client_event("account.magic_link_poll_timeout", {
			"attempts": attempts,
			"had_token": not ml_token.is_empty(),
		}, true)
	_polling_magic_link = false

func _refresh_account_controls() -> void:
	var linked := NakamaService.is_linked_account()
	_set_merge_section_visible(false)
	_set_username_section_visible(linked)
	if linked:
		var linked_email := NakamaService.get_linked_email()
		if linked_email.is_empty():
			linked_email = email_input.text.strip_edges().to_lower()
			if not linked_email.is_empty():
				NakamaService.set_linked_email(linked_email)
		if not linked_email.is_empty():
			email_input.text = linked_email
			status_label.text = "Logged in as: %s" % linked_email
		else:
			status_label.text = "Logged in as: linked account"
		email_input.editable = false
		send_magic_link_button.text = "Logout"
		_refresh_username_policy()
	else:
		email_input.editable = true
		send_magic_link_button.text = "Send Magic Link"
		_username_cost = 0
		username_button.text = "Set Username (Free)"
		if status_label.text.begins_with("Logged in as:"):
			status_label.text = "Link account with magic link"
	call_deferred("_layout_modal")

func _set_username_section_visible(visible: bool) -> void:
	if username_header != null:
		username_header.visible = visible
	if username_input != null:
		username_input.visible = visible
	if username_button != null:
		username_button.visible = visible

func _set_merge_section_visible(visible: bool) -> void:
	if merge_header != null:
		merge_header.visible = visible
	if merge_code_input != null:
		merge_code_input.visible = visible
	if merge_create_button != null:
		merge_create_button.visible = visible
	if merge_redeem_button != null:
		merge_redeem_button.visible = visible

func _on_auth_state_changed(_is_authenticated: bool, _user_id: String) -> void:
	if not is_inside_tree():
		return
	_refresh_account_controls()

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
			var err: Variant = row.get("error")
			if typeof(err) == TYPE_DICTIONARY:
				var err_row: Dictionary = err
				if err_row.has("message"):
					return str(err_row.get("message"))
				if err_row.has("code"):
					return str(err_row.get("code"))
			return str(err)
	return fallback

func _format_magic_link_error(result: Dictionary) -> String:
	var message := _extract_error_message(result, "Magic link unavailable.")
	var normalized := message.to_lower()
	if normalized.find("mail relay denied") != -1:
		return "Magic link email failed: relay rejected by SMTP provider."
	if normalized.find("rate limit exceeded") != -1:
		return "Too many attempts. Please wait and try again."
	return message

func _extract_magic_link_token(result: Dictionary) -> String:
	var data_var: Variant = result.get("data", {})
	if typeof(data_var) != TYPE_DICTIONARY:
		return ""
	var data: Dictionary = data_var
	var token := str(data.get("ml_token", data.get("magic_link_token", data.get("token", "")))).strip_edges()
	return token

func _safe_email_domain(email: String) -> String:
	var cleaned := email.strip_edges().to_lower()
	var at_idx := cleaned.find("@")
	if at_idx < 0:
		return ""
	return cleaned.substr(at_idx + 1)

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_layout_modal()
		_refresh_panel_pivot()

func _layout_modal() -> void:
	if panel == null or panel_vbox == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var outer_margin: float = clamp(viewport_size.x * 0.04, 18.0, 28.0)
	var panel_width: float = clamp(viewport_size.x - (outer_margin * 2.0), 420.0, viewport_size.x - 12.0)
	var max_panel_height: float = clamp(viewport_size.y - (outer_margin * 2.0), 520.0, viewport_size.y - 12.0)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(panel_width, max_panel_height)
	panel.position = (viewport_size - panel.size) * 0.5

	var margin_x: float = clamp(panel_width * 0.07, 26.0, 40.0)
	var panel_inner_width: float = max(280.0, panel_width - (margin_x * 2.0))
	var content_inset: float = clamp(panel_inner_width * 0.03, 14.0, 24.0)
	var content_width: float = clamp(panel_inner_width - (content_inset * 2.0), 280.0, panel_inner_width)
	var inside_edge_padding: float = margin_x + content_inset

	if top_inset != null:
		top_inset.custom_minimum_size.y = inside_edge_padding
	if bottom_inset != null:
		bottom_inset.custom_minimum_size.y = inside_edge_padding

	for path in [
		"Panel/VBox/Header",
		"Panel/VBox/Status",
		"Panel/VBox/Scroll",
		"Panel/VBox/Scroll/Content",
		"Panel/VBox/Footer",
	]:
		_apply_centered_content_width(path, content_width)

	if footer_panel != null:
		footer_panel.custom_minimum_size.y = 66.0

	if close_button != null:
		close_button.size_flags_horizontal = Control.SIZE_FILL
		close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		close_button.custom_minimum_size = Vector2(0.0, 54.0)
		close_button.set_anchors_preset(Control.PRESET_FULL_RECT)
		close_button.offset_left = 0.0
		close_button.offset_top = 0.0
		close_button.offset_right = 0.0
		close_button.offset_bottom = 0.0

	var vbox_separation: float = float(panel_vbox.get_theme_constant("separation"))
	var non_scroll_height: float = 0.0
	var visible_vbox_children: int = 0
	for child in panel_vbox.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		visible_vbox_children += 1
		if control == scroll_container:
			continue
		non_scroll_height += control.get_combined_minimum_size().y

	var scroll_content_height: float = 0.0
	if scroll_content != null:
		scroll_content_height = scroll_content.get_combined_minimum_size().y
	if scroll_container != null:
		scroll_container.custom_minimum_size.y = 0.0

	var gap_count: int = max(0, visible_vbox_children - 1)
	var inner_height_target: float = non_scroll_height + scroll_content_height + (vbox_separation * float(gap_count))
	var target_panel_height: float = inner_height_target
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

func _play_open_animation() -> void:
	panel.scale = Vector2(0.98, 0.98)
	panel.modulate.a = 0.0
	backdrop.modulate.a = 0.0
	_open_tween = create_tween()
	_open_tween.set_parallel(true)
	_open_tween.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	_open_tween.tween_property(backdrop, "modulate:a", 1.0, 0.18)

func _exit_tree() -> void:
	if is_instance_valid(_open_tween):
		_open_tween.kill()
	if is_instance_valid(_close_tween):
		_close_tween.kill()
