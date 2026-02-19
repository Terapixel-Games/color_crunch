extends Node2D
class_name BoardView

signal match_made(group: Array)
signal no_moves
signal move_committed(group: Array, snapshot: Array)
signal match_click_haptic_triggered(duration_ms: int, amplitude: float)
signal match_haptic_triggered(duration_ms: int, amplitude: float)

@export var width := 4
@export var height := 4
@export var colors := 16
@export var tile_size := 128.0

const LEVEL_NAMES := [
	"",
	"MINT",
	"LIME",
	"SPRING",
	"AQUA",
	"SKY",
	"AZURE",
	"INDIGO",
	"VIOLET",
	"MAGENTA",
	"ROSE",
	"CORAL",
	"EMBER",
	"AMBER",
	"SOLAR",
	"LUMA",
	"NOVA",
	"QUASAR",
]

const TILE_PALETTE_MODERN := [
	Color(0.56, 0.95, 0.86, 0.82),
	Color(0.52, 0.96, 0.62, 0.84),
	Color(0.50, 0.93, 0.56, 0.86),
	Color(0.46, 0.88, 0.96, 0.86),
	Color(0.44, 0.78, 0.98, 0.88),
	Color(0.46, 0.67, 0.99, 0.88),
	Color(0.54, 0.58, 1.0, 0.88),
	Color(0.66, 0.54, 1.0, 0.9),
	Color(0.78, 0.50, 1.0, 0.9),
	Color(0.93, 0.48, 0.97, 0.9),
	Color(1.0, 0.50, 0.84, 0.9),
	Color(1.0, 0.55, 0.69, 0.92),
	Color(1.0, 0.63, 0.52, 0.92),
	Color(1.0, 0.75, 0.41, 0.92),
	Color(1.0, 0.86, 0.34, 0.92),
	Color(1.0, 0.95, 0.43, 0.94),
]

const TILE_PALETTE_LEGACY := [
	Color(0.62, 0.90, 0.84, 0.76),
	Color(0.58, 0.92, 0.66, 0.78),
	Color(0.54, 0.88, 0.60, 0.78),
	Color(0.54, 0.84, 0.94, 0.8),
	Color(0.52, 0.74, 0.96, 0.82),
	Color(0.56, 0.67, 0.96, 0.82),
	Color(0.64, 0.61, 0.96, 0.82),
	Color(0.72, 0.58, 0.96, 0.84),
	Color(0.82, 0.56, 0.96, 0.84),
	Color(0.90, 0.54, 0.92, 0.84),
	Color(0.96, 0.56, 0.84, 0.86),
	Color(0.96, 0.60, 0.76, 0.86),
	Color(0.98, 0.66, 0.66, 0.86),
	Color(0.99, 0.74, 0.58, 0.88),
	Color(1.0, 0.82, 0.54, 0.88),
	Color(1.0, 0.90, 0.60, 0.9),
]

const EMPTY_TILE_COLOR := Color(0.16, 0.22, 0.34, 0.34)

var board: Board
var tiles: Array = []
var _animating: bool = false
var _game_over_emitted: bool = false
var _hint_timer: Timer
var _hint_tween: Tween
var _hint_group: Array = []
var _tile_gap_px: float = 8.0
var _hints_enabled: bool = true

var _touch_active: bool = false
var _touch_start: Vector2 = Vector2.ZERO

var _last_move_score: int = 0
var _last_merge_count: int = 0
var _theme_tile_palette: Array = []

func _ready() -> void:
	_tile_gap_px = _gap_for_tile_size(tile_size)
	var board_seed: int = 1234 if FeatureFlags.is_visual_test_mode() else -1
	colors = _palette_size()
	board = Board.new(width, height, colors, board_seed, 2, _palette_size())
	_create_tiles()
	_refresh_tiles()
	queue_redraw()
	_setup_hint_timer()
	_check_no_moves_and_emit()

func set_tile_size(new_size: float) -> void:
	var target: float = max(72.0, new_size)
	if absf(target - tile_size) < 0.1:
		return
	tile_size = target
	_tile_gap_px = _gap_for_tile_size(tile_size)
	if board == null:
		return
	_rebuild_tiles_from_grid()

func set_theme_palette(theme_palette: Array) -> void:
	_theme_tile_palette = theme_palette.duplicate(true)
	if board == null:
		return
	_refresh_tiles()
	queue_redraw()

func _gap_for_tile_size(size: float) -> float:
	return clamp(size * 0.08, 7.0, 12.0)

