extends TextureButton
class_name ConnectionButtonPoint
## Side button that connections align themselves to

const CIRCLE_LOGO = "res://Feagi-Godot-Interface/UI/Resources/Icons/info.png"

## Called by parent object [CorticalNode] when it is dragged
signal moved(new_graph_position: Vector2)

enum CONNECTION_STATE {
	DISABLED,
	EMPTY,
	FILLED
}

enum CorticalIO{
	INPUT,
	OUTPUT
}

@export var button_side: CorticalIO

#TODO use this to toggle icon depending on number of connections
var connection_state: CONNECTION_STATE:
	get: return _connection_state
	set(v):
		_connection_state = v

## Since local position is local to the root of the [CorticalNode], we need this to find the position in the graph
var graph_position: Vector2:
	get: return position + _cortical_node_parent.position + (size / 2.0)

var _cortical_node_parent: CorticalNode
var _connection_state: CONNECTION_STATE = CONNECTION_STATE.EMPTY

func _ready():
	_cortical_node_parent = get_parent()
	pressed.connect(_pressed)
	if button_side == CorticalIO.OUTPUT:
		action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS

func _pressed():
	match button_side:
		CorticalIO.OUTPUT:
			_cortical_node_parent.user_started_connection_from.emit(_cortical_node_parent)

			

