extends GraphElement
class_name SchematicEdgeLayer
## Draws every merged schematic line in one _draw(), one draw_multiline per colour.
## Covers the whole canvas and ignores input. The schematic keeps it above open region frames and
## below everything else, so lines show inside frames but never over boxes.

const SEGMENTS_PER_CURVE: int = 16
const SCREEN_WIDTH_PX: float = 2.0
const LABEL_MIN_SCREEN_LENGTH_PX: float = 90.0
const LABEL_FONT_SIZE_PX: float = 13.0
const MIXED_COLOR: Color = Color(0.62, 0.62, 0.66)

var _batches: Array[PackedVector2Array] = [] ## per SchematicModel.LINE_KIND, segment pairs
var _colors: Array[Color] = []
var _labels: Array = [] ## [position, text, length]
var _last_zoom: float = -1.0


func _init() -> void:
	name = "SchematicLines"
	selectable = false
	draggable = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colors = [CBLineInterTerminal.LINE_COLOR_PSPP, CBLineInterTerminal.LINE_COLOR_PSPN, CBLineInterTerminal.LINE_COLOR_EPISODIC, MIXED_COLOR]


## [param lines] from [method SchematicModel.group_lines].
func set_lines(model: SchematicModel, lines: Array) -> void:
	position_offset = model.canvas_rect.position
	custom_minimum_size = model.canvas_rect.size
	size = model.canvas_rect.size
	_batches.clear()
	for c in _colors:
		_batches.append(PackedVector2Array())
	_labels.clear()
	for line in lines:
		var from_rect: Rect2 = model.global_rect(line[0])
		var to_rect: Rect2 = model.global_rect(line[1])
		var start: Vector2 = Vector2(from_rect.end.x, from_rect.get_center().y) - position_offset
		var finish: Vector2 = Vector2(to_rect.position.x, to_rect.get_center().y) - position_offset
		var points: PackedVector2Array = _bezier(start, finish)
		var batch: PackedVector2Array = _batches[int(line[3])]
		for i in SEGMENTS_PER_CURVE:
			batch.append(points[i])
			batch.append(points[i + 1])
		_batches[int(line[3])] = batch
		if int(line[2]) > 1:
			_labels.append([points[SEGMENTS_PER_CURVE / 2], str(line[2]), start.distance_to(finish)])
	queue_redraw()


func _process(_delta: float) -> void:
	# Width and label size stay constant on screen, so a zoom change needs a redraw.
	var graph: GraphEdit = get_parent() as GraphEdit
	if graph != null and graph.zoom != _last_zoom:
		_last_zoom = graph.zoom
		queue_redraw()


func _draw() -> void:
	var graph: GraphEdit = get_parent() as GraphEdit
	var zoom: float = maxf(graph.zoom if graph != null else 1.0, 0.0001)
	for i in _batches.size():
		if not _batches[i].is_empty():
			draw_multiline(_batches[i], _colors[i], SCREEN_WIDTH_PX / zoom)
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(1, int(LABEL_FONT_SIZE_PX / zoom))
	for label in _labels:
		if label[2] * zoom >= LABEL_MIN_SCREEN_LENGTH_PX:
			draw_string_outline(font, label[0], label[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(1, int(4.0 / zoom)), Color(0, 0, 0, 0.85))
			draw_string(font, label[0], label[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _bezier(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var reach: float = maxf(80.0, absf(finish.x - start.x) * 0.5)
	var control_out: Vector2 = start + Vector2(reach, 0)
	var control_in: Vector2 = finish - Vector2(reach, 0)
	var points: PackedVector2Array = []
	for i in SEGMENTS_PER_CURVE + 1:
		points.append(start.bezier_interpolate(control_out, control_in, finish, float(i) / SEGMENTS_PER_CURVE))
	return points
