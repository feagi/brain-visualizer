extends DraggableWindow
class_name WindowCloneCorticalArea

const NAME_APPEND: StringName = &"_copy"
const OFFSET_3D: Vector3i = Vector3i(10,10,10)
const OFFSET_2D: Vector2i = Vector2i(10,10)

var _field_cortical_name: TextInput
var _field_3d_location: Vector3iSpinboxField
var _field_2d_location: Vector2iSpinboxField
var _cloning_cortical_area: BaseCorticalArea

func _ready() -> void:
	super._ready()
	var _create_button: TextButton_Element = $Container/Create_button
	_field_cortical_name = $Container/HBoxContainer/Cortical_Name
	_field_3d_location = $Container/HBoxContainer2/Coordinates_3D
	_field_2d_location = $Container/HBoxContainer3/Coordinates_2D

func setup(cloning_cortical_area: BaseCorticalArea) -> void:
	_cloning_cortical_area = cloning_cortical_area
	_field_cortical_name.text = cloning_cortical_area.name + NAME_APPEND
	_field_3d_location.current_vector = cloning_cortical_area.coordinates_3D + OFFSET_3D
	_field_2d_location.current_vector = cloning_cortical_area.coordinates_2D + OFFSET_2D

func _clone_pressed():
	FeagiRequests.request_clone_cortical_area(_cloning_cortical_area, _field_cortical_name.text, _field_2d_location.current_vector, _field_3d_location.current_vector)
	close_window("clone_cortical")

