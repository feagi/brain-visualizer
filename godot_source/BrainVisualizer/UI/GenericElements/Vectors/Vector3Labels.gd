extends BoxContainer
class_name Vector3Labels


@export var label_x_text: StringName = &"X"
@export var label_y_text: StringName = &"Y"
@export var label_z_text: StringName = &"Z"


func _ready():
	get_node("LabelX").text = label_x_text
	get_node("LabelY").text = label_y_text
	get_node("LabelZ").text = label_z_text
	
