extends VBoxContainer
class_name LeftBarTop
## Top Section of the Left Bar Window
## TODO add field color changing

## User pressed update button, the following changes are requested
signal user_requested_update(changed_values: Dictionary)

var _line_cortical_name: TextInput
var _line_cortical_ID: TextInput
var _line_cortical_type: TextInput
var _vector_position: Vector3iField
var _vector_dimensions: Vector3iField
var _update_button: TextButton_Element
var _growing_cortical_update: Dictionary

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
	print("User requesing Summary changes to cortical area")
	user_requested_update.emit(_growing_cortical_update)

func _user_edit_name(new_name: String) -> void:
	print("User queued name change")
	_growing_cortical_update["cortical_name"] = new_name
	_update_button.disabled = false

func _user_edit_3D_position(new_position: Vector3i) -> void:
	print("User queued position change")
	_growing_cortical_update["cortical_coordinates"] = FEAGIUtils.vector3i_to_array(new_position)
	_update_button.disabled = false

func _user_edit_dimension(new_dimension: Vector3i) -> void:
	print("User queued dimension change")
	_growing_cortical_update["cortical_dimensions"] = FEAGIUtils.vector3i_to_array(new_dimension)
	_update_button.disabled = false
