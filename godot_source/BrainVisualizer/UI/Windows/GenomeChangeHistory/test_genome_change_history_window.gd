extends SceneTree
## Change-history window opens wide enough for a four-column table and can be dragged.
## Run: godot --headless --path godot_source --script res://BrainVisualizer/UI/Windows/GenomeChangeHistory/test_genome_change_history_window.gd


func _initialize() -> void:
	var failures := 0
	failures += _test_opening_size_fits_a_table()
	failures += _test_resize_can_grow_and_shrink()
	if failures == 0:
		print("Genome change history window tests: PASS")
		quit(0)
	else:
		push_error("Genome change history window tests: FAIL (%d)" % failures)
		quit(1)


func _test_opening_size_fits_a_table() -> int:
	var desktop := Vector2(1920, 1080)
	var opened := WindowGenomeChangeHistory.opening_window_size(desktop)
	if opened.x < WindowGenomeChangeHistory.OPENING_PREFERRED.x or opened.y < WindowGenomeChangeHistory.OPENING_PREFERRED.y:
		push_error("history should open wide enough for the table, got %s" % opened)
		return 1
	if opened.x > WindowGenomeChangeHistory.OPENING_MAX.x or opened.y > WindowGenomeChangeHistory.OPENING_MAX.y:
		push_error("history should not open larger than its cap, got %s" % opened)
		return 1
	var huge := WindowGenomeChangeHistory.opening_window_size(Vector2(5568, 2428))
	if huge.x != WindowGenomeChangeHistory.OPENING_MAX.x or huge.y != WindowGenomeChangeHistory.OPENING_MAX.y:
		push_error("a large display should cap the history window, got %s" % huge)
		return 1
	var small := WindowGenomeChangeHistory.opening_window_size(Vector2(800, 600))
	if small.x > 800.0 or small.y > 600.0:
		push_error("history must stay inside a small viewport, got %s" % small)
		return 1
	return 0


func _test_resize_can_grow_and_shrink() -> int:
	var viewport := Vector2(1920, 1080)
	var start := WindowGenomeChangeHistory.opening_window_size(viewport)
	var grown := WindowGenomeChangeHistory.resized_window_size(start, Vector2(200, 80), "corner", viewport)
	if grown.x <= start.x or grown.y <= start.y:
		push_error("corner drag should grow the history window, got %s from %s" % [grown, start])
		return 1
	var shrunk := WindowGenomeChangeHistory.resized_window_size(start, Vector2(-800, -800), "corner", viewport)
	if shrunk.x != WindowGenomeChangeHistory.MIN_WINDOW_SIZE.x or shrunk.y != WindowGenomeChangeHistory.MIN_WINDOW_SIZE.y:
		push_error("corner drag should stop at the floor, got %s" % shrunk)
		return 1
	var wider := WindowGenomeChangeHistory.resized_window_size(start, Vector2(40, 0), "right", viewport)
	if wider.x <= start.x or wider.y != start.y:
		push_error("the right edge should change width only, got %s" % wider)
		return 1
	return 0
