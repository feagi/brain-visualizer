extends VBoxContainer
class_name PartSpawnCorticalAreaCustom

signal user_selected_back()
signal user_request_close_window()

var dimensions: Vector3iField
var location: Vector3iField
var cortical_name: TextInput

func _ready() -> void:
	location = $location/location
	cortical_name = $name/name
	dimensions = $dimensions/dimensions
