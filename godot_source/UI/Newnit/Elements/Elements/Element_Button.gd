extends Element_Base
class_name Element_Button
# Yes, you can technically enable the sideButton for this Button element if you wanted to

const D_editable = true
const D_text = " "

const _specificSettableProps := {
	"editable": TYPE_BOOL,
	"text": TYPE_STRING,
	"image": TYPE_STRING
}

var value: bool:
	get: return _Button.button_pressed

var editable: bool:
	get: return _Button.editable
	set(v): _Button.editable = v

var text: String:
	get: return _Button.text
	set(v): _Button.text= v
	
var image: String:
	set(v): _Button.icon = ResourceLoader.load("res://"+v);_Button.expand_icon = true;print("WORKING")

var _Button: Button_Sub

func _ActivationSecondary(settings: Dictionary) -> void:
	if(_has_label): _Button = get_children()[1]
	else: _Button = get_children()[0]
	editable = HelperFuncs.GetIfCan(settings, "editable", D_editable)
	text = HelperFuncs.GetIfCan(settings, "text", D_text)
	if "image" in settings.keys():
		image = settings["image"]
	
	
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
