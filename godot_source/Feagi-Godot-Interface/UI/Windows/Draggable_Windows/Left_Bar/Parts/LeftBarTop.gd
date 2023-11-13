extends VBoxContainer
class_name LeftBarTop
## Top Section of the Left Bar Window
## TODO add field color changing

## User pressed update button, the following changes are requested
signal user_requested_update(changed_values: Dictionary)

var top_panel: WindowLeftPanel
var _line_cortical_name: TextInput
var _line_cortical_ID: TextInput
var _line_cortical_type: TextInput
var _vector_position: Vector3iSpinboxField
var _vector_dimensions: Vector3iSpinboxField
var _update_button: TextButton_Element
var _growing_cortical_update: Dictionary
var _is_preview_active: bool = false

func _ready():
	_line_cortical_name = $Row_Cortical_Name/Cortical_Name
	_line_cortical_ID = $Row_Cortical_ID/Cortical_ID
	_line_cortical_type = $Row_Cortical_Type/Cortical_Type
	_vector_position = $Cortical_Position
	_vector_dimensions = $Cortical_Size
	_update_button = $Update_Button

	_line_cortical_name.text_confirmed.connect(_user_edit_name)
	_vector_position.user_updated_vector.connect(_user_edit_3D_position)
	_vector_dimensions.user_updated_vector.connect(_user_edit_dimension)
	_update_button.pressed.connect(_user_requests_update)

## set initial values from FEAGI Cache
func initial_values_from_FEAGI(cortical_reference: CorticalArea) -> void:
	_line_cortical_name.text = cortical_reference.name
	_line_cortical_ID.text = cortical_reference.cortical_ID
	_line_cortical_type.text = CorticalArea.CORTICAL_AREA_TYPE.keys()[cortical_reference.group]
	_vector_position.current_vector = cortical_reference.coordinates_3D
	_vector_dimensions.current_vector = cortical_reference.dimensions
	if cortical_reference.is_dimension_not_editable:
		_vector_dimensions.editable = false

func FEAGI_set_cortical_name(new_name: StringName, _duplicate_ref: CorticalArea):
	print("Left pane recieved new cortical name")
	_line_cortical_name.text = new_name
	_FEAGI_confirmed_update()

func FEAGI_set_cortical_position(new_position: Vector3i, _duplicate_ref: CorticalArea):
	print("Left pane recieved new cortical position")
	_vector_position.current_vector = new_position
	_FEAGI_confirmed_update()

func FEAGI_set_cortical_dimension(new_dimension: Vector3i, _duplicate_ref: CorticalArea):
	print("Left pane recieved new cortical dimensions")
	_vector_dimensions.current_vector = new_dimension
	_FEAGI_confirmed_update()

## FEAGI confirmed changes, show this in the UI and clear the backend dict
func _FEAGI_confirmed_update() -> void:
	_growing_cortical_update = {} # reset queued changes
	_update_button.disabled = true
	# TODO change edited color of fields

## User pressed update button
func _user_requests_update() -> void:
	if _growing_cortical_update == {}:
		# If user presses update button but no properties are set to change, do nothing
		_update_button.disabled = true
		return
	print("User requesing Summary changes to cortical area")
	user_requested_update.emit(_growing_cortical_update)

func _user_edit_name(new_name: String) -> void:
	print("User queued name change")
	_growing_cortical_update["cortical_name"] = new_name

func _user_edit_3D_position(new_position: Vector3i) -> void:
	print("User queued position change")
	_growing_cortical_update["cortical_coordinates"] = FEAGIUtils.vector3i_to_array(new_position)
	if !_is_preview_active:
		_enable_3D_preview()

func _user_edit_dimension(new_dimension: Vector3i) -> void:
	print("User queued dimension change")
	_growing_cortical_update["cortical_dimensions"] = FEAGIUtils.vector3i_to_array(new_dimension)
	if !_is_preview_active:
		_enable_3D_preview()

# Connected via TSCN to editable textboxes
func _enable_update_button():
	_update_button.disabled = false

func _enable_3D_preview():
		var preview_close_signals: Array[Signal] = [_update_button.pressed, top_panel.closed_window_no_name, top_panel.tree_exiting]
		var preview: CorticalBoxPreview = VisConfig.UI_manager.start_new_cortical_area_preview(_vector_position.user_updated_vector, _vector_dimensions.user_updated_vector, preview_close_signals)
		preview.update_size(_vector_dimensions.current_vector)
		preview.update_position(_vector_position.current_vector)
		_is_preview_active = true
