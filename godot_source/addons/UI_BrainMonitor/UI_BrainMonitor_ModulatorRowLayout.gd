extends RefCounted
## Pure slot math for the modulator trigger row (no scene or cache access).

## id -> FEAGI position, in cortical-ID order. With a [param power_anchor] (Vector3i) the row starts
## [param first_slot_from_anchor] slots from it; with null it starts at the first modulator's stored position.
static func compute(stored_positions: Dictionary, spacing_x: int, first_slot_from_anchor: int, power_anchor: Variant = null) -> Dictionary:
	var ids: Array = stored_positions.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var out: Dictionary = {}
	if ids.is_empty():
		return out
	var anchor: Vector3i
	var first_slot: int = 0
	if power_anchor is Vector3i:
		anchor = power_anchor
		first_slot = first_slot_from_anchor
	else:
		anchor = stored_positions[ids[0]]
	for i in ids.size():
		out[ids[i]] = anchor + Vector3i((first_slot + i) * spacing_x, 0, 0)
	return out
