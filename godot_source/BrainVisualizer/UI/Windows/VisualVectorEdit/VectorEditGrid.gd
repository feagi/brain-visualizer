extends Control
class_name VectorEditGrid
## 2D grid for editing vectors at a single Z slice. Center cell = (0, 0). Click to toggle.
## The control keeps a constant pixel side; the grid resolution (radius) changes cell size.

const DEFAULT_RADIUS: int = 7  # -7 to 7 = 15x15 grid
const GRID_SIDE: int = 360
const RADIUS_STEPS: Array[int] = [3, 5, 7, 10, 15, 22]
const INT32_SAFE_HALF: int = 1073741823  # doubling stays inside int32
const UNDO_CAP: int = 100

signal cell_toggled(x: int, y: int)
## Emitted when anything the tool row or hidden note depends on changed.
signal view_changed

var _radius: int = DEFAULT_RADIUS
var _selected_at_z: Dictionary = {}  # "x,y" -> true for current Z slice
var _current_z: int = 0
var _full_selection: Dictionary = {}  # "x,y,z" -> true across all Z slices
var _undo_stack: Array[Dictionary] = []  # previous selections, newest last
var _redo_stack: Array[Dictionary] = []

# ---------- Pure helpers (no scene or autoload access) ----------

## Smallest radius step covering max_abs; 7 when max_abs <= 7; largest step when none covers.
static func radius_step_for(max_abs: int) -> int:
	if max_abs <= DEFAULT_RADIUS:
		return DEFAULT_RADIUS
	for step in RADIUS_STEPS:
		if step >= max_abs:
			return step
	return RADIUS_STEPS[RADIUS_STEPS.size() - 1]

## Returns Vector2i(cell_size, offset) for a radius: the drawn grid is centred in GRID_SIDE.
static func grid_metrics(radius: int) -> Vector2i:
	var n: int = 2 * radius + 1
	var cell: int = int(floor(float(GRID_SIDE) / float(n)))
	var offset: int = int(floor(float(GRID_SIDE - cell * n) / 2.0))
	return Vector2i(cell, offset)

static func max_abs_of_cells(cells: Array[Vector2i]) -> int:
	var m: int = 0
	for c in cells:
		m = maxi(m, maxi(absi(c.x), absi(c.y)))
	return m

