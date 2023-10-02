extends DraggableWindow
class_name WindowCreateCorticalArea

signal dimensions_updated(dimensions: Vector3i)
signal coordinates_updated(location: Vector3i)

var _field_cortical_name: TextInput
var _field_3D_coordinates: Vector3iField
var _field_type_radio: RadioButtons
var _field_dimensions: Vector3iField
var _field_channel: IntInput
var _dropdown_cortical_dropdown: TemplateDropDown
var _holder_dropdown: HBoxContainer
var _holder_channel: HBoxContainer

func _ready() -> void:
	var _create_button: TextButton_Element = $BoxContainer/Create_button
	_field_cortical_name = $BoxContainer/HBoxContainer/Cortical_Name
	_field_3D_coordinates = $BoxContainer/HBoxContainer2/Coordinates_3D
	_field_type_radio = $BoxContainer/type/options
	_field_dimensions = $BoxContainer/dimensions_holder/Dimensions
	_field_channel = $BoxContainer/channel_holder/Channel_Input
	_dropdown_cortical_dropdown = $BoxContainer/cortical_dropdown_holder/CorticalTemplateDropDown
	_holder_dropdown = $BoxContainer/cortical_dropdown_holder
	_holder_channel = $BoxContainer/channel_holder
	
	_create_button.pressed.connect(_create_pressed)
	_field_type_radio.button_pressed.connect(_radio_button_proxy)
	_field_3D_coordinates.user_updated_vector.connect(_coordinate_proxy)
	_field_dimensions.user_updated_vector.connect(_dimensions_updated_proxy)
	_dropdown_cortical_dropdown.template_picked.connect(_template_dropdown_changed)
	_field_channel.int_confirmed.connect(_channel_changed)


func get_selected_type() -> CorticalArea.CORTICAL_AREA_TYPE:
	var selected_str: StringName = _field_type_radio.currently_selected_text
	if selected_str not in CorticalArea.CORTICAL_AREA_TYPE.keys():
		return CorticalArea.CORTICAL_AREA_TYPE.INVALID
	return CorticalArea.CORTICAL_AREA_TYPE[selected_str]


func _radio_button_proxy(_button_index: int, button_label: StringName) -> void:
	_switch_UI_between_cortical_types(CorticalArea.CORTICAL_AREA_TYPE[button_label])


func _coordinate_proxy(input: Vector3) -> void:
	coordinates_updated.emit(input)


## Called regardless of if updated by user or from template
func _dimensions_updated_proxy(input:Vector3) -> void:
	dimensions_updated.emit(input)


func _template_dropdown_changed(selected_template: CorticalTemplate) -> void:
	var cortical_type: CorticalArea.CORTICAL_AREA_TYPE = get_selected_type()
	_field_cortical_name.text = selected_template.cortical_name
	if (cortical_type == CorticalArea.CORTICAL_AREA_TYPE.IPU) || (cortical_type == CorticalArea.CORTICAL_AREA_TYPE.OPU):
		_field_dimensions.current_vector = selected_template.calculate_IOPU_dimension(_field_channel.current_int)
		_dimensions_updated_proxy(_field_dimensions.current_vector)
		return
	if cortical_type == CorticalArea.CORTICAL_AREA_TYPE.CORE:
		_field_dimensions.current_vector = selected_template.resolution
		_dimensions_updated_proxy(_field_dimensions.current_vector)
		return

func _channel_changed(new_channel_count: int) -> void:
	if _dropdown_cortical_dropdown.selected == -1:
		return # nothing to change if no drop down is selected
	var selected_template: CorticalTemplate = _dropdown_cortical_dropdown.get_selected_template()
	_field_dimensions.current_vector = selected_template.calculate_IOPU_dimension(new_channel_count)
	_dimensions_updated_proxy(_field_dimensions.current_vector)

func _switch_UI_between_cortical_types(cortical_type: CorticalArea.CORTICAL_AREA_TYPE) -> void:
	_field_cortical_name.text = ""
	match cortical_type:
		CorticalArea.CORTICAL_AREA_TYPE.IPU:
			_holder_dropdown.visible = true
			_holder_channel.visible = true
			_field_dimensions.editable = false
			_field_cortical_name.editable = false
			_dropdown_cortical_dropdown.load_cortical_type_options(cortical_type)
			_dropdown_cortical_dropdown.selected = -1
			_field_cortical_name.placeholder_text = "Will load from Template"
		CorticalArea.CORTICAL_AREA_TYPE.OPU:
			_holder_dropdown.visible = true
			_holder_channel.visible = true
			_field_dimensions.editable = false
			_field_cortical_name.editable = false
			_dropdown_cortical_dropdown.load_cortical_type_options(cortical_type)
			_dropdown_cortical_dropdown.selected = -1
			_field_cortical_name.placeholder_text = "Will load from Template"
		CorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			_holder_dropdown.visible = false
			_holder_channel.visible = false
			_field_dimensions.editable = true
			_field_cortical_name.editable = true
			_field_cortical_name.placeholder_text = "Type Name Here"

func _create_pressed():
	var generating_cortical_type: CorticalArea.CORTICAL_AREA_TYPE = get_selected_type()
	if generating_cortical_type == CorticalArea.CORTICAL_AREA_TYPE.INVALID:
		push_warning("Unable to create a cortical area when no type is given!")
		return
	
	match generating_cortical_type:
		CorticalArea.CORTICAL_AREA_TYPE.IPU:
			if _dropdown_cortical_dropdown.selected == -1:
				push_warning("Unable to create a cortical area when no template is given!")
				return 
			FeagiRequests.request_add_IOPU_cortical_area(_dropdown_cortical_dropdown.get_selected_template(), _field_channel.current_int,
				_field_3D_coordinates.current_vector, false)

		CorticalArea.CORTICAL_AREA_TYPE.OPU:
			if _dropdown_cortical_dropdown.selected == -1:
				push_warning("Unable to create a cortical area when no template is given!")
				return 
			FeagiRequests.request_add_IOPU_cortical_area(_dropdown_cortical_dropdown.get_selected_template(), _field_channel.current_int,
				_field_3D_coordinates.current_vector, false)

		CorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			if _field_cortical_name.text == "":
				# TODO better check here
				push_warning("Unable to create a custom cortical area with no name!")
				return
			FeagiRequests.add_custom_cortical_area(_field_cortical_name.text, _field_3D_coordinates.current_vector, _field_dimensions.current_vector,
				false)
	
	close_window("create_cortical")

## Called from Window manager, to save previous position
func save_to_memory() -> Dictionary:
	return {
		"position": position,
	}

## Called from Window manager, to load previous position
func load_from_memory(previous_data: Dictionary) -> void:
	position = previous_data["position"]
