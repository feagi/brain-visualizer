extends VBoxContainer
class_name PartSpawnCorticalAreaCustom

signal user_selected_back()
signal user_request_close_window()

var dimensions: Vector3iSpinboxField
var location: Vector3iSpinboxField
var cortical_name: TextInput

func _ready() -> void:
	location = $location/location
	cortical_name = $name/name
	dimensions = $dimensions/dimensions

func cortical_type_selected(_cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, preview_close_signals: Array[Signal]) -> void:
	var move_signals: Array[Signal] = [location.user_updated_vector]
	var resize_signals: Array[Signal] = [dimensions.user_updated_vector]
