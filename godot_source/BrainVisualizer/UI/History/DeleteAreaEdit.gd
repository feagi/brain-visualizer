extends GenomeEdit
class_name DeleteAreaEdit
## One cortical-area delete. Each entry keeps the FEAGI property record and the mappings
## that pointed at the area. Undo creates a new id and rewrites those mappings onto it.

const _PUT_SKIP: Array[String] = [
	"properties",
	"cortical_mapping_dst",
	"cortical_id",
	"cortical_id_s",
	"cortical_idx",
	"cortical_name",
	"cortical_dimensions",
	"coordinates_3d",
	"coordinates_2d",
	"cortical_group",
	"cortical_type",
	"area_type",
	"brain_region_id",
	"parent_region_id",
	"cortical_sub_group",
	"group_id",
	"dev_count",
	"device_count",
	"neuron_count",
	"synapse_count",
	"incoming_synapse_count",
	"outgoing_synapse_count",
	"memory_twin_areas",
]

var _areas: Array[Dictionary] = []


func _init() -> void:
	label = "Delete"


func is_empty() -> bool:
	return _areas.is_empty()


func area_count() -> int:
	return _areas.size()


func add_area(snapshot: Dictionary) -> void:
	_areas.append(snapshot)


func snapshot_at(index: int) -> Dictionary:
	return _areas[index]


func original_id_at(index: int) -> String:
	return String(_areas[index]["original_id"])


func restored_id_at(index: int) -> String:
	return String(_areas[index].get("restored_id", ""))


func set_restored_id(index: int, restored_id: String) -> void:
	_areas[index]["restored_id"] = restored_id


func clear_restored_ids() -> void:
	for snapshot in _areas:
		snapshot["restored_id"] = ""


## Original id to the id FEAGI issued on undo. Unrestored areas map to themselves.
func id_map() -> Dictionary:
	var mapped: Dictionary = {}
	for snapshot in _areas:
		var original := String(snapshot["original_id"])
		var restored := String(snapshot.get("restored_id", ""))
		mapped[original] = restored if restored != "" else original
	return mapped


static func can_recreate(cortical_group: String) -> bool:
	var group := cortical_group.to_upper()
	return group == "CUSTOM" or group == "MEMORY" or group == "IPU" or group == "OPU"


static func outgoing_map(properties: Dictionary) -> Dictionary:
	var raw: Variant = {}
	var bag: Variant = properties.get("properties", {})
	if bag is Dictionary and (bag as Dictionary).has("cortical_mapping_dst"):
		raw = (bag as Dictionary)["cortical_mapping_dst"]
	elif properties.has("cortical_mapping_dst"):
		raw = properties["cortical_mapping_dst"]
	if not (raw is Dictionary):
		return {}
	var outgoing: Dictionary = {}
	for destination_id in (raw as Dictionary).keys():
		outgoing[String(destination_id)] = _rules_array((raw as Dictionary)[destination_id])
	return outgoing


## Property keys to send after create. Mappings and identity fields stay out of this payload.
static func update_payload(properties: Dictionary) -> Dictionary:
	var payload: Dictionary = {}
	_copy_payload_fields(properties, payload)
	var bag: Variant = properties.get("properties", {})
	if bag is Dictionary:
		_copy_payload_fields(bag as Dictionary, payload)
	return payload


## Mapping PUTs for one undo. Edges between areas in this step are written once, from the source snapshot.
func mapping_writes() -> Array[Dictionary]:
	var originals: Dictionary = {}
	for snapshot in _areas:
		originals[String(snapshot["original_id"])] = true
	var mapped := id_map()
	var incoming_writes: Array[Dictionary] = []
	var outgoing_writes: Array[Dictionary] = []
	for snapshot in _areas:
		var restored_self: String = mapped[String(snapshot["original_id"])]
		var incoming: Array = snapshot.get("incoming", [])
		for edge in incoming:
			if not (edge is Dictionary):
				continue
			var source_id := String((edge as Dictionary).get("source_id", ""))
			if originals.has(source_id):
				continue
			_append_mapping_write(incoming_writes, _mapped_id(source_id, mapped), restored_self, remap_value((edge as Dictionary).get("rules", []), mapped))
		var outgoing := outgoing_map(snapshot["properties"])
		for destination_id in outgoing.keys():
			_append_mapping_write(outgoing_writes, restored_self, _mapped_id(String(destination_id), mapped), remap_value(outgoing[destination_id], mapped))
	# Inbound mappings are written first. A mapping into memory makes FEAGI create the replay twin.
	incoming_writes.append_array(outgoing_writes)
	return incoming_writes


static func remap_value(value: Variant, id_map: Dictionary) -> Variant:
	if value is String or value is StringName:
		return _mapped_id(String(value), id_map)
	if value is Dictionary:
		var copied: Dictionary = {}
		for key in (value as Dictionary).keys():
			copied[key] = remap_value((value as Dictionary)[key], id_map)
		return copied
	if value is Array:
		var copied: Array = []
		for item in value:
			copied.append(remap_value(item, id_map))
		return copied
	return value


static func _mapped_id(cortical_id: String, id_map: Dictionary) -> String:
	if id_map.has(cortical_id):
		return String(id_map[cortical_id])
	return cortical_id


static func _copy_payload_fields(source: Dictionary, payload: Dictionary) -> void:
	for key in source.keys():
		var field := String(key)
		if field in _PUT_SKIP or payload.has(field):
			continue
		payload[field] = source[key]


## FEAGI creates the memory_replay edge and its twin when an inbound memory mapping is restored.
## The twin from before the delete no longer exists, so that edge is not written back.
static func _append_mapping_write(writes: Array[Dictionary], source_id: String, destination_id: String, rules: Variant) -> void:
	if not (rules is Array):
		return
	var kept: Array = []
	for rule in rules:
		if rule is Dictionary and String((rule as Dictionary).get("morphology_id", "")).to_lower() == "memory_replay":
			continue
		kept.append(rule)
	if kept.is_empty():
		return
	writes.append({
		"source_id": source_id,
		"destination_id": destination_id,
		"rules": kept,
	})


static func _rules_array(raw: Variant) -> Array:
	if raw is Array:
		return (raw as Array).duplicate(true)
	if raw is Dictionary:
		return [(raw as Dictionary).duplicate(true)]
	return []
