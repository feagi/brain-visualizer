extends BoxContainer
class_name Vector2iField

signal user_updated_vector(new_vector2: Vector2i)
signal user_interacted()

@export var label_x_text: StringName = &"X"
@export var label_y_text: StringName = &"Y"
@export var int_x_prefix: StringName
@export var int_y_prefix: StringName
@export var int_x_suffix: StringName
@export var int_y_suffix: StringName
@export var int_x_max: int = 9999999999
@export var int_y_max: int = 9999999999
@export var int_x_min: int = -9999999999
@export var int_y_min: int = -9999999999
@export var initial_vector: Vector2i
@export var initial_editable: bool = true

var current_vector: Vector2i:
	get: return Vector2i(_field_x.current_int, _field_y.current_int)
	set(v):
		_field_x.current_int = v.x
		_field_y.current_int = v.y

var editable: bool:
	get: return _editable
	set(v):
		_editable = v
		_field_x.editable = v
		_field_y.editable = v

var _field_x: IntInput
var _field_y: IntInput
var _editable: bool = true

func _ready():
	get_node("LabelX").label_text = label_x_text
	get_node("LabelY").label_text = label_y_text

	_field_x = get_node("IntX")
	_field_y = get_node("IntY")

	_field_x.prefix = int_x_prefix
	_field_x.suffix = int_x_suffix
	_field_x.max_value = int_x_max
	_field_x.min_value = int_x_min
	_field_y.prefix = int_y_prefix
	_field_y.suffix = int_y_suffix
	_field_y.max_value = int_y_max
	_field_y.min_value = int_y_min

	current_vector = initial_vector

	_field_x.int_confirmed.connect(_emit_new_vector)
	_field_y.int_confirmed.connect(_emit_new_vector)

	editable = initial_editable

func _emit_new_vector(_dont_care: int) -> void:
	user_updated_vector.emit(current_vector)
	

