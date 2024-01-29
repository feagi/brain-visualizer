extends VBoxContainer
class_name PartSpawnCorticalAreaIOPU

signal user_selected_back()
signal user_request_close_window()

var dropdown: TemplateDropDown
var location: Vector3iSpinboxField
var cortical_name: TextInput
var channel_count: SpinBox
var dimensions: Vector3iSpinboxField

func _ready() -> void:
	dropdown = $input_output_type/TemplateDropDown
	location = $location/location
	cortical_name = $PanelContainer/VBoxContainer/name/name
	channel_count = $PanelContainer/VBoxContainer/channel_count/channel_count
	dimensions = $PanelContainer/VBoxContainer/dimensions/dimensions

func cortical_type_selected(cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE, preview_close_signals: Array[Signal]) -> void:
	dropdown.load_cortical_type_options(cortical_type)
	var preview_handler: GenericSinglePreviewHandler = GenericSinglePreviewHandler.new()
	preview_handler.start_BM_preview(dimensions.current_vector, location.current_vector)
	preview_handler.connect_BM_preview(location.user_updated_vector, dimensions.user_updated_vector, preview_close_signals)
	
	match(cortical_type):
		BaseCorticalArea.CORTICAL_AREA_TYPE.IPU:
			$input_output_type/Label.text = "Select a Input output type"
		BaseCorticalArea.CORTICAL_AREA_TYPE.OPU:
			$input_output_type/Label.text = "Select a motor output type"

func _drop_down_changed(cortical_template: CorticalTemplate) -> void:
	dimensions.current_vector = cortical_template.calculate_IOPU_dimension(channel_count.value)
