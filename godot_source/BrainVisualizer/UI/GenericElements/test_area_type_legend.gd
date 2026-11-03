extends SceneTree
## Modulator boxes are dark green in Circuit Builder and Circuit Schematic, and the legend lists that color.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/GenericElements/test_area_type_legend.gd


func _initialize() -> void:
	var failures := 0
	var modulator := CBNodeCorticalArea.MODULATOR_BOX_COLOR
	if modulator == CBNodeCorticalArea.CORE_BOX_COLOR:
		push_error("modulator must not use the core color")
		failures += 1
	if modulator.g <= modulator.r or modulator.g <= modulator.b or modulator.g < 0.25 or modulator.g > 0.55:
		push_error("modulator color is not a dark green: %s" % modulator)
		failures += 1
	if modulator == CBLineInterTerminal.LINE_COLOR_PSPP:
		push_error("modulator color matches excitatory wires")
		failures += 1
	var schematic: Color = SchematicTreeBuilder.TYPE_COLORS[AbstractCorticalArea.CORTICAL_AREA_TYPE.MODULATOR]
	if schematic != modulator:
		push_error("schematic modulator color drifted from circuit builder")
		failures += 1
	var rows: Array[Dictionary] = AreaTypeLegend.entries(CBNodeClassifier.CLASSIFIER_BOX_COLOR)
	var labels: PackedStringArray = []
	var saw_modulator := false
	for row: Dictionary in rows:
		labels.append(row["label"])
		if row["label"] == "Modulator":
			saw_modulator = row["color"] == modulator
			if String(row["tip"]).is_empty():
				push_error("modulator legend row has no tooltip")
				failures += 1
	if not saw_modulator:
		push_error("legend is missing the modulator swatch")
		failures += 1
	if labels != PackedStringArray(["Input", "Output", "Memory", "Custom", "Core", "Modulator", "Classifier"]):
		push_error("legend labels: %s" % [", ".join(labels)])
		failures += 1
	var schematic_rows: Array[Dictionary] = AreaTypeLegend.entries(SchematicTreeBuilder.CLASSIFIER_COLOR)
	if schematic_rows[-1]["color"] != SchematicTreeBuilder.CLASSIFIER_COLOR:
		push_error("schematic legend must use the schematic classifier color")
		failures += 1
	failures += _test_mapping_legend()
	failures += _test_tint_keeps_padding()
	failures += _test_header_ports_disabled()
	failures += _test_theme_locks_graph_node()
	if failures > 0:
		push_error("area type legend: %d check(s) failed" % failures)
		quit(1)
		return
	print("area type legend: PASS")
	quit(0)


func _test_tint_keeps_padding() -> int:
	var node := GraphNode.new()
	root.add_child(node)
	var failed := 0
	var panel := GraphNodeStyle.tinted(node, &"panel", Color(0.2, 0.3, 0.4)) as StyleBoxFlat
	var title := GraphNodeStyle.tinted(node, &"titlebar", Color.RED) as StyleBoxFlat
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
		var text := FileAccess.get_file_as_string(path)
		if not text.contains("GraphNode/styles/panel") or not text.contains("GraphNode/styles/titlebar") or not text.contains("GraphNode/styles/slot") or not text.contains("GraphNode/constants/port_h_offset"):
			push_error("theme is missing locked GraphNode styles: %s" % path)
			failed = 1
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
	return failed


func _test_mapping_legend() -> int:
	var builder: Array[Dictionary] = AreaTypeLegend.mapping_entries(false)
	var schematic: Array[Dictionary] = AreaTypeLegend.mapping_entries(true)
	var failed := 0
	var builder_labels: PackedStringArray = []
	for row: Dictionary in builder:
		builder_labels.append(row["label"])
		if String(row["tip"]).is_empty():
			push_error("mapping row %s has no tooltip" % row["label"])
			failed = 1
	if builder_labels != PackedStringArray(["Excitatory", "Inhibitory", "Episodic", "Plastic", "Partial"]):
		push_error("circuit builder mapping legend: %s" % [", ".join(builder_labels)])
		failed = 1
	if builder[0]["color"] != CBLineInterTerminal.LINE_COLOR_PSPP or builder[1]["color"] != CBLineInterTerminal.LINE_COLOR_PSPN or builder[2]["color"] != CBLineInterTerminal.LINE_COLOR_EPISODIC:
		push_error("mapping colors drifted from the line colors")
		failed = 1
	if not builder[3]["dashed"] or builder[4]["dashed"]:
		push_error("plastic must be dashed and partial must be solid")
		failed = 1
	if not is_equal_approx(builder[4]["color"].a, CBLineInterTerminal.LINE_COLOR_PARTIAL_MAPPING_TRANSPARENCY):
		push_error("partial legend line is not the partial-mapping fade")
		failed = 1
	var schematic_labels: PackedStringArray = []
	for row: Dictionary in schematic:
		schematic_labels.append(row["label"])
	if schematic_labels != PackedStringArray(["Excitatory", "Inhibitory", "Episodic", "Plastic", "Mixed"]):
		push_error("schematic mapping legend: %s" % [", ".join(schematic_labels)])
		failed = 1
	if not schematic[3]["dashed"]:
		push_error("plastic must be dashed on the schematic legend too")
		failed = 1
	if schematic[-1]["color"] != SchematicEdgeLayer.MIXED_COLOR or schematic[-1]["dashed"]:
		push_error("mixed schematic line must be solid gray")
		failed = 1
	return failed
