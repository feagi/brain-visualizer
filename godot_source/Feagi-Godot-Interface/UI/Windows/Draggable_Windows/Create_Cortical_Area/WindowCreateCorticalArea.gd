extends GrowingPanel
class_name WindowCreateCorticalArea

signal dimensions_updated(dimensions: Vector3i)
signal location_updated(location: Vector3i)

var _field_cortical_name: TextInput
var _field_3D_coordinates: Vector3iField
var _field_type_radio: RadioButtons
var _field_dimensions: Vector3iField
var _field_channel: IntInput
var _dropdown_cortical_dropdown: TemplateDropDown
var _holder_dropdown: HBoxContainer
var _holder_channel: HBoxContainer

func _ready() -> void:
	_field_cortical_name = $BoxContainer/HBoxContainer/Cortical_Name
	_field_3D_coordinates = $BoxContainer/HBoxContainer2/Coordinates_3D
	_field_type_radio = $BoxContainer/type/options
	_field_dimensions = $BoxContainer/dimensions_holder/Dimensions
	_field_channel = $BoxContainer/channel_holder/Channel_Input
	_dropdown_cortical_dropdown = $BoxContainer/cortical_dropdown_holder/CorticalTemplateDropDown
	_holder_dropdown = $BoxContainer/cortical_dropdown_holder
	_holder_channel = $BoxContainer/channel_holder
	
	_field_type_radio.button_pressed.connect(_radio_button_proxy)

func _radio_button_proxy(button_index: int, button_label: StringName) -> void:
	_switch_UI_between_cortical_types(CorticalArea.CORTICAL_AREA_TYPE[button_label])

func _switch_UI_between_cortical_types(cortical_type: CorticalArea.CORTICAL_AREA_TYPE) -> void:
	match cortical_type:
		CorticalArea.CORTICAL_AREA_TYPE.IPU:
			_holder_dropdown.visible = true
			_holder_channel.visible = true
			_field_dimensions.editable = false
			_field_cortical_name.editable = false
			_dropdown_cortical_dropdown.load_cortical_type_options(cortical_type)
			_dropdown_cortical_dropdown.selected = -1
		CorticalArea.CORTICAL_AREA_TYPE.OPU:
			_holder_dropdown.visible = true
			_holder_channel.visible = true
			_field_dimensions.editable = false
			_field_cortical_name.editable = false
			_dropdown_cortical_dropdown.load_cortical_type_options(cortical_type)
			_dropdown_cortical_dropdown.selected = -1
		CorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			_holder_dropdown.visible = false
			_holder_channel.visible = false
			_field_dimensions.editable = true
			_field_cortical_name.text = ""
			_field_cortical_name.editable = true


func _calculate_IOPU_dimension(input_dimension: Vector3i, channel_count: int) -> Vector3i:
	input_dimension.x = input_dimension.x * channel_count
	return input_dimension
