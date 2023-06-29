extends Element_Label
class_name Element_Internal_TitleBar
# This is unique header element with dragging functionality. Intended for title bars
# Do NOT spawn this manually


var isDragging: bool:
	get: return _dragger != null

var _dragger


# This never gets called, but here for compatibility reasons
func _DataUpProxy(_data) -> void:
	DataUp.emit(_data, ID, self)
