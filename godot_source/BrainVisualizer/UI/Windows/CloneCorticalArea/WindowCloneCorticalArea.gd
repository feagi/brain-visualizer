extends BaseDraggableWindow
class_name WindowCloneCorticalArea

const WINDOW_NAME: StringName = "clone_cortical"

signal null_dimensions_signal(vector: Vector3i) #not utilized but required as an empty input for a func

const NAME_APPEND: StringName = &"_copy"
const OFFSET_3D: Vector3i = Vector3i(10,0,0)
const OFFSET_2D: Vector2i = Vector2i(10,10)

var _field_cortical_name: TextInput
var _field_3d_location: Vector3iSpinboxField
var _field_2d_location: Vector2iSpinboxField
var _cloning_cortical_area: AbstractCorticalArea
var _preview_holder: GenericSinglePreviewHandler

func _ready() -> void:
	super()
	_field_cortical_name = _window_internals.get_node('HBoxContainer/Cortical_Name')
	_field_3d_location = _window_internals.get_node('HBoxContainer2/Coordinates_3D')
	_field_2d_location = _window_internals.get_node('HBoxContainer3/Coordinates_2D')
	_preview_holder = GenericSinglePreviewHandler.new()

func setup(cloning_cortical_area: AbstractCorticalArea) -> void:
	_setup_base_window(WINDOW_NAME)
	_cloning_cortical_area = cloning_cortical_area
	_field_cortical_name.text = cloning_cortical_area.name + NAME_APPEND
	_field_3d_location.current_vector = cloning_cortical_area.coordinates_3D + OFFSET_3D
	_field_2d_location.current_vector = cloning_cortical_area.coordinates_2D + OFFSET_2D
	
	var closing_signals: Array[Signal] = [close_window_requested]
	var move_signals: Array[Signal] = [_field_3d_location.user_updated_vector]
	var resize_signals: Array[Signal] = [null_dimensions_signal]
	BV.UI.start_cortical_area_preview(_field_3d_location.current_vector, _cloning_cortical_area.dimensions, move_signals, resize_signals, closing_signals)


func _clone_pressed():
	#TODO check for conflicting name and alert user
	FeagiCore.requests.clone_cortical_area(_cloning_cortical_area, _field_cortical_name.text, _field_2d_location.current_vector, _field_3d_location.current_vector, FeagiCore.feagi_local_cache.brain_regions.get_root_region()) #TODO remove root region
	close_window()

