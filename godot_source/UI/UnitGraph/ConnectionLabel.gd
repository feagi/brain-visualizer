extends GraphNode
class_name Connection_Label

signal ButtonPressed(label: Connection_Label)

var numConnections: int:
	get: return _numConnections
	set(v):
		_numConnections = v
		_UpdateText()

var sourceNode: CortexNode:
	get: return _sourceNode

var destinationNode: CortexNode:
	get: return _destinationNode

var _sourceNode: CortexNode
var _destinationNode: CortexNode
var _numConnections: int
var _button: Button
var _graphCoreRef: GraphCore

func _init(inputNode: CortexNode, outputNode: CortexNode,
 numberConnections: int, graph: GraphCore):

	_graphCoreRef = graph
	_graphCoreRef.add_child(self)
	
	comment = true
	var style: StyleBox = StyleBox.new()
	add_theme_stylebox_override("comment", style)
	add_theme_constant_override("title_offset", 0)
	
	_button = Button.new()
	_button.pressed.connect(_ButtonClicked)
	add_child(_button)
	numConnections = numberConnections
	_sourceNode = inputNode
	_destinationNode = outputNode
	_UpdateConnectionPosition()
	sourceNode.position_offset_changed.connect(_UpdateConnectionPosition)
	destinationNode.position_offset_changed.connect(_UpdateConnectionPosition)

	draggable = false
	selectable = false

	_VisuallyConnectNodes()

func DestroyConnection() -> void:
	_VisuallyDisconnectNodes()
	queue_free()

func _UpdateText() -> void:
	_button.text = str(numConnections)
	pass

func _UpdateConnectionPosition() -> void:
	var sourceRightPos: Vector2 = _sourceNode.position_offset + Vector2(_sourceNode.size.y / 2.0, 0.0)
	var desRightPos: Vector2 = _destinationNode.position_offset + Vector2(_destinationNode.size.y / 2.0, 0.0)
	position_offset = (sourceRightPos  + desRightPos) / 2.0

func _ButtonClicked():
	ButtonPressed.emit(self)
	
# Creates the visible line connection
func _VisuallyConnectNodes(fromPort: int = 0, toPort: int = 0) -> void:
	_graphCoreRef.connect_node(sourceNode.corticalID.str, fromPort, destinationNode.corticalID.str, toPort)

# Removes the visible line connection
func _VisuallyDisconnectNodes(fromPort: int = 0, toPort: int = 0) -> void:
	_graphCoreRef.disconnect_node(sourceNode.corticalID.str, fromPort, destinationNode.corticalID.str, toPort)