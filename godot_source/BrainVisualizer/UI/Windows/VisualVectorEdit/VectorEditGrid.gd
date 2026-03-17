extends Control
class_name VectorEditGrid
## 2D grid for editing vectors at a single Z slice. Center cell = (0, 0). Click to toggle.

const DEFAULT_RADIUS: int = 7  # -7 to 7 = 15x15 grid
const DEFAULT_CELL_SIZE: int = 24

signal cell_toggled(x: int, y: int)

var _radius: int = DEFAULT_RADIUS
var _cell_size: int = DEFAULT_CELL_SIZE
var _selected_at_z: Dictionary = {}  # "x,y" -> true for current Z slice
var _current_z: int = 0
var _full_selection: Dictionary = {}  # "x,y,z" -> true across all Z slices

func setup(radius: int = DEFAULT_RADIUS, cell_size: int = DEFAULT_CELL_SIZE) -> void:
	_radius = radius
	_cell_size = cell_size
	_update_minimum_size()

func _update_minimum_size() -> void:
	var side: int = (2 * _radius + 1) * _cell_size
	custom_minimum_size = Vector2(side, side)

func set_full_selection(selection: Dictionary) -> void:
	_full_selection = selection.duplicate()
	_refresh_slice()

func get_full_selection() -> Dictionary:
	return _full_selection.duplicate()

func set_current_z(z: int) -> void:
	_current_z = z
	_refresh_slice()
	queue_redraw()

func _refresh_slice() -> void:
	_selected_at_z.clear()
	for key in _full_selection.keys():
		var parts: PackedStringArray = key.split(",", false)
		if parts.size() == 3 and int(parts[2]) == _current_z:
			_selected_at_z[parts[0] + "," + parts[1]] = true

func _key(x: int, y: int) -> String:
	return str(x) + "," + str(y)

func _key3(x: int, y: int, z: int) -> String:
	return str(x) + "," + str(y) + "," + str(z)

func _is_selected(x: int, y: int) -> bool:
	return _selected_at_z.has(_key(x, y))

func _local_to_cell(local: Vector2) -> Vector2i:
	var col: int = int(local.x / _cell_size)
	var row: int = int(local.y / _cell_size)
	var half: int = 2 * _radius + 1
	if col < 0 or col >= half or row < 0 or row >= half:
		return Vector2i(-999, -999)
	return Vector2i(col, row)

func _cell_to_xy(col: int, row: int) -> Vector2i:
	var x: int = col - _radius
	var y: int = _radius - row  # row 0 = top = +radius, center row = 0
	return Vector2i(x, y)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var cell: Vector2i = _local_to_cell(mb.position)
			if cell.x >= 0:
				var xy: Vector2i = _cell_to_xy(cell.x, cell.y)
				_toggle(xy.x, xy.y)
				cell_toggled.emit(xy.x, xy.y)
				accept_event()

func _toggle(x: int, y: int) -> void:
	var k: String = _key3(x, y, _current_z)
	if _full_selection.has(k):
		_full_selection.erase(k)
		_selected_at_z.erase(_key(x, y))
	else:
		_full_selection[k] = true
		_selected_at_z[_key(x, y)] = true
	queue_redraw()

func _draw() -> void:
	var half: int = 2 * _radius + 1
	var total: int = half * _cell_size

	for row in half:
		for col in half:
			var x: int = col - _radius
			var y: int = _radius - row
			var rect: Rect2 = Rect2(col * _cell_size, row * _cell_size, _cell_size, _cell_size)
			var border: Color = Color(0.5, 0.5, 0.5, 0.8)
			draw_rect(rect, border)
			if _is_selected(x, y):
				var fill: Color = Color(0.2, 0.6, 0.9, 0.7)
				draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), fill)
			else:
				var fill: Color = Color(0.15, 0.15, 0.15, 0.5)
				draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), fill)

	# Center crosshair
	var cx: float = _radius * _cell_size + _cell_size / 2.0
	var cy: float = _radius * _cell_size + _cell_size / 2.0
	draw_line(Vector2(cx - 6, cy), Vector2(cx + 6, cy), Color(1, 0.5, 0.5))
	draw_line(Vector2(cx, cy - 6), Vector2(cx, cy + 6), Color(1, 0.5, 0.5))
