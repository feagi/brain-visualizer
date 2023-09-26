extends BoxContainer
class_name PatternVector3Field

signal user_updated_vector(new_vector3: PatternVector3)

@export var label_x_text: StringName = &"X"
@export var label_y_text: StringName = &"Y"
@export var label_z_text: StringName = &"Z"
@export var int_x_prefix: StringName
@export var int_y_prefix: StringName
@export var int_z_prefix: StringName
@export var int_x_suffix: StringName
@export var int_y_suffix: StringName
@export var int_z_suffix: StringName
## Due to godot limitations, only ints can go here
@export var initial_vector: Vector3i
@export var initial_editable: bool = true

var current_vector: PatternVector3:
	get: return PatternVector3.new(_field_x.current_patternval, _field_y.current_patternval, _field_z.current_patternval)
	set(v):
		_field_x.current_patternval = v.x
		_field_y.current_patternval = v.y
		_field_z.current_patternval = v.z

var editable: bool:
	get: return _editable
	set(v):
		_editable = v
		_field_x.editable = v
		_field_y.editable = v
		_field_z.editable = v

var _field_x: PatternValInput
var _field_y: PatternValInput
var _field_z: PatternValInput
var _editable: bool = true

func _ready():
	get_node("LabelX").label_text = label_x_text
	get_node("LabelY").label_text = label_y_text
	get_node("LabelZ").label_text = label_z_text

	_field_x = get_node("PVX")
	_field_y = get_node("PVY")
	_field_z = get_node("PVZ")

	_field_x.prefix = int_x_prefix
	_field_x.suffix = int_x_suffix
	_field_y.prefix = int_y_prefix
	_field_y.suffix = int_y_suffix
	_field_z.prefix = int_z_prefix
	_field_z.suffix = int_z_suffix

	_field_x.current_patternval = PatternVal.new(initial_vector.x)
	_field_y.current_patternval = PatternVal.new(initial_vector.y)
	_field_z.current_patternval = PatternVal.new(initial_vector.z)
	

	_field_x.patternval_confirmed.connect(_emit_new_vector)
	_field_y.patternval_confirmed.connect(_emit_new_vector)
	_field_z.patternval_confirmed.connect(_emit_new_vector)
	
	editable = initial_editable

func _emit_new_vector(_dont_care: PatternVal) -> void:
	user_updated_vector.emit(current_vector) # already builds a new object, avoiding reference conflict
	

