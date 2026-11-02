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


## Adds the key to [param graph]. [param classifier_color] is the color that view paints classifiers.
static func add_to(graph: GraphEdit, classifier_color: Color) -> AreaTypeLegend:
	var legend := AreaTypeLegend.new()
	legend.name = "AreaTypeLegend"
	legend._classifier_color = classifier_color
	graph.add_child(legend)
	return legend


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
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var header := Label.new()
	header.text = "Legend"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_color_override("font_color", HEADER_COLOR)
	column.add_child(header)
	for entry: Dictionary in entries(_classifier_color):
		column.add_child(_row(entry))
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
