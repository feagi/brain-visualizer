extends BaseDraggableWindow
class_name WindowRawConnectivityEdit
## Dialog for raw JSON editing of vector or pattern connectivity rules.
## Validates input and calls on_save with parsed data on success.

const WINDOW_NAME: StringName = &"raw_connectivity_edit"

enum MODE { VECTORS, PATTERNS }

var _text_edit: TextEdit
var _error_label: Label
var _cancel_button: Button
var _save_button: Button
var _mode: MODE
var _on_save: Callable

func _ready() -> void:
	super()
	_text_edit = $WindowPanel/WindowMargin/WindowInternals/Content/TextEdit
	_error_label = $WindowPanel/WindowMargin/WindowInternals/ErrorLabel
	_cancel_button = $WindowPanel/WindowMargin/WindowInternals/ButtonRow/Cancel
	_save_button = $WindowPanel/WindowMargin/WindowInternals/ButtonRow/Save
	_cancel_button.pressed.connect(close_window)
	_save_button.pressed.connect(_on_save_pressed)

func setup(mode: MODE, initial_json: String, on_save: Callable) -> void:
	_setup_base_window(WINDOW_NAME)
	_mode = mode
	_on_save = on_save
	_text_edit.text = initial_json
	_clear_error()
	_titlebar.title = "Raw Edit - " + ("Vectors" if mode == MODE.VECTORS else "Patterns")

func _clear_error() -> void:
	_error_label.text = ""
	_error_label.add_theme_color_override("font_color", Color.WHITE)

func _show_error(msg: String) -> void:
	_error_label.text = msg
	_error_label.add_theme_color_override("font_color", Color.RED)

func _on_save_pressed() -> void:
	_clear_error()
	var raw_text: String = _text_edit.text.strip_edges()
	if raw_text.is_empty():
		_show_error("Content cannot be empty. Use [] for an empty array.")
		return

	var parse_result: Dictionary = _parse_json(raw_text)
	if !parse_result.get("ok", false):
		_show_error(parse_result.get("error", "Unknown parse error"))
		return

	var validated: Dictionary = _validate_structure(parse_result.data)
	if !validated.get("ok", false):
		_show_error(validated.get("error", "Validation failed"))
		return

	_on_save.call(validated.data)
	close_window()

func _parse_json(raw: String) -> Dictionary:
	var json := JSON.new()
	var err: Error = json.parse(raw)
	if err != OK:
		return {"ok": false, "error": "Invalid JSON: " + json.get_error_message()}
	var data: Variant = json.data
	if !(data is Array):
		return {"ok": false, "error": "Expected JSON array as root. Got: " + _type_name(data)}
	return {"ok": true, "data": data}

func _validate_structure(data: Variant) -> Dictionary:
	if _mode == MODE.VECTORS:
		return _validate_vectors(data)
	return _validate_patterns(data)

func _validate_vectors(data: Variant) -> Dictionary:
	if !(data is Array):
		return {"ok": false, "error": "Expected array of vectors. Got: " + _type_name(data)}
	var arr: Array = data
	var result: Array[Vector3i] = []
	for i in arr.size():
		var item = arr[i]
		if !(item is Array):
			return {"ok": false, "error": "Element %d: expected [x,y,z], got %s" % [i, _type_name(item)]}
		var vec_arr: Array = item
		if vec_arr.size() != 3:
			return {"ok": false, "error": "Element %d: expected 3 values [x,y,z], got %d" % [i, vec_arr.size()]}
		var xi: Variant = _to_int(vec_arr[0])
		var yi: Variant = _to_int(vec_arr[1])
		var zi: Variant = _to_int(vec_arr[2])
		if xi == null:
			return {"ok": false, "error": "Element %d: x must be integer, got %s" % [i, str(vec_arr[0])]}
		if yi == null:
			return {"ok": false, "error": "Element %d: y must be integer, got %s" % [i, str(vec_arr[1])]}
		if zi == null:
			return {"ok": false, "error": "Element %d: z must be integer, got %s" % [i, str(vec_arr[2])]}
		result.append(Vector3i(int(xi), int(yi), int(zi)))
	return {"ok": true, "data": result}

func _validate_patterns(data: Variant) -> Dictionary:
	if !(data is Array):
		return {"ok": false, "error": "Expected array of pattern pairs. Got: " + _type_name(data)}
	var arr: Array = data
	var result: Array[PatternVector3Pairs] = []
	for i in arr.size():
		var item = arr[i]
		if !(item is Array):
			return {"ok": false, "error": "Element %d: expected [[src],[dst]], got %s" % [i, _type_name(item)]}
		var pair_arr: Array = item
		if pair_arr.size() != 2:
			return {"ok": false, "error": "Element %d: expected [source,destination] pair, got %d elements" % [i, pair_arr.size()]}
		for j in 2:
			var vec_raw = pair_arr[j]
			if !(vec_raw is Array):
				return {"ok": false, "error": "Element %d vector %d: expected [x,y,z], got %s" % [i, j, _type_name(vec_raw)]}
			var vec_arr: Array = vec_raw
			if vec_arr.size() != 3:
				return {"ok": false, "error": "Element %d vector %d: expected 3 values, got %d" % [i, j, vec_arr.size()]}
			for k in 3:
				if !PatternVal.can_be_PatternVal(vec_arr[k]):
					return {"ok": false, "error": "Element %d vector %d pos %d: unsupported value '%s'. Use int or *, ?, !" % [i, j, k, str(vec_arr[k])]}
				var pv: PatternVal = PatternVal.new(vec_arr[k])
				if pv.isInt and int(pv.data) < 0:
					return {"ok": false, "error": "Element %d vector %d pos %d: voxel coordinates must be >= 0, got %d" % [i, j, k, int(pv.data)]}
		result.append(PatternVector3Pairs.raw_pattern_nested_array_to_array_of_PatternVector3s([pair_arr])[0])
	return {"ok": true, "data": result}

## Returns the value as int, or null if not a valid integer.
func _to_int(v: Variant) -> Variant:
	if v is int:
		return v
	if v is float:
		var iv: int = int(v)
		if float(iv) == v:
			return iv
		return null
	if v is String or v is StringName:
		if str(v).is_valid_int():
			return str(v).to_int()
	return null

func _type_name(v: Variant) -> String:
	var t := typeof(v)
	match t:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "boolean"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "string"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_ARRAY: return "array"
		TYPE_DICTIONARY: return "dictionary"
		_: return "type_" + str(t)
