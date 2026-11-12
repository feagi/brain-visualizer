extends RefCounted
class_name VectorClipboardPayload
## Clipboard text for the visual vector editor:
## {"feagi_vectors": {"scope": "slice" | "all", "vectors": [[x, y, z], ...]}}
## Static only; no scene or autoload access. For "slice" z is written as 0 and ignored on paste.

const SCOPE_SLICE: String = "slice"
const SCOPE_ALL: String = "all"
const KEY: String = "feagi_vectors"
const MAX_VECTORS: int = 10000


static func encode(scope: String, vectors: Array[Vector3i]) -> String:
	var seen: Dictionary = {}
	var rows: Array = []
	for v in vectors:
		var row: Vector3i = Vector3i(v.x, v.y, 0) if scope == SCOPE_SLICE else v
		if seen.has(row):
			continue
		seen[row] = true
		rows.append([row.x, row.y, row.z])
	return JSON.stringify({KEY: {"scope": scope, "vectors": rows}})


## Returns {} or {"scope": String, "vectors": Array[Vector3i]}. Any bad entry rejects the whole payload.
static func decode(text: String) -> Dictionary:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return {}
	var parsed: Variant = _parse_quiet(trimmed)
	if parsed is String:  # a JSON string literal wrapping the payload
		parsed = _parse_quiet(String(parsed))
	if parsed is not Dictionary:
		return {}
	var root: Dictionary = parsed
	if not root.has(KEY) or root[KEY] is not Dictionary:
		return {}
	var body: Dictionary = root[KEY]
	var scope: Variant = body.get("scope", null)
	if scope is not String or (scope != SCOPE_SLICE and scope != SCOPE_ALL):
		return {}
	var raw: Variant = body.get("vectors", null)
	if raw is not Array:
		return {}
	var raw_vectors: Array = raw
	if raw_vectors.size() > MAX_VECTORS:
		return {}
	var seen: Dictionary = {}
	var out: Array[Vector3i] = []
	for entry in raw_vectors:
		if entry is not Array:
			return {}
		var arr: Array = entry
		if arr.size() != 3:
			return {}
		var x: Variant = VoxelClipboardPayload.variant_to_int_if_possible(arr[0])
		var y: Variant = VoxelClipboardPayload.variant_to_int_if_possible(arr[1])
		var z: Variant = VoxelClipboardPayload.variant_to_int_if_possible(arr[2])
		if x == null or y == null or z == null:
			return {}
		var v: Vector3i = Vector3i(int(x), int(y), int(z))
		if seen.has(v):
			continue
		seen[v] = true
		out.append(v)
	return {"scope": String(scope), "vectors": out}


## JSON.parse_string logs an engine error on every non-JSON clipboard; this stays silent.
static func _parse_quiet(text: String) -> Variant:
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data
