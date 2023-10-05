extends DraggableWindow
class_name WindowImportCircuit

var _circuit_dropdown: CircuitsDropDown
var _circuit_dimensions: Vector3iField
var _circuit_details: TextEdit
var _circuit_location: Vector3iField

func _ready() -> void:
	_circuit_dropdown = $VBoxContainer/HBoxContainer/CircuitsDropDown
	_circuit_dimensions = $VBoxContainer/HBoxContainer2/Vector
	_circuit_details = $VBoxContainer/HBoxContainer3/TextEdit
	_circuit_location = $VBoxContainer/HBoxContainer4/Vector3fField

	FeagiEvents.retrieved_circuit_details.connect(_on_new_circuit_details)
	_circuit_dropdown.user_selected_circuit.connect(_on_user_select_circuit)

## Called from Window manager, to save previous position
func save_to_memory() -> Dictionary:
	return {
		"position": position,
	}

## Called from Window manager, to load previous position
func load_from_memory(previous_data: Dictionary) -> void:
	position = previous_data["position"]

func _on_user_select_circuit(user_selected_circuit: StringName):
	FeagiRequests.get_circuit_details(user_selected_circuit)

func _on_new_circuit_details(details: CircuitDetails) -> void:
	# First confirm this is the correct one
	if details.friendly_name != _circuit_dropdown.get_current_circuit_friendly_name():
		FeagiRequests.get_circuit_details(_circuit_dropdown.get_current_circuit_file_name())
		return
	_circuit_dimensions.current_vector = details.dimensions
	_circuit_details.text = details.details


func _on_add_press() -> void:
	if _circuit_dropdown.get_current_circuit_friendly_name() == "":
		return # dont proceed if nothing is picked
	FeagiRequests.request_add_circuit(_circuit_dropdown.get_current_circuit_friendly_name(), _circuit_location.current_vector)
