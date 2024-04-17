extends BoxContainer
class_name Vector3iSpinboxField

signal user_updated_vector(new_vector3: Vector3i)
signal user_interacted()

@export var label_x_text: StringName = &"X"
@export var label_y_text: StringName = &"Y"
@export var label_z_text: StringName = &"Z"
@export var int_x_prefix: StringName
@export var int_y_prefix: StringName
@export var int_z_prefix: StringName
@export var int_x_suffix: StringName
@export var int_y_suffix: StringName
@export var int_z_suffix: StringName
@export var int_x_max: int = 9999999999
@export var int_y_max: int = 9999999999
@export var int_z_max: int = 9999999999
@export var int_x_min: int = -9999999999
@export var int_y_min: int = -9999999999
@export var int_z_min: int = -9999999999
@export var initial_vector: Vector3i
@export var initial_editable: bool = true

var current_vector: Vector3i:
	get: return Vector3i(int(_field_x.value), int(_field_y.value), int(_field_z.value))
	set(v):
		_field_x.set_value_no_signal(int(v.x))
		_field_y.set_value_no_signal(int(v.y))
		_field_z.set_value_no_signal(int(v.z))

var editable: bool:
	get: return _editable
	set(v):
		_editable = v
		_field_x.editable = v
		_field_y.editable = v
		_field_z.editable = v

var _field_x: SpinBox
var _field_y: SpinBox
var _field_z: SpinBox
var _editable: bool = true


func _ready():
	$HBoxContainer/LabelX.text = label_x_text
	$HBoxContainer2/LabelY.text = label_y_text
	$HBoxContainer3/LabelZ.text = label_z_text

	_field_x = $HBoxContainer/IntX
	_field_y = $HBoxContainer2/IntY
	_field_z = $HBoxContainer3/IntZ

	_field_x.prefix = int_x_prefix
	_field_x.suffix = int_x_suffix
	_field_x.max_value = int_x_max
	_field_x.min_value = int_x_min
	_field_y.prefix = int_y_prefix
	_field_y.suffix = int_y_suffix
	_field_y.max_value = int_y_max
	_field_y.min_value = int_y_min
	_field_z.prefix = int_z_prefix
	_field_z.suffix = int_z_suffix
	_field_z.max_value = int_z_max
	_field_z.min_value = int_z_min

	current_vector = initial_vector

	_field_x.value_changed.connect(_emit_new_vector)
	_field_y.value_changed .connect(_emit_new_vector)
	_field_z.value_changed .connect(_emit_new_vector)
	
	_field_x.value_changed .connect(_emit_user_interaction)
	_field_y.value_changed .connect(_emit_user_interaction)
	_field_z.value_changed .connect(_emit_user_interaction)

	editable = initial_editable

func _emit_new_vector(_dont_care: Variant) -> void:
	user_updated_vector.emit(current_vector)

func _emit_user_interaction(_dont_care: Variant):
	user_interacted.emit()

