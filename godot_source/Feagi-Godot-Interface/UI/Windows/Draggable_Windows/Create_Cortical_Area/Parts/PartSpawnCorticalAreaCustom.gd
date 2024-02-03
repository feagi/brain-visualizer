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

func cortical_type_selected(_cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE, preview_close_signals: Array[Signal]) -> void:
	var preview_handler: GenericSinglePreviewHandler = GenericSinglePreviewHandler.new()
	preview_handler.start_BM_preview(dimensions.current_vector, location.current_vector)
	preview_handler.connect_BM_preview(location.user_updated_vector, dimensions.user_updated_vector, preview_close_signals)
