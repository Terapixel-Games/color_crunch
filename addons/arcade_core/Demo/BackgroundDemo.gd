extends Node2D

const BACKGROUND_CONTROLLER_SCRIPT := preload("res://addons/arcade_core/Background/AC_BackgroundController.gd")
const BACKGROUND_PROFILES_SCRIPT := preload("res://addons/arcade_core/Background/AC_BackgroundProfiles.gd")

var _background: Node2D
var _playfield_canvas: CanvasLayer
var _playfield_root: Control
var _playfield_rect: ColorRect

var _ui_canvas: CanvasLayer
var _profile_picker: OptionButton
var _combo_slider: HSlider
var _tier_slider: HSlider
var _grid_toggle: CheckBox
var _sweep_toggle: CheckBox
var _flow_toggle: CheckBox

func _ready() -> void:
	_build_background()
	_build_playfield()
	_build_ui()
	_refresh_profile_picker()
	_on_viewport_size_changed()

	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

func _exit_tree() -> void:
	var viewport := get_viewport()
	if viewport != null and viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.disconnect(_on_viewport_size_changed)

func _build_background() -> void:
	_background = BACKGROUND_CONTROLLER_SCRIPT.new()
	_background.name = "BackgroundController"
	_background.initial_profile = "calm_puzzle"
	_background.initial_tier = 1
	add_child(_background)

func _build_playfield() -> void:
	_playfield_canvas = CanvasLayer.new()
	_playfield_canvas.layer = -10
	add_child(_playfield_canvas)

	_playfield_root = Control.new()
	_playfield_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_playfield_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield_canvas.add_child(_playfield_root)

	_playfield_rect = ColorRect.new()
	_playfield_rect.color = Color(0.10, 0.12, 0.18, 0.72)
	_playfield_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield_rect.size = Vector2(680.0, 980.0)
	_playfield_root.add_child(_playfield_rect)

	var frame := ColorRect.new()
	frame.color = Color(0.58, 0.72, 0.95, 0.15)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield_rect.add_child(frame)

func _build_ui() -> void:
	_ui_canvas = CanvasLayer.new()
	_ui_canvas.layer = 100
	add_child(_ui_canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(20.0, 20.0)
	panel.size = Vector2(320.0, 340.0)
	_ui_canvas.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "ArcadeCore Background Demo"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var profile_label := Label.new()
	profile_label.text = "Profile"
	vb.add_child(profile_label)

	_profile_picker = OptionButton.new()
	_profile_picker.item_selected.connect(_on_profile_selected)
	vb.add_child(_profile_picker)

	vb.add_child(_build_slider_row("Combo Intensity", 0.0, 1.0, 0.0, 0.01, _on_combo_changed, true))
	vb.add_child(_build_slider_row("Tier", 1.0, 5.0, 1.0, 1.0, _on_tier_changed, false))

	_grid_toggle = CheckBox.new()
	_grid_toggle.text = "Enable Grid"
	_grid_toggle.button_pressed = false
	_grid_toggle.toggled.connect(func(pressed: bool): _background.set_enabled_layer("grid", pressed))
	vb.add_child(_grid_toggle)

	_sweep_toggle = CheckBox.new()
	_sweep_toggle.text = "Enable Sweep"
	_sweep_toggle.button_pressed = true
	_sweep_toggle.toggled.connect(func(pressed: bool): _background.set_enabled_layer("sweep", pressed))
	vb.add_child(_sweep_toggle)

	_flow_toggle = CheckBox.new()
	_flow_toggle.text = "Enable Flow Particles"
	_flow_toggle.button_pressed = true
	_flow_toggle.toggled.connect(func(pressed: bool): _background.set_enabled_layer("flow_particles", pressed))
	vb.add_child(_flow_toggle)

	var pulse_btn := Button.new()
	pulse_btn.text = "Powerup Pulse"
	pulse_btn.pressed.connect(func(): _background.trigger_powerup_pulse(1.0))
	vb.add_child(pulse_btn)

func _build_slider_row(label_text: String, min_value: float, max_value: float, value: float, step: float, callback: Callable, show_percent: bool) -> Control:
	var wrap := VBoxContainer.new()

	var lbl := Label.new()
	lbl.text = label_text
	wrap.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(slider)

	if show_percent:
		_combo_slider = slider
		slider.value_changed.connect(callback)
	else:
		_tier_slider = slider
		slider.value_changed.connect(callback)
	return wrap

func _refresh_profile_picker() -> void:
	_profile_picker.clear()
	var names: PackedStringArray = BACKGROUND_PROFILES_SCRIPT.list_profile_names(_background.profiles_path)
	for name in names:
		_profile_picker.add_item(name)
	if not names.is_empty():
		var selected := maxi(0, names.find(_background.active_profile_name))
		_profile_picker.select(selected)
		_on_profile_selected(selected)

	_background.set_combo_intensity(0.0)
	_background.set_tier(1)
	_tier_slider.value = 1.0
	_combo_slider.value = 0.0

func _on_profile_selected(index: int) -> void:
	if index < 0 or index >= _profile_picker.item_count:
		return
	var name := _profile_picker.get_item_text(index)
	_background.load_profile(name)
	_grid_toggle.button_pressed = _background.active_profile != null and bool(_background.active_profile.grid.get("enabled", false))
	_sweep_toggle.button_pressed = _background.active_profile != null and bool(_background.active_profile.sweep.get("enabled", true))
	_flow_toggle.button_pressed = _background.active_profile != null and bool(_background.active_profile.flow_particles.get("enabled", true))

func _on_combo_changed(value: float) -> void:
	_background.set_combo_intensity(value)

func _on_tier_changed(value: float) -> void:
	_background.set_tier(int(round(value)))

func _on_viewport_size_changed() -> void:
	if _playfield_root == null:
		return
	var size := get_viewport_rect().size
	_playfield_root.size = size
	var rect_size := Vector2(size.x * 0.62, size.y * 0.72)
	_playfield_rect.size = rect_size
	_playfield_rect.position = (size - rect_size) * 0.5