func _create_tiles() -> void:
	tiles.clear()
	for y in range(height):
		var row: Array = []
		for x in range(width):
			var tile: ColorRect = _create_tile_node(Vector2i(x, y), EMPTY_TILE_COLOR)
			row.append(tile)
		tiles.append(row)

func _input(event: InputEvent) -> void:
	if _animating:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		match key_event.keycode:
			KEY_LEFT, KEY_A:
				_attempt_move(Vector2i.LEFT)
			KEY_RIGHT, KEY_D:
				_attempt_move(Vector2i.RIGHT)
			KEY_UP, KEY_W:
				_attempt_move(Vector2i.UP)
			KEY_DOWN, KEY_S:
				_attempt_move(Vector2i.DOWN)

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_touch_active = true
			_touch_start = touch_event.position
		else:
			if _touch_active:
				_touch_active = false
				_attempt_move(_direction_from_delta(touch_event.position - _touch_start))

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed:
			_touch_active = true
			_touch_start = mouse_event.position
		else:
			if _touch_active:
				_touch_active = false
				_attempt_move(_direction_from_delta(mouse_event.position - _touch_start))

func _direction_from_delta(delta: Vector2) -> Vector2i:
	if delta.length() < max(20.0, tile_size * 0.2):
		return Vector2i.ZERO
	if absf(delta.x) >= absf(delta.y):
		return Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP

