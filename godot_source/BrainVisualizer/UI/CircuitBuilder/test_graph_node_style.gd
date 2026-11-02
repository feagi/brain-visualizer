extends SceneTree
## Type color keeps GraphNode padding, header ports stay off, and the theme locks both.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/CircuitBuilder/test_graph_node_style.gd

const STYLE := preload("res://BrainVisualizer/UI/CircuitBuilder/GraphNodeStyle.gd")


func _initialize() -> void:
	var failures := 0
	failures += _test_tint_keeps_padding()
	failures += _test_header_ports_disabled()
	failures += _test_theme_locks_graph_node()
	failures += _test_port_icon_size()
	failures += _test_line_styles_stay()
	if failures > 0:
		push_error("graph node style: %d check(s) failed" % failures)
		quit(1)
		return
	call_deferred("_test_row_ports_then_quit")


func _test_row_ports_then_quit() -> void:
	var failed: int = await _test_one_port_per_row()
	if failed > 0:
		push_error("graph node style: %d check(s) failed" % failed)
		quit(1)
		return
	failed = await _test_hidden_parent_port()
	if failed > 0:
		push_error("graph node style: %d check(s) failed" % failed)
		quit(1)
		return
	print("graph node style: PASS")
	quit(0)


func _test_port_icon_size() -> int:
	var icon := GraphNodeStyle.port_icon(&"full")
	if icon.get_width() != GraphNodeStyle.PORT_ICON_PX or icon.get_height() != GraphNodeStyle.PORT_ICON_PX:
		push_error("port icon is %s, expected %d" % [icon.get_size(), GraphNodeStyle.PORT_ICON_PX])
		return 1
	if GraphNodeStyle.port_icon(&"ring").get_width() != GraphNodeStyle.PORT_ICON_PX:
		push_error("ring port icon was not scaled")
		return 1
	return 0


func _test_line_styles_stay() -> int:
	var text := FileAccess.get_file_as_string("res://BrainVisualizer/UI/CircuitBuilder/CBLine/CBLineInterTerminal.gd")
	if not text.contains("set_line_dashing(mapping_ref.is_any_mapping_plastic())"):
		push_error("plastic mappings must stay dashed")
		return 1
	if not text.contains("LINE_COLOR_PARTIAL_MAPPING_TRANSPARENCY"):
		push_error("partial mappings must stay transparent")
		return 1
	return 0


func _test_one_port_per_row() -> int:
	var graph := GraphNode.new()
	graph.position_offset = Vector2(40, 70)
	root.add_child(graph)
	var header := Label.new()
	header.text = "Add Input"
	header.custom_minimum_size = Vector2(120, 20)
	graph.add_child(header)
	var hidden := VBoxContainer.new()
	hidden.visible = false
	graph.add_child(hidden)
	var first := Label.new()
	first.custom_minimum_size = Vector2(120, 22)
	graph.add_child(first)
	var second := Label.new()
	second.custom_minimum_size = Vector2(120, 22)
	graph.add_child(second)
	if GraphNodeStyle.visible_slot_index(graph, first) != 1 or GraphNodeStyle.visible_slot_index(graph, second) != 2:
		push_error("hidden group container was counted as a slot")
		return 1
	GraphNodeStyle.configure_row_slot(graph, 0, false, false, null)
	GraphNodeStyle.configure_row_slot(graph, 1, true, false, GraphNodeStyle.port_icon(&"full"))
	GraphNodeStyle.configure_row_slot(graph, 2, true, false, GraphNodeStyle.port_icon(&"full"))
	await process_frame
	if graph.get_input_port_count() != 2:
		push_error("expected 2 input ports, got %d" % graph.get_input_port_count())
		return 1
	if graph.get_input_port_slot(0) != 1 or graph.get_input_port_slot(1) != 2:
		push_error("ports landed on the wrong rows: %d %d" % [graph.get_input_port_slot(0), graph.get_input_port_slot(1)])
		return 1
	var first_pos := GraphNodeStyle.graph_port_position(graph, true, 0)
	var second_pos := GraphNodeStyle.graph_port_position(graph, true, 1)
	if second_pos.y <= first_pos.y:
		push_error("second row port is not below the first: %s %s" % [first_pos, second_pos])
		return 1
	if first_pos != graph.get_input_port_position(0) + graph.position_offset:
		push_error("wire anchor is not the graph port position")
		return 1
	if graph.is_slot_draw_stylebox(1):
		push_error("row slot background is still drawn")
		return 1
	graph.queue_free()
	return 0


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


var _slot_sizes_fired := 0


func _on_slot_sizes() -> void:
	_slot_sizes_fired += 1


func _test_hidden_parent_port() -> int:
	var host := Control.new()
	host.visible = false
	root.add_child(host)
	var graph := GraphNode.new()
	graph.position_offset = Vector2(40, 70)
	host.add_child(graph)
	var row := Label.new()
	row.text = "Row"
	row.custom_minimum_size = Vector2(120, 22)
	graph.add_child(row)
	GraphNodeStyle.configure_row_slot(graph, 0, false, true, GraphNodeStyle.port_icon(&"full"))
	graph.slot_sizes_changed.connect(_on_slot_sizes)
	await process_frame
	await process_frame
	var hidden_pos := GraphNodeStyle.graph_port_position(graph, false, 0)
	if hidden_pos != graph.position_offset:
		push_error("hidden node port position should be position_offset, got %s" % hidden_pos)
		return 1
	_slot_sizes_fired = 0
	host.visible = true
	for i in 4:
		await process_frame
	print("slot_sizes_changed fired after show: %d" % _slot_sizes_fired)
	if _slot_sizes_fired < 1:
		push_error("slot_sizes_changed did not fire after the node became visible")
		return 1
	var shown_pos := GraphNodeStyle.graph_port_position(graph, false, 0)
	if shown_pos == graph.position_offset:
		push_error("shown node port position still equals position_offset")
		return 1
	host.queue_free()
	return 0
