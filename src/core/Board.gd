extends RefCounted
class_name Board

var width: int
var height: int
var color_count: int
var min_match_size: int
var match_color_mod: int
var rng: RandomNumberGenerator
var grid: Array

const START_TILE_COUNT := 2
const LOW_LEVEL_SPAWN_CHANCE := 0.9
const LOW_LEVEL := 1
const HIGH_LEVEL := 2

func _init(
	w: int = 4,
	h: int = 4,
	colors: int = 14,
	rng_seed: int = -1,
	min_match: int = 2,
	match_mod: int = -1
) -> void:
	width = max(2, w)
	height = max(2, h)
	color_count = max(4, colors)
	min_match_size = max(2, min_match)
	match_color_mod = match_mod
	rng = RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	grid = []
	_reset_grid()
	for _i in range(START_TILE_COUNT):
		spawn_tile()

func _reset_grid() -> void:
	grid.clear()
	for y in range(height):
		var row: Array = []
		for _x in range(width):
			row.append(0)
		grid.append(row)

func get_tile(pos: Vector2i) -> Variant:
	if not _in_bounds(pos):
		return null
	return grid[pos.y][pos.x]

func set_tile(pos: Vector2i, value: Variant) -> void:
	if _in_bounds(pos):
		grid[pos.y][pos.x] = value

func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func snapshot() -> Array:
	return grid.duplicate(true)

func restore(snapshot_grid: Array) -> void:
	grid = snapshot_grid.duplicate(true)

func find_group(start: Vector2i) -> Array:
	if not _in_bounds(start):
		return []
	var target: int = int(get_tile(start))
	if target <= 0:
		return []
	var visited := {}
	var stack: Array[Vector2i] = [start]
	var out: Array = []
	visited[start] = true
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		out.append(p)
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var np: Vector2i = p + dir
			if not _in_bounds(np):
				continue
			if visited.has(np):
				continue
			if int(get_tile(np)) != target:
				continue
			visited[np] = true
			stack.append(np)
	return out

func has_move() -> bool:
	for y in range(height):
		for x in range(width):
			var v: int = int(grid[y][x])
			if v == 0:
				return true
			if x + 1 < width and int(grid[y][x + 1]) == v:
				return true
			if y + 1 < height and int(grid[y + 1][x]) == v:
				return true
	return false

func resolve_move(start: Vector2i) -> Array:
	var group: Array = find_group(start)
	if group.size() < min_match_size:
		return []
	for p in group:
		set_tile(p, 0)
	_refill_empty_cells()
	return group

func move(direction: Vector2i) -> Dictionary:
	var lines: Array = _lines_for_direction(direction)
	if lines.is_empty():
		return {
			"moved": false,
			"score_gain": 0,
			"merge_positions": [],
			"spawn_position": Vector2i(-1, -1),
			"motion_paths": [],
			"spawn_from_direction": direction,
		}

	var moved := false
	var score_gain := 0
	var merge_positions: Array[Vector2i] = []
	var motion_paths: Array[Dictionary] = []

	for line_coords in lines:
		var old_line: Array = []
		for p in line_coords:
			old_line.append(int(grid[p.y][p.x]))

		var result: Dictionary = _slide_line(old_line)
		var new_line: Array = result["line"]
		if old_line != new_line:
			moved = true
		score_gain += int(result["score_gain"])
		for idx in result["merged_indices"]:
			merge_positions.append(line_coords[int(idx)])
		for path_var in result.get("paths", []):
			var path: Dictionary = path_var
			var from_idx: int = int(path.get("from", -1))
			var to_idx: int = int(path.get("to", -1))
			if from_idx < 0 or from_idx >= line_coords.size() or to_idx < 0 or to_idx >= line_coords.size():
				continue
			var old_cell: Vector2i = line_coords[from_idx]
			var new_cell: Vector2i = line_coords[to_idx]
			motion_paths.append({
				"old_cell": old_cell,
				"new_cell": new_cell,
				"from": old_cell,
				"to": new_cell,
				"level": int(path.get("level", 0)),
				"merged": bool(path.get("merged", false)),
				"spawned": false,
			})

		for i in range(line_coords.size()):
			var p: Vector2i = line_coords[i]
			grid[p.y][p.x] = int(new_line[i])

	if not moved:
		return {
			"moved": false,
			"score_gain": 0,
			"merge_positions": [],
			"spawn_position": Vector2i(-1, -1),
			"motion_paths": [],
			"spawn_from_direction": direction,
		}

	var spawn_position: Vector2i = spawn_tile()
	if _in_bounds(spawn_position):
		var spawn_old_cell: Vector2i = spawn_position - direction
		motion_paths.append({
			"old_cell": spawn_old_cell,
			"new_cell": spawn_position,
			"from": spawn_old_cell,
			"to": spawn_position,
			"level": int(grid[spawn_position.y][spawn_position.x]),
			"merged": false,
			"spawned": true,
		})
	return {
		"moved": true,
		"score_gain": score_gain,
		"merge_positions": merge_positions,
		"spawn_position": spawn_position,
		"motion_paths": motion_paths,
		"spawn_from_direction": direction,
	}

func count_available_matches() -> int:
	var count := 0
	for y in range(height):
		for x in range(width):
			var v: int = int(grid[y][x])
			if v <= 0:
				continue
			if x + 1 < width and int(grid[y][x + 1]) == v:
				count += 1
			if y + 1 < height and int(grid[y + 1][x]) == v:
				count += 1
	return count

