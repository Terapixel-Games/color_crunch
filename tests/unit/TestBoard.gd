extends GdUnitTestSuite

func test_slide_line_merges_each_pair_once() -> void:
	var b := Board.new(4, 4, 16, 7)
	var result: Dictionary = b._slide_line([1, 1, 1, 1])
	assert_that(result["line"]).is_equal([2, 2, 0, 0])
	assert_that(int(result["score_gain"])).is_equal(8)
	assert_that(result["merged_indices"]).is_equal([0, 1])

func test_move_left_applies_merge_and_spawns_one_tile() -> void:
	var b := Board.new(4, 4, 16, 11)
	b.grid = [
		[1, 1, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 0, 0],
	]
	var result: Dictionary = b.move(Vector2i.LEFT)
	assert_that(bool(result["moved"])).is_true()
	assert_that(int(result["score_gain"])).is_equal(4)
	assert_that(int(b.grid[0][0])).is_equal(2)
	assert_that(int(b.grid[0][1])).is_equal(0)
	assert_that(_count_non_zero_cells(b.grid)).is_equal(2)

func test_move_returns_swipe_animation_metadata() -> void:
	var b := Board.new(4, 4, 16, 11)
	b.grid = [
		[1, 1, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 0, 0],
	]
	var result: Dictionary = b.move(Vector2i.RIGHT)
	assert_that(bool(result["moved"])).is_true()
	assert_that(result.has("motion_paths")).is_true()
	assert_that(result.has("spawn_from_direction")).is_true()
	assert_that(result["spawn_from_direction"]).is_equal(Vector2i.RIGHT)

	var paths: Array = result["motion_paths"]
	assert_that(paths.size()).is_greater_equal(3)
	var merge_paths := 0
	var spawn_paths := 0
	for path_var in paths:
		var path: Dictionary = path_var
		assert_that(path.has("old_cell")).is_true()
		assert_that(path.has("new_cell")).is_true()
		assert_that(path.has("level")).is_true()
		if bool(path.get("merged", false)):
			merge_paths += 1
			assert_that(path.get("new_cell")).is_equal(Vector2i(3, 0))
		if bool(path.get("spawned", false)):
			spawn_paths += 1
			assert_that(path.get("new_cell")).is_equal(result["spawn_position"])
	assert_that(merge_paths).is_equal(2)
	assert_that(spawn_paths).is_equal(1)

func test_move_without_change_returns_false() -> void:
	var b := Board.new(4, 4, 16, 21)
	b.grid = [
		[1, 2, 3, 4],
		[4, 3, 2, 1],
		[1, 2, 3, 4],
		[4, 3, 2, 1],
	]
	var result: Dictionary = b.move(Vector2i.LEFT)
	assert_that(bool(result["moved"])).is_false()
	assert_that(int(result["score_gain"])).is_equal(0)
	assert_that(result.get("motion_paths", [])).is_empty()
	assert_that(result.get("spawn_from_direction", Vector2i.ZERO)).is_equal(Vector2i.LEFT)
	assert_that(b.grid).is_equal([
		[1, 2, 3, 4],
		[4, 3, 2, 1],
		[1, 2, 3, 4],
		[4, 3, 2, 1],
	])

func test_has_move_detects_adjacent_match_even_when_full() -> void:
	var b := Board.new(4, 4, 16, 3)
	b.grid = [
		[1, 2, 3, 4],
		[4, 3, 2, 1],
		[1, 1, 3, 4],
		[4, 3, 2, 1],
	]
	assert_that(b.has_move()).is_true()

func test_remove_color_refills_empty_slots() -> void:
	var b := Board.new(4, 4, 16, 4)
	b.grid = [
		[1, 2, 1, 2],
		[2, 1, 2, 1],
		[1, 2, 1, 2],
		[2, 1, 2, 1],
	]
	var removed: int = b.remove_color(2)
	assert_that(removed).is_equal(8)
	for row in b.grid:
		for cell in row:
			assert_that(int(cell)).is_greater(0)

func _count_non_zero_cells(grid: Array) -> int:
	var count := 0
	for row in grid:
		for cell in row:
			if int(cell) > 0:
				count += 1
	return count
