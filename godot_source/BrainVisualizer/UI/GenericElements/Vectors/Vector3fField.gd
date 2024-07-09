extends BoxContainer
class_name Vector3fField

signal user_updated_vector(new_vector3: Vector3)
signal user_update_accepted()

@export var label_x_text: StringName
@export var label_y_text: StringName
@export var label_z_text: StringName
@export var float_x_prefix: StringName
@export var float_y_prefix: StringName
@export var float_z_prefix: StringName
@export var float_x_suffix: StringName
@export var float_y_suffix: StringName
@export var float_z_suffix: StringName
@export var float_x_max: float = 9999999999.0
@export var float_y_max: float = 9999999999.0
@export var float_z_max: float = 9999999999.0
@export var float_x_min: float = -9999999999.0
@export var float_y_min: float = -9999999999.0
@export var float_z_min: float = -9999999999.0
@export var initial_vector: Vector3

var current_vector: Vector3:
	get: return Vector3(_field_x.current_float, _field_y.current_float, _field_z.current_float)
	set(v):
		_field_x.current_float = v.x
		_field_y.current_float = v.y
		_field_z.current_float = v.z

var editable: bool:
	get: return _editable
	set(v):
		_editable = v
		_field_x.editable = v
		_field_y.editable = v
		_field_z.editable = v

var _field_x: FloatInput
var _field_y: FloatInput
var _field_z: FloatInput
var _editable: bool = true

func _ready():
	$HBoxContainer/LabelX.text = label_x_text
	$HBoxContainer2/LabelY.text = label_y_text
	$HBoxContainer3/LabelZ.text = label_z_text

	_field_x = $HBoxContainer/FloatX
	_field_y = $HBoxContainer2/FloatY
	_field_z = $HBoxContainer3/FloatZ

	_field_x.prefix = float_x_prefix
	_field_x.suffix = float_x_suffix
	_field_x.max_value = float_x_max
	_field_x.min_value = float_x_min
	_field_y.prefix = float_y_prefix
	_field_y.suffix = float_y_suffix
	_field_y.max_value = float_y_max
	_field_y.min_value = float_y_min
	_field_z.prefix = float_z_prefix
	_field_z.suffix = float_z_suffix
	_field_z.max_value = float_z_max
	_field_z.min_value = float_z_min

	current_vector = initial_vector

	_field_x.float_confirmed.connect(_emit_new_vector)
	_field_y.float_confirmed.connect(_emit_new_vector)
	_field_z.float_confirmed.connect(_emit_new_vector)

	_field_x.user_update_accepted.connect(_emit_user_update_accepted)
	_field_y.user_update_accepted.connect(_emit_user_update_accepted)
	_field_z.user_update_accepted.connect(_emit_user_update_accepted)

func _emit_new_vector(_dont_care: float) -> void:
	user_updated_vector.emit(current_vector)
	
func _emit_user_update_accepted():
	user_update_accepted.emit()
