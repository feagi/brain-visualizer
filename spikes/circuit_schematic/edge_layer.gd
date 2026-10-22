extends GraphElement
## Draws every schematic line in one _draw(). It covers the whole canvas, sits behind all boxes and
## takes no input; GraphEdit positions and scales it like any other GraphElement.
## mode "multiline": one draw_multiline per line colour. mode "polyline": one draw_polyline per line.

const KIND_COLORS: Array[Color] = [Color(0.2, 0.75, 0.3), Color(0.85, 0.25, 0.25), Color(0.95, 0.82, 0.08)]
const MIXED_COLOR: Color = Color(0.65, 0.65, 0.65)
const SEGMENTS_PER_CURVE: int = 12
const SCREEN_WIDTH_PX: float = 2.0
const LABEL_MIN_SCREEN_LENGTH_PX: float = 80.0

var mode: String = "multiline"
var draw_cpu_ms: PackedFloat64Array = []

var _graph: GraphEdit
var _batches: Array[PackedVector2Array] = [] ## per colour, segment pairs for draw_multiline
var _batch_colors: Array[Color] = []
var _curves: Array[PackedVector2Array] = []
var _curve_colors: PackedColorArray = []
var _labels: Array = [] ## [position, text, length]
var _last_zoom: float = -1.0


func setup(graph: GraphEdit, model: RefCounted, edges: Array, draw_mode: String) -> void:
	_graph = graph
	mode = draw_mode
	selectable = false
	draggable = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position_offset = model.canvas_rect.position
	size = model.canvas_rect.size
	var colors: Array[Color] = KIND_COLORS.duplicate()
	colors.append(MIXED_COLOR)
	_batch_colors = colors
	for c in colors:
		_batches.append(PackedVector2Array())
	for edge in edges:
		var from_rect: Rect2 = model.global_rect(edge[0])
		var to_rect: Rect2 = model.global_rect(edge[1])
		var start: Vector2 = Vector2(from_rect.end.x, from_rect.get_center().y) - position_offset
		var finish: Vector2 = Vector2(to_rect.position.x, to_rect.get_center().y) - position_offset
		var points: PackedVector2Array = _bezier(start, finish)
		var kind_mask: int = edge[3]
		var color_index: int = 3
		for k in 3:
			if kind_mask == 1 << k:
				color_index = k
		_curves.append(points)
		_curve_colors.append(colors[color_index])
		for i in SEGMENTS_PER_CURVE:
			_batches[color_index].append(points[i])
			_batches[color_index].append(points[i + 1])
		if edge[2] > 1:
			_labels.append([points[SEGMENTS_PER_CURVE / 2], str(edge[2]), start.distance_to(finish)])


func _process(_delta: float) -> void:
	# Line width is held constant on screen, so a zoom change needs a redraw.
	if _graph.zoom != _last_zoom:
		_last_zoom = _graph.zoom
		queue_redraw()


func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	var zoom: float = maxf(_graph.zoom, 0.0001)
	var width: float = SCREEN_WIDTH_PX / zoom
	if mode == "multiline":
		for i in _batches.size():
			if not _batches[i].is_empty():
				draw_multiline(_batches[i], _batch_colors[i], width)
	else:
		for i in _curves.size():
			draw_polyline(_curves[i], _curve_colors[i], width)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(1, int(12.0 / zoom))
	for label in _labels:
		if label[2] * zoom >= LABEL_MIN_SCREEN_LENGTH_PX:
			draw_string(font, label[0], label[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_cpu_ms.append((Time.get_ticks_usec() - started) / 1000.0)


func _bezier(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var reach: float = maxf(80.0, absf(finish.x - start.x) * 0.5)
	var c1: Vector2 = start + Vector2(reach, 0)
	var c2: Vector2 = finish - Vector2(reach, 0)
	var points: PackedVector2Array = []
	for i in SEGMENTS_PER_CURVE + 1:
		var t: float = float(i) / SEGMENTS_PER_CURVE
		points.append(start.bezier_interpolate(c1, c2, finish, t))
	return points
