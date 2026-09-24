extends RefCounted
class_name SelectionArrange
## Plans align and distribute moves for selected cortical-area positions.
## Positions are FEAGI coordinates_3d. Only the chosen axis changes.
## Align snaps every position to the lowest value on that axis.
## Distribute keeps the lowest and highest values fixed and spaces the rest evenly.
## Even spacing uses integer division, so gaps differ by at most one voxel.

const ACTION_ALIGN: StringName = &"align"
const ACTION_DISTRIBUTE: StringName = &"distribute"
const ALIGN_MINIMUM_COUNT: int = 2
const DISTRIBUTE_MINIMUM_COUNT: int = 3

enum Axis { X, Y, Z }


## True when [param axis] is X, Y, or Z.
static func is_axis(axis: int) -> bool:
	return axis == Axis.X or axis == Axis.Y or axis == Axis.Z


## "X", "Y", or "Z". Empty when [param axis] is not an axis.
static func axis_label(axis: int) -> String:
	match axis:
		Axis.X:
			return "X"
		Axis.Y:
			return "Y"
		Axis.Z:
			return "Z"
		_:
			return ""


## Planned coordinates for [param action] along [param axis], in the same order as [param positions].
static func plan_positions(action: StringName, positions: Array[Vector3i], axis: int) -> Array[Vector3i]:
	if action == ACTION_ALIGN:
		return align_positions(positions, axis)
	if action == ACTION_DISTRIBUTE:
		return distribute_positions(positions, axis)
	push_error("SelectionArrange: unknown action %s" % String(action))
	return _copy_positions(positions)


## Sets every position's [param axis] component to the lowest value in [param positions].
static func align_positions(positions: Array[Vector3i], axis: int) -> Array[Vector3i]:
	if not is_axis(axis):
		push_error("SelectionArrange: axis must be X, Y, or Z")
		return _copy_positions(positions)
	if positions.size() < ALIGN_MINIMUM_COUNT:
		return _copy_positions(positions)
	var target: int = _component(positions[0], axis)
	for position in positions:
		target = mini(target, _component(position, axis))
	var aligned: Array[Vector3i] = []
	for position in positions:
		aligned.append(_with_component(position, axis, target))
	return aligned


## Spaces [param positions] evenly on [param axis]. Endpoints stay put.
## Fewer than 3 positions, or a zero span, returns the input unchanged.
static func distribute_positions(positions: Array[Vector3i], axis: int) -> Array[Vector3i]:
	var distributed: Array[Vector3i] = _copy_positions(positions)
	if not is_axis(axis):
		push_error("SelectionArrange: axis must be X, Y, or Z")
		return distributed
	var count: int = positions.size()
	if count < DISTRIBUTE_MINIMUM_COUNT:
		return distributed
	var order: Array[int] = _order_by_axis(positions, axis)
	var lowest: int = _component(positions[order[0]], axis)
	var highest: int = _component(positions[order[count - 1]], axis)
	if lowest == highest:
		return distributed
	var span: int = highest - lowest
	var slots: int = count - 1
	for rank in count:
		var value: int = lowest + int((rank * span) / slots)
		var index: int = order[rank]
		distributed[index] = _with_component(positions[index], axis, value)
	return distributed


static func _component(position: Vector3i, axis: int) -> int:
	match axis:
		Axis.X:
			return position.x
		Axis.Y:
			return position.y
		Axis.Z:
			return position.z
		_:
			return 0


static func _with_component(position: Vector3i, axis: int, value: int) -> Vector3i:
	var updated := position
	match axis:
		Axis.X:
			updated.x = value
		Axis.Y:
			updated.y = value
		Axis.Z:
			updated.z = value
		_:
			pass
	return updated


static func _copy_positions(positions: Array[Vector3i]) -> Array[Vector3i]:
	var copied: Array[Vector3i] = []
	for position in positions:
		copied.append(position)
	return copied


## Ascending axis value. Equal values keep the earlier input index first.
static func _order_by_axis(positions: Array[Vector3i], axis: int) -> Array[int]:
	var order: Array[int] = []
	for index in positions.size():
		order.append(index)
	for index in range(1, order.size()):
		var key: int = order[index]
		var previous: int = index - 1
		while previous >= 0 and _comes_before(positions, axis, key, order[previous]):
			order[previous + 1] = order[previous]
			previous -= 1
		order[previous + 1] = key
	return order


static func _comes_before(positions: Array[Vector3i], axis: int, index_a: int, index_b: int) -> bool:
	var value_a: int = _component(positions[index_a], axis)
	var value_b: int = _component(positions[index_b], axis)
	if value_a == value_b:
		return index_a < index_b
	return value_a < value_b
