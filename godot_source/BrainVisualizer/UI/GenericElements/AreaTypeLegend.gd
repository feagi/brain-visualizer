extends PanelContainer
class_name AreaTypeLegend
## Color key pinned to a GraphEdit. A child that is not a GraphElement stays on screen
## while the graph pans and zooms, which is how Circuit Builder's object menu stays put.
## Bottom-left keeps it clear of that menu, the schematic toolbar, and the minimap.

const MARGIN: float = 16.0
const SWATCH: float = 14.0
const TEXT_COLOR: Color = Color8(220, 220, 220)
const HEADER_COLOR: Color = Color8(160, 164, 172)

var _classifier_color: Color = CBNodeClassifier.CLASSIFIER_BOX_COLOR


var _for_schematic: bool = false
## Export draws the key on its own, at its natural size, instead of pinning it to a graph corner.
var _strip: bool = false


## Adds the key to [param graph]. [param classifier_color] is the color that view paints classifiers.
## [param for_schematic] adds the gray mixed line and leaves out the faded partial mapping, which that view does not draw.
static func add_to(graph: GraphEdit, classifier_color: Color, for_schematic: bool = false) -> AreaTypeLegend:
	var legend := AreaTypeLegend.new()
	legend.name = "AreaTypeLegend"
	legend._classifier_color = classifier_color
	legend._for_schematic = for_schematic
	graph.add_child(legend)
	return legend


## A schematic-key sized for [SchematicExporter] to paste under the canvas. Call before adding to the tree.
func configure_for_export(classifier_color: Color) -> void:
	_classifier_color = classifier_color
	_for_schematic = true
	_strip = true


## Label, swatch color, tooltip. Order is the order shown.
static func entries(classifier_color: Color) -> Array[Dictionary]:
	return [
		{"label": "Input", "color": CBNodeCorticalArea.IPU_BOX_COLOR, "tip": "Input areas (IPU). Signals coming into the brain."},
		{"label": "Output", "color": CBNodeCorticalArea.OPU_BOX_COLOR, "tip": "Output areas (OPU). Signals the brain sends out."},
		{"label": "Memory", "color": CBNodeCorticalArea.MEMORY_BOX_COLOR, "tip": "Memory areas. They store a pattern and can fire it again later."},
		{"label": "Custom", "color": CBNodeCorticalArea.CUSTOM_BOX_COLOR, "tip": "Custom areas. Processing areas you add."},
		{"label": "Core", "color": CBNodeCorticalArea.CORE_BOX_COLOR, "tip": "Core areas. Built into the brain, such as power and death."},
		{"label": "Modulator", "color": CBNodeCorticalArea.MODULATOR_BOX_COLOR, "tip": "Modulator areas. A small driver whose firing changes subscribed areas or connections for a few bursts."},
		{"label": "Classifier", "color": classifier_color, "tip": "Classifiers. They read an area and name the pattern they see."},
	]


## Mapping rows. A plastic mapping is dashed in both views. Circuit Builder also fades a hinted
## partial mapping. The schematic uses gray when one line merges different kinds.
static func mapping_entries(for_schematic: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [
		{"label": "Excitatory", "color": CBLineInterTerminal.LINE_COLOR_PSPP, "dashed": false, "tip": "A mapping that excites its destination. Solid green."},
		{"label": "Inhibitory", "color": CBLineInterTerminal.LINE_COLOR_PSPN, "dashed": false, "tip": "A mapping with a negative weight, unless every rule on it is episodic. Solid red."},
		{"label": "Episodic", "color": CBLineInterTerminal.LINE_COLOR_EPISODIC, "dashed": false, "tip": "Every rule on the mapping is episodic or associative memory. Yellow, ahead of the red inhibitory color."},
		{"label": "Plastic", "color": CBLineInterTerminal.LINE_COLOR_PSPP, "dashed": true, "tip": "At least one rule on the mapping can learn. The line is dashed. Its color is still excitatory, inhibitory, or episodic."},
		{"label": "Associative", "color": CBLineInterTerminal.LINE_COLOR_EPISODIC, "dashed": true, "wavy": true, "tip": "At least one rule on the mapping is associative memory. The line is wavy and dashed. Yellow, like episodic, when every rule is memory."},
	]
	if for_schematic:
		rows.append({"label": "Mixed", "color": SchematicEdgeLayer.MIXED_COLOR, "dashed": false, "tip": "One schematic line stands for mappings of more than one kind. Solid gray."})
		return rows
	var faded := CBLineInterTerminal.LINE_COLOR_PSPP
	faded.a = CBLineInterTerminal.LINE_COLOR_PARTIAL_MAPPING_TRANSPARENCY
	rows.append({"label": "Partial", "color": faded, "dashed": false, "tip": "A hinted mapping from an imported region, not a finished connection. Same color, drawn fainter."})
	return rows


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 10
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.1, 0.11, 0.13, 0.92)
	plate.border_color = Color(0.38, 0.42, 0.48, 1.0)
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(6)
	plate.set_content_margin_all(8)
	add_theme_stylebox_override("panel", plate)
	var columns := HBoxContainer.new()
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_theme_constant_override("separation", 16)
	add_child(columns)
	var areas := VBoxContainer.new()
	areas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	areas.add_theme_constant_override("separation", 4)
	columns.add_child(areas)
	areas.add_child(_header("Areas"))
	for entry: Dictionary in entries(_classifier_color):
		areas.add_child(_row(entry))
	var mappings := VBoxContainer.new()
	mappings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mappings.add_theme_constant_override("separation", 4)
	columns.add_child(mappings)
	mappings.add_child(_header("Mappings"))
	for entry: Dictionary in mapping_entries(_for_schematic):
		mappings.add_child(_line_row(entry))
	if _strip:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		position = Vector2.ZERO
		reset_size()
		return
	var host := get_parent() as Control
	if host != null and not host.resized.is_connected(_place):
		host.resized.connect(_place)
	var graph := host as GraphEdit
	if graph != null and not graph.scroll_offset_changed.is_connected(_place_after_scroll):
		graph.scroll_offset_changed.connect(_place_after_scroll)
	_place.call_deferred()


