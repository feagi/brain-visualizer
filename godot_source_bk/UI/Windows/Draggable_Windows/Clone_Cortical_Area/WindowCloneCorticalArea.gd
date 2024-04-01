extends BaseDraggableWindow
class_name WindowCloneCorticalArea

signal null_dimensions_signal(vector: Vector3i) #not utilized but required as an empty input for a func

const NAME_APPEND: StringName = &"_copy"
const OFFSET_3D: Vector3i = Vector3i(10,0,0)
const OFFSET_2D: Vector2i = Vector2i(10,10)

var _field_cortical_name: TextInput
var _field_3d_location: Vector3iSpinboxField
var _field_2d_location: Vector2iSpinboxField
var _cloning_cortical_area: BaseCorticalArea
var _preview_holder: GenericSinglePreviewHandler

func _ready() -> void:
	super()
	_field_cortical_name =  _window_internals.get_node('HBoxContainer/Cortical_Name')
	_field_3d_location =  _window_internals.get_node('HBoxContainer2/Coordinates_3D')
	_field_2d_location =  _window_internals.get_node('HBoxContainer3/Coordinates_2D')
	_preview_holder = GenericSinglePreviewHandler.new()

func setup(cloning_cortical_area: BaseCorticalArea) -> void:
	_setup_base_window("clone_cortical")
	_cloning_cortical_area = cloning_cortical_area
	_field_cortical_name.text = cloning_cortical_area.name + NAME_APPEND
	_field_3d_location.current_vector = cloning_cortical_area.coordinates_3D + OFFSET_3D
	_field_2d_location.current_vector = cloning_cortical_area.coordinates_2D + OFFSET_2D
	
	var closing_signals: Array[Signal] = [close_window_requested]
	_preview_holder.start_BM_preview(_cloning_cortical_area.dimensions, _field_3d_location.current_vector)
	_preview_holder.connect_BM_preview(_field_3d_location.user_updated_vector, null_dimensions_signal,closing_signals)

func _clone_pressed():
	FeagiRequests.request_clone_cortical_area(_cloning_cortical_area, _field_cortical_name.text, _field_2d_location.current_vector, _field_3d_location.current_vector)
	close_window()

