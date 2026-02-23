extends Control
class_name PatternPreviewGrid
## Read-only 2D grid that highlights cells impacted by a [PatternVector3] at a given Z slice.
## Center cell = (0, 0). No user interaction - display only.

const DEFAULT_RADIUS: int = 7
const DEFAULT_CELL_SIZE: int = 24

var _radius: int = DEFAULT_RADIUS
var _cell_size: int = DEFAULT_CELL_SIZE
var _pattern: PatternVector3
var _current_z: int = 0

func setup(radius: int = DEFAULT_RADIUS, cell_size: int = DEFAULT_CELL_SIZE) -> void:
	_radius = radius
	_cell_size = cell_size
	_update_minimum_size()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _update_minimum_size() -> void:
	var side: int = (2 * _radius + 1) * _cell_size
	custom_minimum_size = Vector2(side, side)

func set_pattern(pv: PatternVector3) -> void:
	_pattern = pv
	queue_redraw()

func set_current_z(z: int) -> void:
	_current_z = z
	queue_redraw()

func _is_impacted(x: int, y: int) -> bool:
	if _pattern == null:
		return false
	var x_ok: bool = _pattern.x.isInt and int(_pattern.x.data) == x or !_pattern.x.isInt
	var y_ok: bool = _pattern.y.isInt and int(_pattern.y.data) == y or !_pattern.y.isInt
	var z_ok: bool = _pattern.z.isInt and int(_pattern.z.data) == _current_z or !_pattern.z.isInt
	return x_ok and y_ok and z_ok

func _draw() -> void:
	if _pattern == null:
		return
	var half: int = 2 * _radius + 1
	for row in half:
		for col in half:
			var x: int = col
			var y: int = half - 1 - row
			var rect: Rect2 = Rect2(col * _cell_size, row * _cell_size, _cell_size, _cell_size)
			var border: Color = Color(0.5, 0.5, 0.5, 0.8)
			draw_rect(rect, border)
			if _is_impacted(x, y):
				var fill: Color = Color(0.2, 0.6, 0.9, 0.7)
				draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), fill)
			else:
				var fill: Color = Color(0.15, 0.15, 0.15, 0.5)
				draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), fill)

	var cx: float = _cell_size / 2.0
	var cy: float = (half - 1) * _cell_size + _cell_size / 2.0
	draw_line(Vector2(cx - 6, cy), Vector2(cx + 6, cy), Color(1, 0.5, 0.5))
	draw_line(Vector2(cx, cy - 6), Vector2(cx, cy + 6), Color(1, 0.5, 0.5))
