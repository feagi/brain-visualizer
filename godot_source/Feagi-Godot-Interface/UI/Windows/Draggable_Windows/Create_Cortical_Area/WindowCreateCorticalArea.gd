extends DraggableWindow
class_name WindowCreateCorticalArea

signal dimensions_updated(dimensions: Vector3i)
signal coordinates_updated(location: Vector3i)

var _field_cortical_name: TextInput
var _field_3D_coordinates: Vector3iSpinboxField
var _field_type_radio: RadioButtons
var _field_dimensions: Vector3iSpinboxField
var _field_channel: IntInput
var _dropdown_cortical_dropdown: TemplateDropDown
var _holder_dropdown: HBoxContainer
var _holder_channel: HBoxContainer
var _main_container: ContainerShrinker

func _ready() -> void:
	super._ready()
	_main_container = $Container
	var _create_button: TextButton_Element = $Container/Create_button
	_field_cortical_name = $Container/HBoxContainer/Cortical_Name
	_field_3D_coordinates = $Container/HBoxContainer2/Coordinates_3D
	_field_type_radio = $Container/type/options
	_field_dimensions = $Container/dimensions_holder/Dimensions
	_field_channel = $Container/channel_holder/Channel_Input
	_dropdown_cortical_dropdown = $Container/cortical_dropdown_holder/CorticalTemplateDropDown
	_holder_dropdown = $Container/cortical_dropdown_holder
	_holder_channel = $Container/channel_holder
	
	_create_button.pressed.connect(_create_pressed)
	_field_type_radio.button_pressed.connect(_radio_button_proxy)
	_field_3D_coordinates.user_updated_vector.connect(_coordinate_proxy)
	_field_dimensions.user_updated_vector.connect(_dimensions_updated_proxy)
	_dropdown_cortical_dropdown.template_picked.connect(_template_dropdown_changed)
	_field_channel.int_confirmed.connect(_channel_changed)
	_main_container.recalculate_size()
	
	var preview_close_signals: Array[Signal] = [closed_window_no_name]
	VisConfig.UI_manager.start_new_cortical_area_preview(coordinates_updated, dimensions_updated, preview_close_signals)


func get_selected_type() -> BaseCorticalArea.CORTICAL_AREA_TYPE:
	return BaseCorticalArea.cortical_type_human_readable_str_to_type(_field_type_radio.currently_selected_text)

func _radio_button_proxy(_button_index: int, button_label: StringName) -> void:
	_switch_UI_between_cortical_types(BaseCorticalArea.cortical_type_human_readable_str_to_type(button_label))
	_main_container.recalculate_size()

func _coordinate_proxy(input: Vector3) -> void:
	coordinates_updated.emit(input)


## Called regardless of if updated by user or from template
func _dimensions_updated_proxy(input:Vector3) -> void:
	dimensions_updated.emit(input)


func _template_dropdown_changed(selected_template: CorticalTemplate) -> void:
	var cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE = get_selected_type()
	_field_cortical_name.text = selected_template.cortical_name
	if (cortical_type == BaseCorticalArea.CORTICAL_AREA_TYPE.IPU) || (cortical_type == BaseCorticalArea.CORTICAL_AREA_TYPE.OPU):
		_field_dimensions.current_vector = selected_template.calculate_IOPU_dimension(_field_channel.current_int)
		_dimensions_updated_proxy(_field_dimensions.current_vector)
		return
	if cortical_type == BaseCorticalArea.CORTICAL_AREA_TYPE.CORE:
		_field_dimensions.current_vector = selected_template.resolution
		_dimensions_updated_proxy(_field_dimensions.current_vector)
		return

func _channel_changed(new_channel_count: int) -> void:
	if _dropdown_cortical_dropdown.selected == -1:
		return # nothing to change if no drop down is selected
	var selected_template: CorticalTemplate = _dropdown_cortical_dropdown.get_selected_template()
	_field_dimensions.current_vector = selected_template.calculate_IOPU_dimension(new_channel_count)
	_dimensions_updated_proxy(_field_dimensions.current_vector)

func _switch_UI_between_cortical_types(cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE) -> void:
	_field_cortical_name.text = ""
	match cortical_type:
		BaseCorticalArea.CORTICAL_AREA_TYPE.IPU:
			_holder_dropdown.visible = true
			_holder_channel.visible = true
			_field_dimensions.editable = false
			_field_cortical_name.editable = false
			_dropdown_cortical_dropdown.load_cortical_type_options(cortical_type)
			_dropdown_cortical_dropdown.selected = -1
			_field_cortical_name.placeholder_text = "Will load from Template"
		BaseCorticalArea.CORTICAL_AREA_TYPE.OPU:
			_holder_dropdown.visible = true
			_holder_channel.visible = true
			_field_dimensions.editable = false
			_field_cortical_name.editable = false
			_dropdown_cortical_dropdown.load_cortical_type_options(cortical_type)
			_dropdown_cortical_dropdown.selected = -1
			_field_cortical_name.placeholder_text = "Will load from Template"
		BaseCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			_holder_dropdown.visible = false
			_holder_channel.visible = false
			_field_dimensions.editable = true
			_field_cortical_name.editable = true
			_field_cortical_name.placeholder_text = "Type Name Here"
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			_holder_dropdown.visible = false
			_holder_channel.visible = false
			_field_dimensions.editable = false
			_field_dimensions.current_vector = Vector3i(1,1,1)
			_field_cortical_name.editable = true
			_field_cortical_name.placeholder_text = "Type Name Here"

func _create_pressed():
	var generating_cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE = get_selected_type()
	if generating_cortical_type == BaseCorticalArea.CORTICAL_AREA_TYPE.INVALID:
		VisConfig.show_info_popup("Unable to create cortical area",
		"Please define a cortical area type!",
		"ok")
		
		return
	
	match generating_cortical_type:
		BaseCorticalArea.CORTICAL_AREA_TYPE.IPU:
			if _dropdown_cortical_dropdown.selected == -1:
				VisConfig.show_info_popup("Unable to create cortical area",
				"Please define a template!",
				"ok")
				return 
			FeagiRequests.request_add_IOPU_cortical_area(_dropdown_cortical_dropdown.get_selected_template(), _field_channel.current_int,
				_field_3D_coordinates.current_vector, false)

		BaseCorticalArea.CORTICAL_AREA_TYPE.OPU:
			if _dropdown_cortical_dropdown.selected == -1:
				VisConfig.show_info_popup("Unable to create cortical area",
				"Please define a template!",
				"ok")
				return 
			FeagiRequests.request_add_IOPU_cortical_area(_dropdown_cortical_dropdown.get_selected_template(), _field_channel.current_int,
				_field_3D_coordinates.current_vector, false)

		BaseCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			if _field_cortical_name.text == "":
				VisConfig.show_info_popup("Warning", "Please define a name for your interconnect cortical area", "ok", )
				return
			FeagiRequests.add_custom_cortical_area(_field_cortical_name.text, _field_3D_coordinates.current_vector, _field_dimensions.current_vector,
				false)
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			if _field_cortical_name.text == "":
				VisConfig.show_info_popup("Warning", "Please define a name for your memory cortical area", "ok", )
				return
			FeagiRequests.add_memory_cortical_area(_field_cortical_name.text, _field_3D_coordinates.current_vector, _field_dimensions.current_vector,
				false)
	
	close_window("create_cortical")

