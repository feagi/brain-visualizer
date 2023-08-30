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
var _hiding_container: HiderFrozenSize
var _growing_cortical_update: Dictionary

func _ready():
	_line_cortical_name = $Row_Cortical_Name/Cortical_Name
	_line_cortical_ID = $Row_Cortical_ID/Cortical_ID
	_line_cortical_type = $Row_Cortical_Type/Cortical_Type
	_vector_position = $Cortical_Position
	_vector_dimensions = $Cortical_Size
	_hiding_container = $Update_Button_Hider

	_line_cortical_name.text_confirmed.connect(_user_edit_name)
	_vector_position.user_updated_vector.connect(_user_edit_3D_position)
	_vector_dimensions.user_updated_vector.connect(_user_edit_dimension)
	var update_button: TextButton_Element = _hiding_container.get_node("Update_Button")
	update_button.pressed.connect(_user_requests_update)

## set initial values from FEAGI Cache
func initial_values_from_FEAGI(cortical_reference: CorticalArea) -> void:
	_line_cortical_name.text = cortical_reference.name
	_line_cortical_ID.text = cortical_reference.cortical_ID
	_line_cortical_type.text = str(cortical_reference.group)
	_vector_position.current_vector = cortical_reference.coordinates_3D
	_vector_dimensions.current_vector = cortical_reference.dimensions

func FEAGI_set_cortical_name(new_name: StringName):
	_line_cortical_name.text = new_name
	_FEAGI_confirmed_update()

func FEAGI_set_cortical_position(new_position: Vector3i):
	_vector_position.current_vector = new_position
	_FEAGI_confirmed_update()

func FEAGI_set_cortical_dimension(new_dimension: Vector3i):
	_vector_dimensions.current_vector = new_dimension
	_FEAGI_confirmed_update()

## FEAGI confirmed changes, show this in the UI and clear the backend dict
func _FEAGI_confirmed_update() -> void:
	_growing_cortical_update = {} # reset queued changes
	_hiding_container.toggle_child_visibility(false)
	# TODO change edited color of fields

## User pressed update button
func _user_requests_update() -> void:
	user_requested_update.emit(_growing_cortical_update)

func _user_edit_name(new_name: String) -> void:
	_growing_cortical_update["cortical_name"] = new_name
	_hiding_container.toggle_child_visibility(true)

func _user_edit_3D_position(new_position: Vector3i) -> void:
	_growing_cortical_update["cortical_coordinates"] = str(new_position)
	_hiding_container.toggle_child_visibility(true)

func _user_edit_dimension(new_dimension: Vector3i) -> void:
	_growing_cortical_update["cortical_dimensions"] = str(new_dimension)
	_hiding_container.toggle_child_visibility(true)
