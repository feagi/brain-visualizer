extends BaseDraggableWindow
class_name WindowAmalgamationRequest

signal null_dimchange_signal(val: Vector3i) # Not technically utilized, but needed as a placeholder as a required arg

var _field_title: TextInput
var _field_3d_location: Vector3iSpinboxField

var _amalgamation_ID: StringName
var _circuit_size: Vector3i
var _preview_holder: GenericSinglePreviewHandler


func _ready() -> void:
	_field_title = $Container/HBoxContainer/AmalgamationTitle
	_field_3d_location = $Container/HBoxContainer2/Coordinates_3D
	_preview_holder = GenericSinglePreviewHandler.new()
	

func setup_window(amalgamation_ID: StringName, genome_title: StringName, circuit_size: Vector3i) -> void:
	_amalgamation_ID = amalgamation_ID
	_circuit_size = circuit_size
	_field_title.text = genome_title
	var closed_signals: Array[Signal] = [close_window_requested]
	var move_signals: Array[Signal] = [_field_3d_location.user_updated_vector]
	var resize_signals: Array[Signal] = [null_dimchange_signal]
	BV.UI.start_cortical_area_preview(_field_3d_location.current_vector, _circuit_size, move_signals, resize_signals, closed_signals)

	
	
	_setup_base_window("import_amalgamation")
	
func _cancel_pressed():
	close_window()

func _import_pressed():
	###FeagiRequests.request_import_amalgamation(_field_3d_location.current_vector, _amalgamation_ID)
	close_window(false)

#OVERRIDE
func close_window(request_cancel: bool = true) -> void:
	if request_cancel:
		###FeagiRequests.request_cancel_amalgamation(_amalgamation_ID)
		pass
	super()
