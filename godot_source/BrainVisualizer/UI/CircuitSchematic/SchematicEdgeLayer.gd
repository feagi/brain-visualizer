extends GraphElement
class_name SchematicEdgeLayer
## Draws every merged schematic line in one _draw(), one draw_multiline per colour.
## Covers the whole canvas and ignores input. The schematic keeps it above open region frames and
## below everything else, so lines show inside frames but never over boxes.

const SEGMENTS_PER_CURVE: int = 16
## Wave and dash sizes are canvas units, so they scale with the view like the boxes do and
## the exported image matches what is on screen.
const WAVE_AMPLITUDE_CANVAS: float = 6.0
const WAVE_LENGTH_CANVAS: float = 32.0
const DASH_LENGTH_CANVAS: float = 12.0
const DASH_GAP_CANVAS: float = 8.0
const SCREEN_WIDTH_PX: float = 2.0
const LABEL_MIN_SCREEN_LENGTH_PX: float = 90.0
const LABEL_FONT_SIZE_PX: float = 13.0
const MIXED_COLOR: Color = Color(0.62, 0.62, 0.66)
## Alpha of a line (and its count label) that is not related to the hovered area.
const DIM_ALPHA: float = 0.2

var _batches: Array[PackedVector2Array] = [] ## lit lines: index kind * 2 + dashed, segment pairs
var _dim_batches: Array[PackedVector2Array] = [] ## the same for lines drawn dim
var _colors: Array[Color] = []
var _line_points: Array[PackedVector2Array] = [] ## per line: its segment pairs, kept so highlighting never re-bezier
var _line_slots: Array[int] = []
var _line_labels: Array = [] ## per line: [position, text, length], or null
var _lit_lines: Variant = null ## null = every line lit, else a PackedByteArray with one 0/1 per line
var _last_zoom: float = -1.0


func _init() -> void:
	name = "SchematicLines"
	selectable = false
	draggable = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colors = [CBLineInterTerminal.LINE_COLOR_PSPP, CBLineInterTerminal.LINE_COLOR_PSPN, CBLineInterTerminal.LINE_COLOR_EPISODIC, MIXED_COLOR]


## [param lines] from [method SchematicModel.group_lines]. Resets any highlight.
func set_lines(model: SchematicModel, lines: Array) -> void:
	position_offset = model.canvas_rect.position
	custom_minimum_size = model.canvas_rect.size
	size = model.canvas_rect.size
	_line_points.clear()
	_line_slots.clear()
	_line_labels.clear()
	_lit_lines = null
	for line in lines:
		var from_rect: Rect2 = model.global_rect(line[0])
		var to_rect: Rect2 = model.global_rect(line[1])
		var start: Vector2 = Vector2(from_rect.end.x, from_rect.get_center().y) - position_offset
		var finish: Vector2 = Vector2(to_rect.position.x, to_rect.get_center().y) - position_offset
		var associative: bool = bool(line[5])
		var dashed: bool = bool(line[4]) or associative
		var segments: int = SEGMENTS_PER_CURVE
		var points: PackedVector2Array = _bezier(start, finish, segments)
		var label_at: Vector2 = points[segments / 2]
		if associative:
			points = MappingLineStyle.wave_points(points, WAVE_AMPLITUDE_CANVAS, WAVE_LENGTH_CANVAS)
		var pairs: PackedVector2Array = PackedVector2Array()
		if dashed:
			pairs = MappingLineStyle.dash_segments(points, DASH_LENGTH_CANVAS, DASH_GAP_CANVAS)
		else:
			for i in segments:
				pairs.append(points[i])
				pairs.append(points[i + 1])
		_line_points.append(pairs)
		_line_slots.append(int(line[3]) * 2 + (1 if dashed else 0))
		_line_labels.append([label_at, str(line[2]), start.distance_to(finish)] if int(line[2]) > 1 else null)
	_rebuild_batches()


## Dims every line whose entry in [param lit_lines] is 0; null lights them all. [param lit_lines] has
## one 0/1 per line passed to [method set_lines], in the same order. Only regroups and redraws.
func set_highlight(lit_lines: Variant) -> void:
	_lit_lines = lit_lines
	_rebuild_batches()


func _is_lit(line: int) -> bool:
	return _lit_lines == null or (_lit_lines as PackedByteArray)[line] == 1


func _rebuild_batches() -> void:
	_batches.clear()
	_dim_batches.clear()
	for c in _colors:
		for slot in 2: # solid, dashed
			_batches.append(PackedVector2Array())
			_dim_batches.append(PackedVector2Array())
	for line in _line_points.size():
		var target: Array[PackedVector2Array] = _batches if _is_lit(line) else _dim_batches
		var slot: int = _line_slots[line]
		var batch: PackedVector2Array = target[slot]
		batch.append_array(_line_points[line])
		target[slot] = batch
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
	for i in _dim_batches.size():
		if not _dim_batches[i].is_empty():
			var color: Color = _colors[i / 2]
			color.a = DIM_ALPHA
			draw_multiline(_dim_batches[i], color, SCREEN_WIDTH_PX / zoom)
	for i in _batches.size():
		if not _batches[i].is_empty():
			draw_multiline(_batches[i], _colors[i / 2], SCREEN_WIDTH_PX / zoom)
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(1, int(LABEL_FONT_SIZE_PX / zoom))
	for line in _line_labels.size():
		var label: Variant = _line_labels[line]
		if label == null or label[2] * zoom < LABEL_MIN_SCREEN_LENGTH_PX:
			continue
		var alpha: float = 1.0 if _is_lit(line) else DIM_ALPHA
		draw_string_outline(font, label[0], label[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(1, int(4.0 / zoom)), Color(0, 0, 0, 0.85 * alpha))
		draw_string(font, label[0], label[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, alpha))


func _bezier(start: Vector2, finish: Vector2, segments: int = SEGMENTS_PER_CURVE) -> PackedVector2Array:
	var reach: float = maxf(80.0, absf(finish.x - start.x) * 0.5)
	var control_out: Vector2 = start + Vector2(reach, 0)
	var control_in: Vector2 = finish - Vector2(reach, 0)
	var points: PackedVector2Array = []
	for i in segments + 1:
		points.append(start.bezier_interpolate(control_out, control_in, finish, float(i) / segments))
	return points
