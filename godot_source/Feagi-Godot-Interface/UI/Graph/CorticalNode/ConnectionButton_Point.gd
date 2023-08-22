extends TextureButton
class_name ConnectionButton_Point
## Side button that connections align themselves to

const CIRCLE_LOGO = "res://Feagi-Godot-Interface/UI/Resources/Icons/info.png"

## Called by parent object [CorticalNode] when it is dragged
signal moved()

enum ConnectionState {
	DISABLED,
	EMPTY,
	LOADING,
	FILLED
}

enum CorticalIO{
	INPUT,
	OUTPUT
}

@export var button_side: CorticalIO

## Since local position is local to the root of the [CorticalNode], we need this to find the position in the graph
var graph_position: Vector2:
	get: return position + _cortical_node_parent.position

var _cortical_node_parent: CorticalNode

func _ready():
	_cortical_node_parent = get_parent()
	pressed.connect(_pressed)
	if button_side == CorticalIO.OUTPUT:
		action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS

func _pressed():
	match button_side:
		CorticalIO.OUTPUT:
			print("waffle")
			_cortical_node_parent.user_started_connection_from.emit(_cortical_node_parent)
			

