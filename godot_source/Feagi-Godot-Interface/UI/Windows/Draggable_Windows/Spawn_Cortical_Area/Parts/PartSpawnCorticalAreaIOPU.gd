extends VBoxContainer
class_name PartSpawnCorticalAreaIOPU

signal user_selected_back()
signal user_request_close_window()

var dropdown: TemplateDropDown
var location: Vector3iField
var cortical_name: TextInput
var channel_count: IntInput
var dimensions: Vector3iField

func _ready() -> void:
	dropdown = $input_output_type/TemplateDropDown
	location = $location/location
	cortical_name = $PanelContainer/VBoxContainer/name/name
	channel_count = $PanelContainer/VBoxContainer/channel_count/channel_count
	dimensions = $PanelContainer/VBoxContainer/dimensions/dimensions

func cortical_type_selected(cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE) -> void:
	dropdown.load_cortical_type_options(cortical_type)
	match(cortical_type):
		BaseCorticalArea.CORTICAL_AREA_TYPE.IPU:
			$input_output_type/Label.text = "Select a Input output type"
		BaseCorticalArea.CORTICAL_AREA_TYPE.OPU:
			$input_output_type/Label.text = "Select a motor output type"

func _drop_down_changed(cortical_template: CorticalTemplate) -> void:
	dimensions.current_vector = cortical_template.calculate_IOPU_dimension(channel_count.current_int)
