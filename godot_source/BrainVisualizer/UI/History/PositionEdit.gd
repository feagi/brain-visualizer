extends GenomeEdit
class_name PositionEdit
## One positional gesture. Stores ids and the coordinates before and after the change.
## Undo and redo send those coordinates back through the same FEAGI calls that saved the gesture.

const KIND_CORTICAL_AREA: int = 0
const KIND_BRAIN_REGION: int = 1
const SPACE_3D: int = 0
const SPACE_2D: int = 1

var _entries: Array[Dictionary] = []


func _init() -> void:
	label = "Move"


func is_empty() -> bool:
	return _entries.is_empty()


func entry_count() -> int:
	return _entries.size()


func entry_at(index: int) -> Dictionary:
	return _entries[index]


## Adds one coordinate change. Equal endpoints are not stored.
func add_change(object_id: StringName, kind: int, space: int, before: Variant, after: Variant) -> void:
	if object_id == &"":
		return
	if before == after:
		return
	_entries.append({
		"id": object_id,
		"kind": kind,
		"space": space,
		"before": before,
		"after": after,
	})


func add_cortical_3d(cortical_id: StringName, before: Vector3i, after: Vector3i) -> void:
	add_change(cortical_id, KIND_CORTICAL_AREA, SPACE_3D, before, after)


func add_region_3d(region_id: StringName, before: Vector3i, after: Vector3i) -> void:
	add_change(region_id, KIND_BRAIN_REGION, SPACE_3D, before, after)


## Cortical areas expose cortical_ID. Circuits expose region_ID. Those properties identify the stored target.
func add_2d_object(genome_object: Object, before: Vector2i, after: Vector2i) -> void:
	if genome_object == null:
		return
	var cortical_id: Variant = genome_object.get("cortical_ID")
	if cortical_id != null and str(cortical_id) != "":
		add_change(StringName(str(cortical_id)), KIND_CORTICAL_AREA, SPACE_2D, before, after)
		return
	var region_id: Variant = genome_object.get("region_ID")
	if region_id != null and str(region_id) != "":
		add_change(StringName(str(region_id)), KIND_BRAIN_REGION, SPACE_2D, before, after)
		return
	push_error("Position history: 2D move target has no cortical or circuit id")


## Builds a 2D edit from the position each object had when the gesture started.
func append_2d_moves(origins: Dictionary, destinations: Dictionary) -> void:
	for genome_object in destinations.keys():
		if not (genome_object is Object):
			push_error("Position history: 2D move target is not a genome object")
			continue
		if not origins.has(genome_object):
			push_error("Position history: 2D move is missing its starting coordinate")
			continue
		var before: Vector2i = origins[genome_object]
		var after: Vector2i = destinations[genome_object]
		add_2d_object(genome_object as Object, before, after)


static func from_2d_moves(move_label: String, origins: Dictionary, destinations: Dictionary) -> PositionEdit:
	var edit := PositionEdit.new()
	edit.label = move_label
	edit.append_2d_moves(origins, destinations)
	return edit


static func cortical_3d_moves(move_label: String, cortical_ids: Array[StringName], befores: Array[Vector3i], afters: Array[Vector3i]) -> PositionEdit:
	var edit := PositionEdit.new()
	edit.label = move_label
	var count: int = mini(cortical_ids.size(), mini(befores.size(), afters.size()))
	for index in count:
		edit.add_cortical_3d(cortical_ids[index], befores[index], afters[index])
	return edit


func vector_at(index: int, forward: bool) -> Variant:
	var entry: Dictionary = _entries[index]
	if forward:
		return entry["after"]
	return entry["before"]


## Reads a FEAGI coordinate payload. Returns {ok, value}. A missing or unknown shape is not a coordinate.
static func parse_vector3i(value: Variant) -> Dictionary:
	if value is Vector3i:
		return {"ok": true, "value": value}
	if value is Array and value.size() >= 3:
		return {"ok": true, "value": Vector3i(int(value[0]), int(value[1]), int(value[2]))}
	if value is Dictionary and value.has("x") and value.has("y") and value.has("z"):
		return {"ok": true, "value": Vector3i(int(value["x"]), int(value["y"]), int(value["z"]))}
	return {"ok": false}
