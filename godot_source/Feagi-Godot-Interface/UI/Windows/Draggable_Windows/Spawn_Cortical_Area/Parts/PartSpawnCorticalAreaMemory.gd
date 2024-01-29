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
	var preview_handler: GenericSinglePreviewHandler = GenericSinglePreviewHandler.new()
	preview_handler.start_BM_preview(Vector3i(1,1,1), location.current_vector)
	preview_handler.connect_BM_preview(location.user_updated_vector, dimensions.user_updated_vector, preview_close_signals)
