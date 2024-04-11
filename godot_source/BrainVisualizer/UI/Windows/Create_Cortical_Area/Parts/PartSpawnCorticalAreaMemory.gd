extends VBoxContainer
class_name PartSpawnCorticalAreaMemory

signal user_selected_back()
signal user_request_close_window()

var location: Vector3iSpinboxField
var dimensions: Vector3iSpinboxField
var cortical_name: TextInput

func _ready() -> void:
	location = $location/location
	dimensions = $PanelContainer/dimensions/dimensions
	cortical_name = $name/name

func cortical_type_selected(_cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE, preview_close_signals: Array[Signal]) -> void:
	var move_signals: Array[Signal] = [location.user_updated_vector]
	var resize_signals: Array[Signal] = [dimensions.user_updated_vector]
	BV.UI.start_cortical_area_preview(location.current_vector, dimensions.current_vector, move_signals, resize_signals, preview_close_signals)

