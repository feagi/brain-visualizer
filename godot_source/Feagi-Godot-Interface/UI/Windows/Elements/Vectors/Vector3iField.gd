extends BoxContainer
class_name Vector3iField

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
	get: return Vector3i(_field_x.current_int, _field_y.current_int, _field_z.current_int)
	set(v):
		_field_x.current_int = v.x
		_field_y.current_int = v.y
		_field_z.current_int = v.z

var editable: bool:
	get: return _editable
	set(v):
		_editable = v
		_field_x.editable = v
		_field_y.editable = v
		_field_z.editable = v

var _field_x: IntInput
var _field_y: IntInput
var _field_z: IntInput
var _editable: bool = true
var _default_min_size: Vector2

func _ready():
	get_node("LabelX").text = label_x_text
	get_node("LabelY").text = label_y_text
	get_node("LabelZ").text = label_z_text

	_field_x = get_node("IntX")
	_field_y = get_node("IntY")
	_field_z = get_node("IntZ")

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

	_field_x.int_confirmed.connect(_emit_new_vector)
	_field_y.int_confirmed.connect(_emit_new_vector)
	_field_z.int_confirmed.connect(_emit_new_vector)
	
	_field_x.user_interacted.connect(_emit_user_interaction)
	_field_y.user_interacted.connect(_emit_user_interaction)
	_field_z.user_interacted.connect(_emit_user_interaction)

	editable = initial_editable
	if custom_minimum_size != Vector2(0,0):
		_default_min_size = custom_minimum_size
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)

func _emit_new_vector(_dont_care: int) -> void:
	user_updated_vector.emit(current_vector)

func _emit_user_interaction():
	user_interacted.emit()


func _update_size(multiplier: float) -> void:
	if _default_min_size != Vector2(0,0):
		custom_minimum_size = _default_min_size * multiplier
	size = Vector2(0,0)
