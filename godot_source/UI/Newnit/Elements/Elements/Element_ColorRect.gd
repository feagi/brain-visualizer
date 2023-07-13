extends Element_Base
class_name Element_ColorRect

const D_color := Color(0.0, 0.0, 0.0, 0.0)
const D_internal_custom_minimum_size = Vector2(20,20)

const _specificSettableProps := {
	"color": TYPE_COLOR,
	"size": TYPE_VECTOR2,
	"position": TYPE_VECTOR2,
}

var color: Color:
	get: return _colorRect.color
	set(v): _colorRect.color

var internal_custom_minimum_size: Vector2:
	get: return _colorRect.custom_minimum_size
	set(v): _colorRect.custom_minimum_size = v

var _colorRect: ColorRect_Sub

func _ActivationSecondary(settings: Dictionary) -> void:
	if(_has_label): _colorRect = get_child(1)
	else: _colorRect = get_child(0)
	color = HelperFuncs.GetIfCan(settings, "color", D_color)
	internal_custom_minimum_size = HelperFuncs.GetIfCan(settings, "internal_custom_minimum_size", D_internal_custom_minimum_size)
	_runtimeSettableProperties.merge(_specificSettableProps)


func _PopulateSubElements() -> Array:
	# used during Activation Primary to add Counter
	return ["colorRect"]

func _getChildData() -> Dictionary:
	return {
		"color": color,
	}

# This never gets called, but here for compatibility reasons
func _DataUpProxy(_data) -> void:
	DataUp.emit(_data, ID, self)

func _SetToolTipText(toolTip: String) -> void:
	_colorRect.tooltip_text = toolTip
