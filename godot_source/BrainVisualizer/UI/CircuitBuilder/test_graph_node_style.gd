extends SceneTree
## Type color keeps GraphNode padding, header ports stay off, and the theme locks both.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/CircuitBuilder/test_graph_node_style.gd

const STYLE := preload("res://BrainVisualizer/UI/CircuitBuilder/GraphNodeStyle.gd")


func _initialize() -> void:
	var failures := 0
	failures += _test_tint_keeps_padding()
	failures += _test_header_ports_disabled()
	failures += _test_theme_locks_graph_node()
	if failures > 0:
		push_error("graph node style: %d check(s) failed" % failures)
		quit(1)
		return
	print("graph node style: PASS")
	quit(0)


func _test_tint_keeps_padding() -> int:
	var node := GraphNode.new()
	root.add_child(node)
	var failed := 0
	var panel := STYLE.tinted(node, &"panel", Color(0.2, 0.3, 0.4)) as StyleBoxFlat
	var title := STYLE.tinted(node, &"titlebar", Color.RED) as StyleBoxFlat
	if panel == null or panel.content_margin_left != 18.0 or panel.content_margin_top != 12.0 or panel.content_margin_right != 18.0 or panel.content_margin_bottom != 12.0:
		push_error("tinted panel dropped its padding: %s" % panel)
		failed = 1
	if panel == null or panel.bg_color != Color(0.2, 0.3, 0.4):
		push_error("tinted panel fill was not applied")
		failed = 1
	if title == null or title.content_margin_left != 4.0 or title.content_margin_top != 4.0 or title.bg_color != Color.RED:
		push_error("tinted title bar dropped its padding or fill: %s" % title)
		failed = 1
	node.queue_free()
	return failed


func _test_header_ports_disabled() -> int:
	var failed := 0
	var scenes: PackedStringArray = [
		"res://BrainVisualizer/UI/CircuitBuilder/CBNodeCorticalArea/CBNodeCorticalArea.tscn",
		"res://BrainVisualizer/UI/CircuitBuilder/CBNodeBrainRegion/CBNodeRegion.tscn",
		"res://BrainVisualizer/UI/CircuitBuilder/CBNodeClassifier/CBNodeClassifier.tscn",
	]
	for path: String in scenes:
		var text := FileAccess.get_file_as_string(path)
		if not text.contains("slot/0/left_enabled = false") or not text.contains("slot/0/right_enabled = false"):
			push_error("header ports still enabled in %s" % path)
			failed = 1
	return failed


func _test_theme_locks_graph_node() -> int:
	var failed := 0
	var themes: PackedStringArray = [
		"res://BrainVisualizer/UI/Themes/source_themes/source_dark.tres",
		"res://BrainVisualizer/UI/Themes/1-DARK.tres",
	]
	for path: String in themes:
		var theme := load(path) as Theme
		var panel := theme.get_stylebox(&"panel", &"GraphNode") as StyleBoxFlat
		var title := theme.get_stylebox(&"titlebar", &"GraphNode") as StyleBoxFlat
		if panel == null or panel.content_margin_left != 18.0 or panel.content_margin_top != 12.0:
			push_error("theme panel padding is not locked in %s" % path)
			failed = 1
		if title == null or title.content_margin_left != 4.0 or title.content_margin_top != 4.0:
			push_error("theme title bar padding is not locked in %s" % path)
			failed = 1
		if not (theme.get_stylebox(&"slot", &"GraphNode") is StyleBoxEmpty):
			push_error("theme slot style is not empty in %s" % path)
			failed = 1
		if theme.get_constant(&"port_h_offset", &"GraphNode") != 0:
			push_error("theme port offset is not locked in %s" % path)
			failed = 1
	return failed
