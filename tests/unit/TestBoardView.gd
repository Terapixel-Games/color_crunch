extends GdUnitTestSuite

func test_emits_no_moves_once_when_board_is_stalled() -> void:
	var view := BoardView.new()
	view.width = 4
	view.height = 4
	view.tile_size = 24.0
	get_tree().root.add_child(view)
	view.board.grid = [
		[1, 2, 3, 4],
		[4, 3, 2, 1],
		[1, 2, 3, 4],
		[4, 3, 2, 1],
	]
	view._refresh_tiles()
	var emitted_count: Array[int] = [0]
	view.connect("no_moves", func() -> void:
		emitted_count[0] += 1
	)
	assert_that(view._check_no_moves_and_emit()).is_false()
	assert_that(view._check_no_moves_and_emit()).is_false()
	assert_that(emitted_count[0]).is_equal(1)
	view.queue_free()

func test_attempt_move_emits_commit_and_match() -> void:
	var view := BoardView.new()
	view.width = 4
	view.height = 4
	view.tile_size = 24.0
	get_tree().root.add_child(view)
	view.board.grid = [
		[1, 1, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 0, 0],
	]
	view._refresh_tiles()
	var committed: Array[bool] = [false]
	var matched: Array[bool] = [false]
	view.connect("move_committed", func(_group: Array, _snapshot: Array) -> void:
		committed[0] = true
	)
	view.connect("match_made", func(_group: Array) -> void:
		matched[0] = true
	)
	await view._attempt_move(Vector2i.RIGHT)
	assert_that(committed[0]).is_true()
	assert_that(matched[0]).is_true()
	assert_that(view.consume_last_move_score()).is_equal(4)
	view.queue_free()

func test_attempt_move_emits_directional_attempt_even_without_tile_motion() -> void:
	var view := BoardView.new()
	view.width = 4
	view.height = 4
	view.tile_size = 24.0
	get_tree().root.add_child(view)
	view.board.grid = [
		[1, 0, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 0, 0],
		[0, 0, 0, 0],
	]
	view._refresh_tiles()
	var attempted: Array[Vector2i] = [Vector2i.ZERO]
	var committed: Array[bool] = [false]
	view.connect("move_attempted", func(direction: Vector2i) -> void:
		attempted[0] = direction
	)
	view.connect("move_committed", func(_group: Array, _snapshot: Array) -> void:
		committed[0] = true
	)
	await view._attempt_move(Vector2i.LEFT)
	assert_that(attempted[0]).is_equal(Vector2i.LEFT)
	assert_that(committed[0]).is_false()
	view.queue_free()

func test_restore_snapshot_restores_grid_state() -> void:
	var view := BoardView.new()
	view.width = 4
	view.height = 4
	view.tile_size = 24.0
	get_tree().root.add_child(view)
	var snapshot: Array = [
		[1, 2, 3, 4],
		[4, 3, 2, 1],
		[1, 2, 3, 4],
		[4, 3, 2, 1],
	]
	view.restore_snapshot(snapshot)
	assert_that(view.board.grid).is_equal(snapshot)
	view.queue_free()

func test_hint_group_finds_first_merge_pair() -> void:
	var view := BoardView.new()
	view.width = 4
	view.height = 4
	view.tile_size = 24.0
	get_tree().root.add_child(view)
	view.board.grid = [
		[1, 2, 3, 4],
		[4, 3, 3, 1],
		[1, 2, 4, 2],
		[4, 1, 2, 4],
	]
	var hint: Array = view._find_hint_group()
	assert_that(hint.size()).is_equal(2)
	var first: Vector2i = hint[0]
	var second: Vector2i = hint[1]
	assert_that(int(view.board.grid[first.y][first.x])).is_equal(int(view.board.grid[second.y][second.x]))
	var manhattan: int = abs(first.x - second.x) + abs(first.y - second.y)
	assert_that(manhattan).is_equal(1)
	view.queue_free()

func test_tile_origin_accounts_for_tile_size() -> void:
	var view := BoardView.new()
	view.width = 4
	view.height = 4
	view.tile_size = 80.0
	get_tree().root.add_child(view)
	var origin: Vector2 = view._tile_origin(Vector2i(2, 1))
	assert_that(origin.x).is_greater(0.0)
	assert_that(origin.y).is_greater(0.0)
	view.queue_free()

func test_color_labels_match_color_crunch_theme_palette() -> void:
	var original_colorblind: bool = SaveStore.is_colorblind_high_contrast()
	SaveStore.data["colorblind_high_contrast"] = false
	var view := BoardView.new()
	view.width = 4
	view.height = 4
	view.tile_size = 24.0
	get_tree().root.add_child(view)
	view.set_theme_palette(ThemeManager.COLOR_CRUNCH_DEFAULT_TILE_PALETTE)

	assert_that(view._tile_palette().size()).is_equal(BoardView.TILE_PALETTE_MODERN.size())
	assert_that(view._label_for_level(1)).is_equal("MINT")
	assert_that(view._color_from_level(1)).is_equal(ThemeManager.COLOR_CRUNCH_DEFAULT_TILE_PALETTE[0])
	assert_that(view._label_for_level(2)).is_equal("LIME")
	assert_that(view._color_from_level(2)).is_equal(ThemeManager.COLOR_CRUNCH_DEFAULT_TILE_PALETTE[1])
	assert_that(view._label_for_level(5)).is_equal("SKY")
	assert_that(view._color_from_level(5)).is_equal(ThemeManager.COLOR_CRUNCH_DEFAULT_TILE_PALETTE[4])
	assert_that(view._label_for_level(14)).is_equal("SOLAR")
	assert_that(view._color_from_level(14)).is_equal(ThemeManager.COLOR_CRUNCH_DEFAULT_TILE_PALETTE[13])

	view.set_theme_palette([Color.RED, Color.BLUE, Color.GREEN])
	assert_that(view._tile_palette().size()).is_equal(BoardView.TILE_PALETTE_MODERN.size())
	view.queue_free()
	SaveStore.data["colorblind_high_contrast"] = original_colorblind
