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
