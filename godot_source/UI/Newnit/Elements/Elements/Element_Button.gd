extends Element_Base
class_name Element_Button
# Yes, you can technically enable the sideButton for this Button element if you wanted to

const D_editable = true
const D_fullText = " "
const D_maxTextLength := 100

const _specificSettableProps := {
	"editable": TYPE_BOOL,
	"text": TYPE_STRING,
	"image": TYPE_STRING,
	"fullText": TYPE_STRING,
	"maxTextLength": TYPE_INT
}

var fullText: String:
	get: return _fullText
	set(v): 
		text = HelperFuncs.ShortText(v, maxTextLength)
		_fullText = v

var value: bool:
	get: return _Button.button_pressed

var editable: bool:
	get: return _Button.editable
	set(v): _Button.editable = v

var text: String:
	get: return _Button.text
	set(v): _Button.text= v

var maxTextLength: int
var _fullText: String
var _Button: Button_Sub

func _ActivationSecondary(settings: Dictionary) -> void:
	if(_has_label): _Button = get_children()[1]
	else: _Button = get_children()[0]
	editable = HelperFuncs.GetIfCan(settings, "editable", D_editable)
	maxTextLength = HelperFuncs.GetIfCan(settings, "maxTextLength", D_maxTextLength)
	fullText = HelperFuncs.GetIfCan(settings, "fullText", D_fullText)
	if "text" in settings.keys(): text = settings["text"]
	
	
	
	_runtimeSettableProperties.merge(_specificSettableProps)

func _PopulateSubElements() -> Array:
	# used during Activation Primary to add Counter
	return ["button"]

func _getChildData() -> Dictionary:
	return {
		"value": value,
	}

func _DataUpProxy(_data) -> void:
	DataUp.emit({"value": true}, ID, self)

func _SetToolTipText(toolTip: String) -> void:
	_Button.tooltip_text = toolTip