func ensure_min_available_matches(min_count: int, max_attempts: int = 100) -> int:
	var target: int = max(0, min_count)
	if count_available_matches() >= target:
		return count_available_matches()
	var attempts := 0
	while attempts < max_attempts and count_available_matches() < target:
		attempts += 1
		shuffle_tiles()
	if count_available_matches() >= target:
		return count_available_matches()
	_force_merge_pair()
	return count_available_matches()

func shuffle_tiles() -> void:
	var values: Array = []
	for y in range(height):
		for x in range(width):
			var v: int = int(grid[y][x])
			if v > 0:
				values.append(v)
	for i in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = values[i]
		values[i] = values[j]
		values[j] = tmp

	var idx := 0
	for y in range(height):
		for x in range(width):
			if idx < values.size():
				grid[y][x] = int(values[idx])
				idx += 1
			else:
				grid[y][x] = 0

	if not has_move():
		_force_merge_pair()

func remove_color(color_idx: int, _color_mod: int = -1) -> int:
	if color_idx <= 0:
		return 0
	var removed := 0
	for y in range(height):
		for x in range(width):
			if int(grid[y][x]) == color_idx:
				grid[y][x] = 0
				removed += 1
	if removed <= 0:
		return 0
	_refill_empty_cells()
	if not has_move():
		_force_merge_pair()
	return removed

func spawn_tile(level_override: int = -1) -> Vector2i:
	var empties: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			if int(grid[y][x]) == 0:
				empties.append(Vector2i(x, y))
	if empties.is_empty():
		return Vector2i(-1, -1)
	var pos: Vector2i = empties[rng.randi_range(0, empties.size() - 1)]
	var level: int = level_override
	if level <= 0:
		level = LOW_LEVEL if rng.randf() < LOW_LEVEL_SPAWN_CHANCE else HIGH_LEVEL
	grid[pos.y][pos.x] = level
	return pos

func _lines_for_direction(direction: Vector2i) -> Array:
	var lines: Array = []
	if direction == Vector2i.LEFT:
		for y in range(height):
			var line: Array[Vector2i] = []
			for x in range(width):
				line.append(Vector2i(x, y))
			lines.append(line)
		return lines
	if direction == Vector2i.RIGHT:
		for y in range(height):
			var line: Array[Vector2i] = []
			for x in range(width - 1, -1, -1):
				line.append(Vector2i(x, y))
			lines.append(line)
		return lines
	if direction == Vector2i.UP:
		for x in range(width):
			var line: Array[Vector2i] = []
			for y in range(height):
				line.append(Vector2i(x, y))
			lines.append(line)
		return lines
	if direction == Vector2i.DOWN:
		for x in range(width):
			var line: Array[Vector2i] = []
			for y in range(height - 1, -1, -1):
				line.append(Vector2i(x, y))
			lines.append(line)
		return lines
	return []

func _slide_line(line: Array) -> Dictionary:
	var items: Array = []
	for source_idx in range(line.size()):
		var value: Variant = line[source_idx]
		var v: int = int(value)
		if v > 0:
			items.append({
				"value": v,
				"source": source_idx,
			})

	var result: Array = []
	var merged_indices: Array = []
	var paths: Array[Dictionary] = []
	var score_gain := 0
	var i := 0
	while i < items.size():
		var item: Dictionary = items[i]
		var value: int = int(item.get("value", 0))
		if i + 1 < items.size() and int((items[i + 1] as Dictionary).get("value", 0)) == value:
			var next_item: Dictionary = items[i + 1]
			var merged_level: int = value + 1
			var target_index: int = result.size()
			result.append(merged_level)
			merged_indices.append(target_index)
			paths.append({
				"from": int(item.get("source", -1)),
				"to": target_index,
				"level": merged_level,
				"merged": true,
			})
			paths.append({
				"from": int(next_item.get("source", -1)),
				"to": target_index,
				"level": merged_level,
				"merged": true,
			})
			score_gain += int(pow(2.0, float(merged_level)))
			i += 2
		else:
			var target_index: int = result.size()
			result.append(value)
			paths.append({
				"from": int(item.get("source", -1)),
				"to": target_index,
				"level": value,
				"merged": false,
			})
			i += 1

	while result.size() < line.size():
		result.append(0)

	return {
		"line": result,
		"merged_indices": merged_indices,
		"paths": paths,
		"score_gain": score_gain,
	}

func _refill_empty_cells() -> void:
	for y in range(height):
		for x in range(width):
			if int(grid[y][x]) == 0:
				grid[y][x] = LOW_LEVEL if rng.randf() < LOW_LEVEL_SPAWN_CHANCE else HIGH_LEVEL

func _force_merge_pair() -> void:
	var all_cells: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			all_cells.append(Vector2i(x, y))
	if all_cells.size() < 2:
		return
	for i in range(all_cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = all_cells[i]
		all_cells[i] = all_cells[j]
		all_cells[j] = tmp
	var first: Vector2i = all_cells[0]
	var second: Vector2i = first + Vector2i.RIGHT
	if second.x >= width:
		second = first + Vector2i.LEFT
	if second.x < 0:
		second = first + Vector2i.DOWN
	if second.y >= height:
		second = first + Vector2i.UP
	if not _in_bounds(second):
		second = all_cells[1]
	grid[first.y][first.x] = LOW_LEVEL
	grid[second.y][second.x] = LOW_LEVEL
