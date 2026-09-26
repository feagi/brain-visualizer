extends RefCounted
class_name IoPerDeviceDimensions
## Per-device volume for one I/O subunit, bounded by the cortical template.
##
## Device count repeats width along X. Height and depth stay the per-device size.
## An axis can be edited only when the template minimum and maximum differ.


static func axis_is_adjustable(minimum: int, maximum: int) -> bool:
	return maximum > minimum


## Reads channel_dimensions_default, channel_dimensions_min, and channel_dimensions_max.
## Returns {ok: false, reason: String} when any triplet is missing or the default is outside the range.
static func bounds_from_subunit(subunit: Dictionary) -> Dictionary:
	var parsed_default: Dictionary = _parse_triplet(subunit.get("channel_dimensions_default", null))
	var parsed_minimum: Dictionary = _parse_triplet(subunit.get("channel_dimensions_min", null))
	var parsed_maximum: Dictionary = _parse_triplet(subunit.get("channel_dimensions_max", null))
	if not parsed_default["ok"] or not parsed_minimum["ok"] or not parsed_maximum["ok"]:
		return {"ok": false, "reason": "Template is missing per-device dimension bounds."}
	var initial: Vector3i = parsed_default["value"]
	var minimum: Vector3i = parsed_minimum["value"]
	var maximum: Vector3i = parsed_maximum["value"]
	if not _range_contains(initial, minimum, maximum):
		return {"ok": false, "reason": "Template default dimensions are outside the allowed range."}
	return {
		"ok": true,
		"initial": initial,
		"minimum": minimum,
		"maximum": maximum,
	}


## Total cortical size written for one subunit. Width is repeated once per device.
static func total_dimensions(per_device: Vector3i, device_count: int) -> Vector3i:
	return Vector3i(per_device.x * device_count, per_device.y, per_device.z)


## Sum of neurons across subunits. per_device_by_subunit maps subunit index to Vector3i.
static func neuron_count(per_device_by_subunit: Dictionary, device_count: int, neurons_per_voxel: int) -> int:
	var total: int = 0
	for subunit_index in per_device_by_subunit.keys():
		var per_device: Vector3i = per_device_by_subunit[subunit_index]
		var dimensions: Vector3i = total_dimensions(per_device, device_count)
		total += dimensions.x * dimensions.y * dimensions.z * neurons_per_voxel
	return total


## API object: subunit index string -> [width, height, depth].
static func to_api_payload(per_device_by_subunit: Dictionary) -> Dictionary:
	var payload: Dictionary = {}
	var subunit_indexes: Array = per_device_by_subunit.keys()
	subunit_indexes.sort()
	for subunit_index in subunit_indexes:
		var per_device: Vector3i = per_device_by_subunit[subunit_index]
		payload[str(int(subunit_index))] = [per_device.x, per_device.y, per_device.z]
	return payload


static func _parse_triplet(raw: Variant) -> Dictionary:
	if raw is not Array or (raw as Array).size() != 3:
		return {"ok": false}
	var parsed: Array[int] = []
	for entry in raw:
		if not (entry is int or entry is float):
			return {"ok": false}
		var number: int = int(entry)
		if float(number) != float(entry) or number < 1:
			return {"ok": false}
		parsed.append(number)
	return {"ok": true, "value": Vector3i(parsed[0], parsed[1], parsed[2])}


static func _range_contains(value: Vector3i, minimum: Vector3i, maximum: Vector3i) -> bool:
	if minimum.x > maximum.x or minimum.y > maximum.y or minimum.z > maximum.z:
		return false
	return (
		value.x >= minimum.x and value.x <= maximum.x
		and value.y >= minimum.y and value.y <= maximum.y
		and value.z >= minimum.z and value.z <= maximum.z
	)
