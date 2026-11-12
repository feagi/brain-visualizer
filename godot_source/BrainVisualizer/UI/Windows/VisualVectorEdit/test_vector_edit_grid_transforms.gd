extends SceneTree
## Unit tests for VectorEditGrid pure transform helpers (headless, no scene tree).

const Grid = preload("res://BrainVisualizer/UI/Windows/VisualVectorEdit/VectorEditGrid.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_rotate()
	failures += _test_enlarge_shrink()
	failures += _test_shrink_merge_and_never_origin()
	failures += _test_radius_steps()
	failures += _test_grid_metrics()
	failures += _test_other_slices_untouched()
	failures += _test_undo_redo()
	failures += _test_commit_noop_and_cap()
	if failures == 0:
		print("VectorEditGrid transform tests: PASS")
		quit(0)
	else:
		push_error("VectorEditGrid transform tests: FAIL (%d)" % failures)
		quit(1)


func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var c: Array[Vector2i] = cells.duplicate()
	c.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return c


func _same(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	return _sorted(a) == _sorted(b)


func _fail(msg: String) -> int:
	push_error(msg)
	return 1


func _test_rotate() -> int:
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 1), Vector2i(-2, 5), Vector2i(0, -4)]
	var cw: Array[Vector2i] = Grid.rotate_cells([Vector2i(1, 0)] as Array[Vector2i], true)
	if not _same(cw, [Vector2i(0, -1)] as Array[Vector2i]):
		return _fail("CW (1,0) should be (0,-1), got %s" % str(cw))
	var ccw: Array[Vector2i] = Grid.rotate_cells([Vector2i(1, 0)] as Array[Vector2i], false)
	if not _same(ccw, [Vector2i(0, 1)] as Array[Vector2i]):
		return _fail("CCW (1,0) should be (0,1), got %s" % str(ccw))
	if not _same(Grid.rotate_cells(Grid.rotate_cells(cells, true), false), cells):
		return _fail("CW then CCW is not identity")
	var r: Array[Vector2i] = cells
	for i in 4:
		r = Grid.rotate_cells(r, true)
	if not _same(r, cells):
		return _fail("4x CW is not identity")
	return 0


func _test_enlarge_shrink() -> int:
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-3, 2)]
	var e: Array[Vector2i] = Grid.scale_cells(cells, true)
	if not _same(e, [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-6, 4)] as Array[Vector2i]):
		return _fail("Enlarge wrong: %s" % str(e))
	if not _same(Grid.scale_cells(e, false), cells):
		return _fail("Enlarge then Shrink is not identity")
	var big: Array[Vector2i] = [Vector2i(Grid.INT32_SAFE_HALF + 1, 0)]
	if Grid.can_enlarge(big) or Grid.scale_cells(big, true) != big:
		return _fail("Enlarge must refuse int32 overflow")
	return 0


func _test_shrink_merge_and_never_origin() -> int:
	var merged: Array[Vector2i] = Grid.scale_cells([Vector2i(4, 4), Vector2i(5, 5), Vector2i(3, 3)] as Array[Vector2i], false)
	if not _same(merged, [Vector2i(2, 2), Vector2i(1, 1)] as Array[Vector2i]):
		return _fail("Shrink merge wrong: %s" % str(merged))
	for x in range(-3, 4):
		for y in range(-3, 4):
			var c: Vector2i = Vector2i(x, y)
			if c == Vector2i.ZERO:
				continue
			var out: Array[Vector2i] = Grid.scale_cells([c] as Array[Vector2i], false)
			if out.size() != 1 or out[0] == Vector2i.ZERO:
				return _fail("Shrink created origin from %s" % str(c))
	var neg: Array[Vector2i] = Grid.scale_cells([Vector2i(-3, -2)] as Array[Vector2i], false)
	if not _same(neg, [Vector2i(-1, -1)] as Array[Vector2i]):
		return _fail("Shrink must truncate toward zero, got %s" % str(neg))
	return 0


func _test_radius_steps() -> int:
	if Grid.radius_step_for(12) != 15 or Grid.radius_step_for(0) != 7 or Grid.radius_step_for(40) != 22:
		return _fail("radius_step_for wrong")
	if Grid.radius_step_for(7) != 7 or Grid.radius_step_for(8) != 10 or Grid.radius_step_for(22) != 22:
		return _fail("radius_step_for boundaries wrong")
	return 0


func _test_grid_metrics() -> int:
	for r in Grid.RADIUS_STEPS:
		var m: Vector2i = Grid.grid_metrics(r)
		var used: int = m.x * (2 * r + 1)
		if m.x < 1 or m.y < 0 or used + 2 * m.y > Grid.GRID_SIDE or Grid.GRID_SIDE - used - 2 * m.y > 1:
			return _fail("grid_metrics bad for radius %d: %s" % [r, str(m)])
	if Grid.grid_metrics(7) != Vector2i(24, 0):
		return _fail("grid_metrics(7) expected (24,0)")
	return 0


func _test_other_slices_untouched() -> int:
	var sel: Dictionary = {"1,0,0": true, "2,2,1": true, "-1,3,1": true, "5,5,2": true}
	var cells: Array[Vector2i] = Grid.cells_at_z(sel, 1)
	var out: Dictionary = Grid.replace_slice(sel, 1, Grid.scale_cells(cells, true))
	if not out.has("1,0,0") or not out.has("5,5,2") or out.has("2,2,1") or not out.has("4,4,1") or not out.has("-2,6,1"):
		return _fail("replace_slice wrong: %s" % str(out.keys()))
	if Grid.cells_at_z(out, 0) != Grid.cells_at_z(sel, 0) or Grid.cells_at_z(out, 2) != Grid.cells_at_z(sel, 2):
		return _fail("other slices changed")
	if Grid.count_outside(cells, 2) != 1:
		return _fail("count_outside wrong")
	return 0


func _test_undo_redo() -> int:
	var g: VectorEditGrid = Grid.new()
	var opening: Dictionary = {"1,0,0": true, "0,2,0": true}
	g.set_full_selection(opening)
	g.set_current_z(0)
	g._toggle(3, 3)
	g._toggle(-1, 0)
	g._toggle(1, 0)  # removes an opening cell
	g.rotate_slice(true)
	g.clear_slice()
	var cleared: Dictionary = g.get_full_selection()
	if not cleared.is_empty():
		return _fail("clear_slice should empty the slice")
	for i in 5:
		if not g.can_undo():
			return _fail("undo ran out early at %d" % i)
		g.undo()
	if g.can_undo() or not Grid.same_selection(g.get_full_selection(), opening):
		return _fail("5x undo should equal opening selection")
	for i in 5:
		if not g.can_redo():
			return _fail("redo ran out early at %d" % i)
		g.redo()
	if g.can_redo() or not Grid.same_selection(g.get_full_selection(), cleared):
		return _fail("5x redo should equal cleared selection")
	g.undo()
	g._toggle(5, 5)
	if g.can_redo():
		return _fail("a new edit after undo must empty redo")
	g.free()
	return 0


func _test_commit_noop_and_cap() -> int:
	var g: VectorEditGrid = Grid.new()
	g.set_full_selection({})
	g.set_current_z(0)
	g.clear_slice()
	g.rotate_slice(true)
	g.scale_slice(false)
	if g.can_undo():
		return _fail("no-op commits must push nothing")
	for i in range(150):
		g._toggle(i, 0)
	var n: int = 0
	while g.can_undo():
		g.undo()
		n += 1
	if n != Grid.UNDO_CAP:
		return _fail("undo cap should be %d, got %d" % [Grid.UNDO_CAP, n])
	g.free()
	return 0
