extends Element_Base
class_name Element_Label
# Yes, you can add a label to a label, but why?

const D_text := ""
const D_manual_size_flags_vertical = 2
const D_manual_size_flags_horizontal = 2
const _specificSettableProps := {
	"value": TYPE_STRING,
	"text": TYPE_STRING,
	"manual_size_flags_vertical": TYPE_INT,
	"manual_size_flags_horizontal": TYPE_INT
}


var value: String:
	get: return _label.text
	set(v): _label.text = v

var text: String: # Same as 'value', here just for ease of use
	get: return _label.text
	set(v): _label.text = v

var manual_size_flags_vertical: int:
	get: return _label.size_flags_vertical
	set(v): _label.size_flags_vertical = v

var manual_size_flags_horizontal: int:
	get: return _label.size_flags_horizontal
	set(v): _label.size_flags_horizontal = v

var _label: Label_Sub

func _ActivationSecondary(settings: Dictionary) -> void:
	if(_has_label): _label = get_child(1)
	else: _label = get_child(0)
	text = HelperFuncs.GetIfCan(settings, "text", D_text)
	manual_size_flags_vertical = HelperFuncs.GetIfCan(settings, "manual_size_flags_vertical", D_manual_size_flags_vertical)
	manual_size_flags_horizontal = HelperFuncs.GetIfCan(settings, "manual_size_flags_horizontal", D_manual_size_flags_horizontal)
	_runtimeSettableProperties.merge(_specificSettableProps)


func _PopulateSubElements() -> Array:
	# used during Activation Primary to add Counter
	return ["label"]

func _getChildData() -> Dictionary:
	return {
		"value": value,
	}

# This never gets called, but here for compatibility reasons
func _DataUpProxy(_data) -> void:
	DataUp.emit(_data, ID, self)

func _SetToolTipText(toolTip: String) -> void:
	_label.tooltip_text = toolTip