## Bottom-left anchors, the same way GraphEdit pins its minimap, so the key stays
## inside the view instead of sitting under the left edge.
func _place() -> void:
	var host := get_parent() as Control
	if host == null:
		return
	reset_size()
	var legend_size := get_combined_minimum_size()
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = MARGIN
	offset_right = MARGIN + legend_size.x
	offset_bottom = -MARGIN
	offset_top = -(legend_size.y + MARGIN)


func _place_after_scroll(_offset: Vector2) -> void:
	_place()


func _header(text: String) -> Label:
	var header := Label.new()
	header.text = text
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_color_override("font_color", HEADER_COLOR)
	return header


func _line_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.tooltip_text = entry["tip"]
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_constant_override("separation", 8)
	var mark := LineMark.new()
	mark.line_color = entry["color"]
	mark.dashed = entry["dashed"]
	mark.wavy = bool(entry.get("wavy", false))
	if _for_schematic:
		mark.dashed_width = MappingLineStyle.DASHED_WIDTH_PX
	mark.custom_minimum_size = Vector2(28, SWATCH)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var label := Label.new()
	label.text = entry["label"]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", TEXT_COLOR)
	row.add_child(label)
	return row


func _row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.tooltip_text = entry["tip"]
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_constant_override("separation", 8)
	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(SWATCH, SWATCH)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = entry["color"]
	fill.set_corner_radius_all(2)
	swatch.add_theme_stylebox_override("panel", fill)
	row.add_child(swatch)
	var label := Label.new()
	label.text = entry["label"]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", TEXT_COLOR)
	row.add_child(label)
	return row


class LineMark extends Control:
	## A short sample of a mapping line, drawn with [MappingLineStyle] like the real lines.

	const SAMPLE_POINTS: int = 24
	const WAVE_AMPLITUDE: float = 3.0
	const WAVE_LENGTH: float = 10.0
	const DASH_LENGTH: float = 5.0
	const DASH_GAP: float = 3.0

	var line_color: Color = Color.WHITE
	var dashed: bool = false
	var wavy: bool = false
	## Screen width of the dashes. Circuit Builder still draws dashes at the solid width, so only the
	## schematic key passes [constant MappingLineStyle.DASHED_WIDTH_PX].
	var dashed_width: float = MappingLineStyle.SOLID_WIDTH_PX

	func _draw() -> void:
		var y := size.y * 0.5
		var points := PackedVector2Array()
		for i in SAMPLE_POINTS:
			points.append(Vector2(size.x * float(i) / float(SAMPLE_POINTS - 1), y))
		if wavy:
			points = MappingLineStyle.wave_points(points, WAVE_AMPLITUDE, WAVE_LENGTH)
		if dashed or wavy:
			var segments := MappingLineStyle.dash_segments(points, DASH_LENGTH, DASH_GAP)
			if not segments.is_empty():
				draw_multiline(segments, line_color, dashed_width)
		else:
			draw_polyline(points, line_color, MappingLineStyle.SOLID_WIDTH_PX)
