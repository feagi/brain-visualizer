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

func cortical_type_selected(cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, preview_close_signals: Array[Signal]) -> void:
	dropdown.load_cortical_type_options(cortical_type)
	var move_signals: Array[Signal] = [location.user_updated_vector]
	var resize_signals: Array[Signal] = [dimensions.user_updated_vector]
	BV.UI.start_cortical_area_preview(location.current_vector, dimensions.current_vector, move_signals, resize_signals, preview_close_signals)

	match(cortical_type):
		AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			$input_output_type/Label.text = "Select an input type:"
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			$input_output_type/Label.text = "Select an output type:"

func _drop_down_changed(cortical_template: CorticalTemplate) -> void:
	dimensions.current_vector = cortical_template.calculate_IOPU_dimension(int(channel_count.value))
