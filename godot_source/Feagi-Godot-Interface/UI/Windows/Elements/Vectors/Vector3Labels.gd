extends BoxContainer
class_name Vector3Labels


@export var label_x_text: StringName = &"X"
@export var label_y_text: StringName = &"Y"
@export var label_z_text: StringName = &"Z"
@export var spacer_x: int = 1
@export var spacer_y: int = 1
@export var spacer_z: int = 1


func _ready():
	get_node("LabelX").text = label_x_text
	get_node("LabelY").text = label_y_text
	get_node("LabelZ").text = label_z_text
	
	get_node("SpacerX").custom_minimum_size.x = spacer_x
	get_node("SpacerY").custom_minimum_size.x = spacer_y
	get_node("SpacerZ").custom_minimum_size.x = spacer_z

	

