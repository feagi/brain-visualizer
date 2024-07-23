extends VBoxContainer
class_name PartSpawnCorticalAreaIOPU

signal calculated_dimensions_updated(new_size: Vector3i)

var dropdown: TemplateDropDown
var location: Vector3iSpinboxField
var channel_count: SpinBox
var _current_dimensions_as_per_channel_count: Vector3i = Vector3i(0,0,0)

func _ready() -> void:
	dropdown = $HBoxContainer2/TopSection/TemplateDropDown
	location = $HBoxContainer/Fields/Location
	channel_count = $HBoxContainer/Fields/ChannelCount

func cortical_type_selected(cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, preview_close_signals: Array[Signal]) -> void:
	dropdown.load_cortical_type_options(cortical_type)
	var move_signals: Array[Signal] = [location.user_updated_vector]
	var resize_signals: Array[Signal] = [calculated_dimensions_updated]
	BV.UI.start_cortical_area_preview(location.current_vector, _current_dimensions_as_per_channel_count, move_signals, resize_signals, preview_close_signals)


func _drop_down_changed(cortical_template: CorticalTemplate) -> void:
	_current_dimensions_as_per_channel_count = cortical_template.calculate_IOPU_dimension(int(channel_count.value))
	calculated_dimensions_updated.emit(_current_dimensions_as_per_channel_count)
