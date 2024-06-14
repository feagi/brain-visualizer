extends BaseDraggableWindow
class_name WindowAmalgamationRequest

const WINDOW_NAME: StringName = "import_amalgamation"

signal null_dimchange_signal(val: Vector3i) # Not technically utilized, but needed as a placeholder as a required arg

var _field_title: TextInput
var _field_3d_location: Vector3iSpinboxField
var _region_button: GenomeObjectSelectorButton

var _amalgamation_ID: StringName
var _circuit_size: Vector3i
var _preview_holder: GenericSinglePreviewHandler


func _ready() -> void:
	super()
	_field_title = _window_internals.get_node('HBoxContainer/AmalgamationTitle')
	_field_3d_location = _window_internals.get_node('HBoxContainer2/Coordinates_3D')
	_region_button = _window_internals.get_node('HBoxContainer4/GenomeObjectSelectorButton')

	

func setup(amalgamation_ID: StringName, genome_title: StringName, circuit_size: Vector3i) -> void:
	_setup_base_window(WINDOW_NAME)
	_amalgamation_ID = amalgamation_ID
	_circuit_size = circuit_size
	_field_title.text = genome_title
	var closed_signals: Array[Signal] = [close_window_requested]
	var move_signals: Array[Signal] = [_field_3d_location.user_updated_vector]
	var resize_signals: Array[Signal] = [null_dimchange_signal]
	_region_button.setup(FeagiCore.feagi_local_cache.brain_regions.get_root_region(), GenomeObject.SINGLE_MAKEUP.SINGLE_BRAIN_REGION)
	BV.UI.start_cortical_area_preview(_field_3d_location.current_vector, _circuit_size, move_signals, resize_signals, closed_signals)


func _import_pressed():
	FeagiCore.requests.request_import_amalgamation(_field_3d_location.current_vector, _amalgamation_ID, _region_button.current_selected.genome_ID)
	close_window(false)

#OVERRIDE
func close_window(request_cancel: bool = true) -> void:
	if request_cancel:
		FeagiCore.requests.cancel_pending_amalgamation(_amalgamation_ID)
	super()
