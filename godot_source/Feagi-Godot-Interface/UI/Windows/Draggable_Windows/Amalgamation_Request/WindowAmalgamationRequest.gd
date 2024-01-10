extends DraggableWindow
class_name WindowAmalgamationRequest

signal null_dimchange_signal(val: Vector3i) # Not technically utilized, but needed as a placeholder as a required arg

var _field_title: TextInput
var _field_3d_location: Vector3iSpinboxField

var _amalgamation_ID: StringName
var _circuit_size: Vector3i
var _preview_holder: GenericSinglePreviewHandler


func _ready() -> void:
	super._ready()
	_field_title = $Container/HBoxContainer/AmalgamationTitle
	_field_3d_location = $Container/HBoxContainer2/Coordinates_3D
	_preview_holder = GenericSinglePreviewHandler.new()
	

func setup(amalgamation_ID: StringName, genome_title: StringName, circuit_size: Vector3i) -> void:
	_amalgamation_ID = amalgamation_ID
	_circuit_size = circuit_size
	_field_title.text = genome_title
	_preview_holder.start_BM_preview(_circuit_size, _field_3d_location.current_vector)
	var closed_signals: Array[Signal] = [closed_window_no_name]
	_preview_holder.connect_BM_preview(_field_3d_location.user_updated_vector, null_dimchange_signal, closed_signals)
	
func _cancel_pressed():
	close_window("import_amalgamation")

func _import_pressed():
	FeagiRequests.request_import_amalgamation(_field_3d_location.current_vector, _amalgamation_ID)
	close_window("import_amalgamation", false)

#OVERRIDE
func close_window(window_name: StringName, request_cancel: bool = true) -> void:
	if request_cancel:
		FeagiRequests.request_cancel_amalgamation(_amalgamation_ID)
	super(window_name)
