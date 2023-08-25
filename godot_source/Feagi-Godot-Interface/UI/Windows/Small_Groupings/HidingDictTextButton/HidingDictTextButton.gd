extends BoxContainer
class_name HidingDictTextButton

signal update_request(data: Dictionary)

## Initialization data for the prefab
@export var button_text: StringName

var _stored_data: Dictionary
var _child: BaseButton


func _ready():
	_child = get_child(0)
	_child.text = button_text

## Add data to stored cache, causing button to go visible
func add_data(input: Dictionary) -> void:
	_child.visible = true
	_stored_data.merge(input, true)

## retrieves data that was stored, clears and button hides again
func get_and_clear_data() -> Dictionary:
	_child.visible = false
	var cache: Dictionary = _stored_data.duplicate()
	_stored_data = {}
	return cache

func _signal_data_on_press() -> void:
	custom_minimum_size = _child.size
	update_request.emit(get_and_clear_data())