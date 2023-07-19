extends GraphNode
class_name Connection_Label

signal buttonPressed(data: Dictionary)

var numConnections: int:
	get: return _numConnections
	set(v):
		_numConnections = v
		UpdateText()

var sourceNode: CortexNode:
	get: return _sourceNode

var destinationNode: CortexNode:
	get: return _destinationNode
	
var _sourceNode: CortexNode
var _destinationNode: CortexNode
var _numConnections: int
var _button: Button

func _init(sourceNode: CortexNode, destinationNode: CortexNode,
 numberConnections: int, graph: GraphCore):
	
	graph.add_child(self)
	
	comment = true
	var style: StyleBox = StyleBox.new()
	add_theme_stylebox_override("comment", style)
	add_theme_constant_override("title_offset", 0)
	
	_button = Button.new()
	_button.pressed.connect(buttonClicked)
	add_child(_button)
	numConnections = numberConnections
	_sourceNode = sourceNode
	_destinationNode = destinationNode
	UpdateConnectionPosition()
	sourceNode.close_request.connect(ConnectingNodeClosed)
	destinationNode.close_request.connect(ConnectingNodeClosed)
	sourceNode.position_offset_changed.connect(UpdateConnectionPosition)
	destinationNode.position_offset_changed.connect(UpdateConnectionPosition)
	buttonPressed.connect(get_parent()._ProcessConnectionButtonPress)
	draggable = false
	selectable = false

func UpdateConnectionPosition() -> void:
	var sourceRightPos: Vector2 = _sourceNode.position_offset + Vector2(_sourceNode.size.y / 2.0, 0.0)
	var desRightPos: Vector2 = _destinationNode.position_offset + Vector2(_destinationNode.size.y / 2.0, 0.0)
	position_offset = (sourceRightPos  + desRightPos) / 2.0

func ConnectingNodeClosed() -> void:
	queue_free()

func UpdateText() -> void:
	_button.text = str(numConnections)
	pass

func buttonClicked():
	var data := {
		"event": "ConnectionButtonPressed",
		"source": sourceNode.friendlyName,
		"destination": destinationNode.friendlyName
	}
	buttonPressed.emit(data)
	