## y is up. CW: (x,y)->(y,-x). CCW: (x,y)->(-y,x).
static func rotate_cells(cells: Array[Vector2i], clockwise: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(Vector2i(c.y, -c.x) if clockwise else Vector2i(-c.y, c.x))
	return out

static func can_enlarge(cells: Array[Vector2i]) -> bool:
	for c in cells:
		if absi(c.x) > INT32_SAFE_HALF or absi(c.y) > INT32_SAFE_HALF:
			return false
	return true

## Enlarge: (x,y)->(2x,2y). Shrink: cells within distance 1 stay, others halve toward zero; merges duplicates.
@warning_ignore("integer_division")
static func scale_cells(cells: Array[Vector2i], enlarge: bool) -> Array[Vector2i]:
	var seen: Dictionary = {}
	var out: Array[Vector2i] = []
	if enlarge and not can_enlarge(cells):
		return cells.duplicate()
	for c in cells:
		var n: Vector2i
		if enlarge:
			n = Vector2i(c.x * 2, c.y * 2)
		elif maxi(absi(c.x), absi(c.y)) <= 1:
			n = c
		else:
			n = Vector2i(c.x / 2, c.y / 2)
		if not seen.has(n):
			seen[n] = true
			out.append(n)
	return out

static func cells_at_z(selection: Dictionary, z: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key in selection.keys():
		var parts: PackedStringArray = String(key).split(",", false)
		if parts.size() == 3 and int(parts[2]) == z:
			out.append(Vector2i(int(parts[0]), int(parts[1])))
	return out

static func max_abs_in_selection(selection: Dictionary) -> int:
	var m: int = 0
	for key in selection.keys():
		var parts: PackedStringArray = String(key).split(",", false)
		if parts.size() == 3:
			m = maxi(m, maxi(absi(int(parts[0])), absi(int(parts[1]))))
	return m

## Returns a copy of selection with slice z replaced by new_cells; other slices untouched.
static func replace_slice(selection: Dictionary, z: int, new_cells: Array[Vector2i]) -> Dictionary:
	var out: Dictionary = {}
	for key in selection.keys():
		var parts: PackedStringArray = String(key).split(",", false)
		if parts.size() == 3 and int(parts[2]) == z:
			continue
		out[key] = true
	for c in new_cells:
		out[str(c.x) + "," + str(c.y) + "," + str(z)] = true
	return out

## Returns selection plus vectors; never removes a key. "slice" lands every vector on current_z, "all" keeps each vector's z.
static func merge_vectors(selection: Dictionary, scope: String, vectors: Array[Vector3i], current_z: int) -> Dictionary:
	var out: Dictionary = selection.duplicate()
	for v in vectors:
		var z: int = current_z if scope == "slice" else v.z
		out[str(v.x) + "," + str(v.y) + "," + str(z)] = true
	return out

static func same_selection(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a.keys():
		if not b.has(key):
			return false
	return true

static func count_outside(cells: Array[Vector2i], radius: int) -> int:
	var n: int = 0
	for c in cells:
		if maxi(absi(c.x), absi(c.y)) > radius:
			n += 1
	return n

# ---------- Public API ----------

func setup(radius: int = DEFAULT_RADIUS) -> void:
	_radius = radius
	_update_minimum_size()

func _update_minimum_size() -> void:
	custom_minimum_size = Vector2(GRID_SIDE, GRID_SIDE)

func get_radius() -> int:
	return _radius

func can_radius_down() -> bool:
	return _radius > RADIUS_STEPS[0]

func can_radius_up() -> bool:
	return _radius < RADIUS_STEPS[RADIUS_STEPS.size() - 1]

func step_radius(delta: int) -> void:
	var i: int = RADIUS_STEPS.find(_radius) + delta
	if i < 0 or i >= RADIUS_STEPS.size():
		return
	_radius = RADIUS_STEPS[i]
	queue_redraw()
	view_changed.emit()

func slice_cell_count() -> int:
	return _selected_at_z.size()

func hidden_count() -> int:
	return count_outside(cells_at_z(_full_selection, _current_z), _radius)

func rotate_slice(clockwise: bool) -> void:
	_apply_to_slice(rotate_cells(cells_at_z(_full_selection, _current_z), clockwise))

func scale_slice(enlarge: bool) -> void:
	var cells: Array[Vector2i] = cells_at_z(_full_selection, _current_z)
	if enlarge and not can_enlarge(cells):
		return
	_apply_to_slice(scale_cells(cells, enlarge))
	if enlarge:
		var target: int = radius_step_for(max_abs_of_cells(cells_at_z(_full_selection, _current_z)))
		if target > _radius:
			_radius = target
	queue_redraw()
	view_changed.emit()

func slice_can_enlarge() -> bool:
	return can_enlarge(cells_at_z(_full_selection, _current_z))

func _apply_to_slice(new_cells: Array[Vector2i]) -> void:
	_commit(replace_slice(_full_selection, _current_z, new_cells))

## Single entry point for every selection change: records undo, refreshes, redraws.
## A change that alters nothing records nothing.
func _commit(new_selection: Dictionary) -> void:
	if same_selection(new_selection, _full_selection):
		return
	_undo_stack.append(_full_selection.duplicate())
	if _undo_stack.size() > UNDO_CAP:
		_undo_stack.remove_at(0)
	_redo_stack.clear()
	_full_selection = new_selection
	_refresh_slice()
	queue_redraw()
	view_changed.emit()

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

## Restores the previous selection only; the viewed Z slice and grid resolution stay.
func undo() -> void:
	if _undo_stack.is_empty():
		return
	_redo_stack.append(_full_selection.duplicate())
	_full_selection = _undo_stack.pop_back()
	_refresh_slice()
	queue_redraw()
	view_changed.emit()

func redo() -> void:
	if _redo_stack.is_empty():
		return
	_undo_stack.append(_full_selection.duplicate())
	_full_selection = _redo_stack.pop_back()
	_refresh_slice()
	queue_redraw()
	view_changed.emit()

func clear_slice() -> void:
	_apply_to_slice([] as Array[Vector2i])

## Adds vectors ("slice": onto the viewed Z slice; "all": on their own Z). Never removes.
## Steps the grid resolution up to fit what was pasted, as Enlarge does.
func paste_vectors(scope: String, vectors: Array[Vector3i]) -> void:
	var cells: Array[Vector2i] = []
	for v in vectors:
		cells.append(Vector2i(v.x, v.y))
	var target: int = radius_step_for(max_abs_of_cells(cells))
	if target > _radius:
		_radius = target
		queue_redraw()
		view_changed.emit()
	_commit(merge_vectors(_full_selection, scope, vectors, _current_z))

## Vectors on the viewed Z slice (z = viewed slice).
func slice_vectors() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for c in cells_at_z(_full_selection, _current_z):
		out.append(Vector3i(c.x, c.y, _current_z))
	return out

func all_vectors() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for key in _full_selection.keys():
		var parts: PackedStringArray = String(key).split(",", false)
		if parts.size() == 3:
			out.append(Vector3i(int(parts[0]), int(parts[1]), int(parts[2])))
	return out

func full_cell_count() -> int:
	return _full_selection.size()

func set_full_selection(selection: Dictionary) -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_full_selection = selection.duplicate()
	_radius = radius_step_for(max_abs_in_selection(_full_selection))
	_refresh_slice()
	queue_redraw()
	view_changed.emit()

func get_full_selection() -> Dictionary:
	return _full_selection.duplicate()

func set_current_z(z: int) -> void:
	_current_z = z
	_refresh_slice()
	queue_redraw()
	view_changed.emit()

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
	var m: Vector2i = grid_metrics(_radius)
	var col: int = int(floor((local.x - m.y) / float(m.x)))
	var row: int = int(floor((local.y - m.y) / float(m.x)))
	var n: int = 2 * _radius + 1
	if col < 0 or col >= n or row < 0 or row >= n:
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
	var next: Dictionary = _full_selection.duplicate()
	if next.has(k):
		next.erase(k)
	else:
		next[k] = true
	_commit(next)

func _draw() -> void:
	var n: int = 2 * _radius + 1
	var m: Vector2i = grid_metrics(_radius)
	var cs: int = m.x
	var origin: Vector2 = Vector2(m.y, m.y)
	var inset: int = 2 if cs >= 10 else 1

	for row in n:
		for col in n:
			var x: int = col - _radius
			var y: int = _radius - row
			var rect: Rect2 = Rect2(origin + Vector2(col * cs, row * cs), Vector2(cs, cs))
			draw_rect(rect, Color(0.5, 0.5, 0.5, 0.8))
			var fill: Color = Color(0.2, 0.6, 0.9, 0.7) if _is_selected(x, y) else Color(0.15, 0.15, 0.15, 0.5)
			draw_rect(Rect2(rect.position + Vector2(inset, inset), rect.size - Vector2(inset * 2, inset * 2)), fill)

	# Center crosshair
	var c: float = _radius * cs + cs / 2.0
	var arm: float = minf(6.0, cs / 2.0)
	draw_line(origin + Vector2(c - arm, c), origin + Vector2(c + arm, c), Color(1, 0.5, 0.5))
	draw_line(origin + Vector2(c, c - arm), origin + Vector2(c, c + arm), Color(1, 0.5, 0.5))