func _attempt_move(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	if not _check_no_moves_and_emit():
		return

	_trigger_match_click_haptic()
	_animating = true
	_clear_hint()

	var snapshot: Array = board.snapshot()
	var result: Dictionary = board.move(direction)
	if not bool(result.get("moved", false)):
		_animating = false
		_restart_hint_timer()
		return

	var merge_positions: Array = result.get("merge_positions", [])
	var spawn_position: Vector2i = result.get("spawn_position", Vector2i(-1, -1))
	_last_move_score = int(result.get("score_gain", 0))
	_last_merge_count = merge_positions.size()

	await _animate_board_update(merge_positions, spawn_position)
	emit_signal("move_committed", merge_positions, snapshot)
	if _last_merge_count > 0:
		emit_signal("match_made", merge_positions)
		_trigger_match_haptic()

	if _check_no_moves_and_emit():
		_restart_hint_timer()
	_animating = false

func consume_last_move_score() -> int:
	var gained: int = _last_move_score
	_last_move_score = 0
	return gained

func capture_snapshot() -> Array:
	return board.snapshot()

func restore_snapshot(snapshot_grid: Array) -> void:
	_clear_hint()
	board.restore(snapshot_grid)
	_game_over_emitted = false
	_refresh_tiles()
	if _check_no_moves_and_emit():
		_restart_hint_timer()

func apply_shuffle_powerup() -> bool:
	if _animating:
		return false
	_animating = true
	_clear_hint()
	await _animate_powerup_charge(Color(0.7, 0.95, 1.0, 1.0))
	var before: Array = board.snapshot()
	board.shuffle_tiles()
	var changed: bool = before != board.snapshot()
	_refresh_tiles()
	await _animate_powerup_release()
	if _check_no_moves_and_emit():
		_restart_hint_timer()
	_animating = false
	return changed

func apply_remove_color_powerup(color_idx: int = -1) -> Dictionary:
	if _animating:
		return {"removed": 0, "color_idx": -1}
	var target_level: int = color_idx if color_idx > 0 else _best_removal_level()
	if target_level <= 0:
		return {"removed": 0, "color_idx": -1}

	var removed_cells: Array = _positions_for_level(target_level)
	if removed_cells.is_empty():
		return {"removed": 0, "color_idx": -1}

	_animating = true
	_clear_hint()
	VFXManager.play_prism_clear(removed_cells, tile_size, global_position, posmod(target_level - 1, _palette_size()))

	var fade: Tween = create_tween()
	fade.set_parallel(true)
	for p in removed_cells:
		var tile: ColorRect = tiles[p.y][p.x]
		fade.tween_property(tile, "scale", Vector2(1.2, 1.2), 0.12)
		fade.tween_property(tile, "modulate:a", 0.0, 0.16)
	await fade.finished

	var removed: int = board.remove_color(target_level)
	_refresh_tiles()
	await _animate_powerup_release()
	if _check_no_moves_and_emit():
		_restart_hint_timer()
	_animating = false
	return {"removed": removed, "color_idx": target_level}

func _refresh_tiles() -> void:
	for y in range(height):
		for x in range(width):
			var tile: ColorRect = tiles[y][x]
			var level: int = int(board.grid[y][x])
			_apply_tile_visual(tile, level)
			tile.modulate = Color(1, 1, 1, 1)
			tile.scale = Vector2.ONE
			tile.rotation_degrees = 0.0
			tile.z_index = 0
			tile.position = _tile_origin(Vector2i(x, y))
			var mat: ShaderMaterial = tile.material
			if mat:
				mat.set_shader_parameter("blur_radius", _blur_radius())

func _create_tile_node(cell: Vector2i, color: Color) -> ColorRect:
	var tile := ColorRect.new()
	var visual_size: float = max(12.0, tile_size - _tile_gap_px)
	tile.size = Vector2(visual_size, visual_size)
	tile.pivot_offset = tile.size * 0.5
	tile.position = _tile_origin(cell)
	tile.color = color
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/visual/TileGlass.gdshader")
	mat.set_shader_parameter("tint_color", color)
	mat.set_shader_parameter("blur_radius", _blur_radius())
	_apply_tile_design_shader_profile(mat)
	tile.material = mat

	var label := Label.new()
	label.name = "NameLabel"
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_constant_override("outline_size", 2)
	tile.add_child(label)

	add_child(tile)
	return tile

func _rebuild_tiles_from_grid() -> void:
	for row in tiles:
		for tile in row:
			var tile_node: ColorRect = tile as ColorRect
			if is_instance_valid(tile_node):
				tile_node.queue_free()
	tiles.clear()
	_create_tiles()
	_refresh_tiles()
	queue_redraw()

func _animate_board_update(merge_positions: Array, spawn_position: Vector2i) -> void:
	var fade: Tween = create_tween()
	fade.set_parallel(true)
	for row in tiles:
		for tile in row:
			var tile_node: ColorRect = tile as ColorRect
			fade.tween_property(tile_node, "modulate:a", 0.82, 0.05)
	await fade.finished

	_refresh_tiles()

	var pop: Tween = create_tween()
	pop.set_parallel(true)
	for row in tiles:
		for tile in row:
			var tile_node: ColorRect = tile as ColorRect
			tile_node.modulate.a = 0.86
			pop.tween_property(tile_node, "modulate:a", 1.0, 0.12)

	for p in merge_positions:
		if p.y < 0 or p.y >= tiles.size() or p.x < 0 or p.x >= tiles[p.y].size():
			continue
		var merged_tile: ColorRect = tiles[p.y][p.x]
		merged_tile.scale = Vector2(1.18, 1.18)
		pop.tween_property(merged_tile, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if spawn_position.x >= 0 and spawn_position.y >= 0 and spawn_position.y < tiles.size() and spawn_position.x < tiles[spawn_position.y].size():
		var spawned_tile: ColorRect = tiles[spawn_position.y][spawn_position.x]
		spawned_tile.scale = Vector2(0.7, 0.7)
		pop.tween_property(spawned_tile, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await pop.finished

func _apply_tile_visual(tile: ColorRect, level: int) -> void:
	var color: Color = _color_from_level(level)
	_apply_tile_color(tile, color)
	var label: Label = tile.get_node("NameLabel") as Label
	if label == null:
		return
	label.text = _label_for_level(level)
	label.add_theme_color_override("font_color", _font_color_for_level(level))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.09, 0.16, 0.9))
	var size: int = int(clamp(tile_size * 0.18, 18.0, 40.0))
	if label.text.length() > 8:
		size = int(size * 0.8)
	label.add_theme_font_size_override("font_size", size)

func _color_from_level(level: int) -> Color:
	if level <= 0:
		return EMPTY_TILE_COLOR
	var palette: Array = _tile_palette()
	return palette[posmod(level - 1, palette.size())]

func _label_for_level(level: int) -> String:
	if level <= 0:
		return ""
	if level < LEVEL_NAMES.size():
		return LEVEL_NAMES[level]
	return "PRISM %d" % level

func _font_color_for_level(level: int) -> Color:
	if level <= 0:
		return Color(0.72, 0.78, 0.86, 0.7)
	if level >= 11:
		return Color(0.12, 0.1, 0.08, 0.95)
	return Color(0.06, 0.12, 0.2, 0.95)

func _apply_tile_color(tile: ColorRect, color: Color) -> void:
	tile.color = color
	var mat: ShaderMaterial = tile.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("tint_color", color)

func _blur_radius() -> float:
	return 2.0 if FeatureFlags.tile_blur_mode() == FeatureFlags.TileBlurMode.LITE else 6.0

func _check_no_moves_and_emit() -> bool:
	if board.has_move():
		return true
	_clear_hint()
	if _hint_timer:
		_hint_timer.stop()
	if not _game_over_emitted:
		_game_over_emitted = true
		emit_signal("no_moves")
	return false

func _setup_hint_timer() -> void:
	_hint_timer = Timer.new()
	_hint_timer.one_shot = true
	_hint_timer.wait_time = max(0.1, FeatureFlags.match_hint_delay_seconds())
	add_child(_hint_timer)
	_hint_timer.timeout.connect(_on_hint_timeout)
	if _hints_enabled:
		_restart_hint_timer()

func _restart_hint_timer() -> void:
	if _hint_timer == null:
		return
	if not _hints_enabled:
		_hint_timer.stop()
		return
	_hint_timer.stop()
	_hint_timer.wait_time = max(0.1, FeatureFlags.match_hint_delay_seconds())
	_hint_timer.start()

func _on_hint_timeout() -> void:
	if not _hints_enabled:
		return
	if _animating or _game_over_emitted:
		if _animating:
			_restart_hint_timer()
		return
	if not board.has_move():
		_check_no_moves_and_emit()
		return
	var hint := _find_hint_group()
	if hint.is_empty():
		_restart_hint_timer()
		return
	_apply_hint(hint)
	_restart_hint_timer()

func _find_hint_group() -> Array:
	for y in range(height):
		for x in range(width):
			var v: int = int(board.grid[y][x])
			if v <= 0:
				continue
			if x + 1 < width and int(board.grid[y][x + 1]) == v:
				return [Vector2i(x, y), Vector2i(x + 1, y)]
			if y + 1 < height and int(board.grid[y + 1][x]) == v:
				return [Vector2i(x, y), Vector2i(x, y + 1)]
	return []

func _apply_hint(group: Array) -> void:
	_clear_hint()
	_hint_group = group.duplicate()
	var speed_mul: float = FeatureFlags.hint_pulse_speed_multiplier()
	var beat_seconds: float = (60.0 / max(1.0, float(FeatureFlags.BPM))) / speed_mul
	var attack: float = beat_seconds * 0.42
	var release: float = beat_seconds * 0.33
	var settle: float = beat_seconds * 0.25
	_hint_tween = create_tween()
	_hint_tween.set_loops()
	for p in _hint_group:
		var tile: ColorRect = tiles[p.y][p.x]
		tile.z_index = 200
		tile.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_hint_tween.parallel().tween_property(tile, "scale", Vector2(1.25, 1.25), attack).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hint_tween.chain()
	for p in _hint_group:
		var tile: ColorRect = tiles[p.y][p.x]
		_hint_tween.parallel().tween_property(tile, "scale", Vector2(0.9, 0.9), release)
	_hint_tween.chain()
	for p in _hint_group:
		var tile: ColorRect = tiles[p.y][p.x]
		_hint_tween.parallel().tween_property(tile, "scale", Vector2.ONE, settle).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _clear_hint() -> void:
	if is_instance_valid(_hint_tween):
		_hint_tween.kill()
	_hint_tween = null
	for p in _hint_group:
		if p.y >= 0 and p.y < tiles.size() and p.x >= 0 and p.x < tiles[p.y].size():
			var tile: ColorRect = tiles[p.y][p.x]
			if is_instance_valid(tile):
				tile.scale = Vector2.ONE
				tile.modulate = Color(1.0, 1.0, 1.0, 1.0)
				tile.rotation_degrees = 0.0
				tile.z_index = 0
	_hint_group.clear()

func set_hints_enabled(enabled: bool) -> void:
	if _hints_enabled == enabled:
		return
	_hints_enabled = enabled
	if not _hints_enabled:
		_clear_hint()
		if _hint_timer:
			_hint_timer.stop()
		return
	if _check_no_moves_and_emit():
		_restart_hint_timer()

func _best_removal_level() -> int:
	var counts: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var level: int = int(board.grid[y][x])
			if level <= 0:
				continue
			counts[level] = int(counts.get(level, 0)) + 1
	var best_level := -1
	var best_count := 0
	for level in counts.keys():
		var count: int = int(counts[level])
		if count > best_count:
			best_count = count
			best_level = int(level)
	return best_level

func _positions_for_level(level: int) -> Array:
	var out: Array = []
	for y in range(height):
		for x in range(width):
			if int(board.grid[y][x]) == level:
				out.append(Vector2i(x, y))
	return out

func _palette_size() -> int:
	return _tile_palette().size()

func _tile_palette() -> Array:
	if _theme_tile_palette.size() >= 3:
		return _theme_tile_palette
	return TILE_PALETTE_LEGACY if FeatureFlags.tile_design_mode() == FeatureFlags.TileDesignMode.LEGACY else TILE_PALETTE_MODERN

func _apply_tile_design_shader_profile(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	if FeatureFlags.tile_design_mode() == FeatureFlags.TileDesignMode.LEGACY:
		mat.set_shader_parameter("corner_radius", 0.06)
		mat.set_shader_parameter("border", 0.055)
		mat.set_shader_parameter("tint_mix", 0.92)
		mat.set_shader_parameter("saturation_boost", 1.14)
		mat.set_shader_parameter("bg_luma_mix", 0.32)
		mat.set_shader_parameter("specular_strength", 0.24)
		mat.set_shader_parameter("inner_shadow_strength", 0.3)
		mat.set_shader_parameter("edge_color", Color(0.84, 0.9, 1.0, 0.4))
	else:
		mat.set_shader_parameter("corner_radius", 0.11)
		mat.set_shader_parameter("border", 0.08)
		mat.set_shader_parameter("tint_mix", 1.0)
		mat.set_shader_parameter("saturation_boost", 1.3)
		mat.set_shader_parameter("bg_luma_mix", 0.14)
		mat.set_shader_parameter("specular_strength", 0.36)
		mat.set_shader_parameter("inner_shadow_strength", 0.34)
		mat.set_shader_parameter("edge_color", Color(0.88, 0.95, 1.0, 0.54))

func _normalize_board_color_ids() -> void:
	# Kept for compatibility with older tests; not needed in the 2048 model.
	pass

func _tile_origin(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x * tile_size) + (_tile_gap_px * 0.5),
		(cell.y * tile_size) + (_tile_gap_px * 0.5)
	)

func _draw() -> void:
	var board_size: Vector2 = Vector2(width * tile_size, height * tile_size)
	var glow_rect := Rect2(Vector2(-14.0, -14.0), board_size + Vector2(28.0, 28.0))
	draw_rect(glow_rect, Color(0.62, 0.78, 1.0, 0.08), true)
	var frame_rect := Rect2(Vector2(-6.0, -6.0), board_size + Vector2(12.0, 12.0))
	draw_rect(frame_rect, Color(0.2, 0.32, 0.58, 0.2), true)
	draw_rect(frame_rect, Color(1.0, 1.0, 1.0, 0.2), false, 1.0)

func _animate_powerup_charge(tint: Color) -> void:
	var t: Tween = create_tween()
	t.set_parallel(true)
	for row in tiles:
		for tile in row:
			var tile_node: ColorRect = tile as ColorRect
			t.tween_property(tile_node, "modulate", tint, 0.12)
			t.tween_property(tile_node, "scale", Vector2(1.04, 1.04), 0.12)
	await t.finished

func _animate_powerup_release() -> void:
	var t: Tween = create_tween()
	t.set_parallel(true)
	for row in tiles:
		for tile in row:
			var tile_node: ColorRect = tile as ColorRect
			t.tween_property(tile_node, "modulate", Color(1, 1, 1, 1), 0.18)
			t.tween_property(tile_node, "scale", Vector2.ONE, 0.18)
	await t.finished

func _trigger_match_haptic() -> bool:
	if not FeatureFlags.haptics_enabled():
		return false
	var duration_ms: int = FeatureFlags.match_haptic_duration_ms()
	var amplitude: float = FeatureFlags.match_haptic_amplitude()
	Input.vibrate_handheld(duration_ms, amplitude)
	emit_signal("match_haptic_triggered", duration_ms, amplitude)
	return true

func _trigger_match_click_haptic() -> bool:
	if not FeatureFlags.haptics_enabled():
		return false
	var duration_ms: int = FeatureFlags.match_click_haptic_duration_ms()
	var amplitude: float = FeatureFlags.match_click_haptic_amplitude()
	Input.vibrate_handheld(duration_ms, amplitude)
	emit_signal("match_click_haptic_triggered", duration_ms, amplitude)
	return true
