extends AbstractParameter
class_name OptionalParameter
## Represents an optional value that can be null.

@export var enabled: bool = false
var inner: AbstractParameter

func _init() -> void:
	value_type = TYPE_NIL

## Returns the value of the object in a format that can be written in JSON.
func _get_value_as_JSON() -> Variant:
	if not enabled:
		return null
	if inner == null:
		return null
	var inner_dict := inner.get_as_JSON_formatable_dict()
	if inner_dict.has(inner.label):
		return inner_dict[inner.label]
	return null
