extends Control
class_name PatternPreviewGrid
## Read-only 2D grid that highlights cells impacted by a [PatternVector3] at a given Z slice.
## Supports source-relative patterns by accepting an optional reference coordinate.
## Center cell = (0, 0). No user interaction - display only.

const DEFAULT_RADIUS: int = 7
const DEFAULT_CELL_SIZE: int = 24

var _radius: int = DEFAULT_RADIUS
var _cell_size: int = DEFAULT_CELL_SIZE
var _pattern: PatternVector3
var _current_z: int = 0
## Reference coordinate for resolving relative patterns (source neuron position).
## When null, relative patterns highlight the entire axis (legacy behavior).
var _reference_coord: Vector3i = Vector3i.ZERO
var _has_reference: bool = false

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

func set_reference_coordinate(coord: Vector3i) -> void:
	_reference_coord = coord
	_has_reference = true
	queue_redraw()

func clear_reference_coordinate() -> void:
	_has_reference = false
	queue_redraw()

func _is_impacted(x: int, y: int) -> bool:
	if _pattern == null:
		return false
	var x_ok: bool = _matches_axis(_pattern.x, x, _reference_coord.x)
	var y_ok: bool = _matches_axis(_pattern.y, y, _reference_coord.y)
	var z_ok: bool = _matches_axis(_pattern.z, _current_z, _reference_coord.z)
	return x_ok and y_ok and z_ok

func _matches_axis(pv: PatternVal, coord: int, src_coord: int) -> bool:
	if pv.isInt:
		return int(pv.data) == coord
	if pv.isAny:
		return true
	if pv.isMatchingOther:
		if _has_reference:
			return coord == src_coord
		return true
	if pv.isMatchingNot:
		if _has_reference:
			return coord != src_coord
		return true
	if pv.isDirectionPositive:
		if _has_reference:
			return coord > src_coord
		return true
	if pv.isDirectionNegative:
		if _has_reference:
			return coord < src_coord
		return true
	if pv.isDirectionPositiveInclusive:
		if _has_reference:
			return coord >= src_coord
		return true
	if pv.isDirectionNegativeInclusive:
		if _has_reference:
			return coord <= src_coord
		return true
	var s: String = str(pv.data)
	if pv.isOffset:
		if _has_reference:
			var offset: int = _extract_offset(s)
			return coord == src_coord + offset
		return true
	if pv.isRange:
		if _has_reference:
			var bounds: Vector2i = _extract_range(s)
			return coord >= src_coord + bounds.x and coord <= src_coord + bounds.y
		return true
	return true

## Extract numeric offset from "?+N" or "?-N" string.
static func _extract_offset(s: String) -> int:
	var rest: String = s.substr(1)
	return rest.to_int()

## Extract (lo, hi) from "?-A:?+B" range string.
static func _extract_range(s: String) -> Vector2i:
	var parts: PackedStringArray = s.split(":")
	var lo: int = _extract_offset(parts[0])
	var hi: int = _extract_offset(parts[1])
	return Vector2i(lo, hi)

## Convert a local pixel position to grid cell coordinates (x, y).
## Returns Vector2i(-1, -1) if the position is outside the grid bounds.
func get_cell_at_position(local_pos: Vector2) -> Vector2i:
	var half: int = 2 * _radius + 1
	var col: int = int(local_pos.x) / _cell_size
	var row: int = int(local_pos.y) / _cell_size
	if col < 0 or col >= half or row < 0 or row >= half:
		return Vector2i(-1, -1)
	var x: int = col
	var y: int = half - 1 - row
	return Vector2i(x, y)

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

	# Draw origin marker
	var cx: float = _cell_size / 2.0
	var cy: float = (half - 1) * _cell_size + _cell_size / 2.0
	draw_line(Vector2(cx - 6, cy), Vector2(cx + 6, cy), Color(1, 0.5, 0.5))
	draw_line(Vector2(cx, cy - 6), Vector2(cx, cy + 6), Color(1, 0.5, 0.5))

	# Draw reference coordinate marker if set
	if _has_reference and _reference_coord.x < half and _reference_coord.y < half:
		var ref_col: int = _reference_coord.x
		var ref_row: int = half - 1 - _reference_coord.y
		if ref_col >= 0 and ref_col < half and ref_row >= 0 and ref_row < half:
			var ref_cx: float = ref_col * _cell_size + _cell_size / 2.0
			var ref_cy: float = ref_row * _cell_size + _cell_size / 2.0
			draw_circle(Vector2(ref_cx, ref_cy), 4.0, Color(1.0, 0.8, 0.2, 0.9))
