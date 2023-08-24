extends VBoxContainer
class_name LeftBarTop
## Top Section of the Left Bar Window

var cortical_name: StringName:
	set(v):
		_line_cortical_name.text = v
var cortical_ID: StringName:
	set(v):
		_line_cortical_ID.text = v
var cortical_Type: StringName:
	set(v):
		_line_cortical_type.text = v
var cortical_position: Vector3i:
	get: return _vector_position.current_vector
var cortical_dimension: Vector3i:
	get: return _vector_dimensions.current_vector
	

var _line_cortical_name: TextInput
var _line_cortical_ID: TextInput
var _line_cortical_type: TextInput
var _vector_position: Vector3iField
var _vector_dimensions: Vector3iField


func _ready():
	super._ready()
	_line_cortical_name = $Row_Cortical_Name/Cortical_Name
	_line_cortical_ID = $Row_Cortical_ID/Cortical_ID
	_line_cortical_type = $Row_Cortical_Type/Cortical_Type
	_vector_position = $Cortical_Position
	_vector_dimensions = $Cortical_Size



