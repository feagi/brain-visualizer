extends Element_Base
class_name Element_IntField

#TODO - minimum, maximum, prefix, suffix

const D_editable = true

const _specificSettableProps = {
	"value": TYPE_INT,
	"editable": TYPE_BOOL,
}

var value: int:
	get: return _LineEditINT.value
	set(v): _LineEditINT.value = v

var editable: bool:
	get: return _LineEditINT.editable
	set(v): _LineEditINT.editable = v

var _LineEditINT: LineEdit_int_Sub

func _ActivationSecondary(settings: Dictionary) -> void:
	if(_has_label): _LineEditINT = get_children()[1]
	else: _LineEditINT = get_children()[0]
	editable = HelperFuncs.GetIfCan(settings, "editable", D_editable)
	_runtimeSettableProperties.merge(_specificSettableProps)

func _PopulateSubElements() -> Array:
	# used during Activation Primary to add Counter
	return ["intfield"]

func _getChildData() -> Dictionary:
	return {
		"value": value,
	}

func _DataUpProxy(newInt) -> void:
	DataUp.emit({"value": newInt}, ID, self)
