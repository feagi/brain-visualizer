extends Newnit_Box
class_name Connection_Label


var connectionMorphology: String:
	get: return _connectionMorphology
	set(v):
		_connectionMorphology = v
		UpdateText()

var numConnections: int:
	get: return _numConnections
	set(v):
		_numConnections = v
		UpdateText()

var _sourceNode: CortexNode
var _destinationNode: CortexNode
var _connectionMorphology: String
var _numConnections: int
var _buttonElement: Element_Base

func _init(sourceNode: CortexNode, destinationNode: CortexNode, 
morphology: String, numberConnections: int, graph: GraphCore):
	
	_sourceNode = sourceNode
	_destinationNode = destinationNode
	_connectionMorphology = morphology
	numConnections = numberConnections
	graph.add_child(self)
	
	
	UpdateConnectionPosition()
	
	sourceNode.close_request.connect(ConnectingNodeClosed)
	destinationNode.close_request.connect(ConnectingNodeClosed)
	sourceNode.position_offset_changed.connect(UpdateConnectionPosition)
	destinationNode.position_offset_changed.connect(UpdateConnectionPosition)


func UpdateConnectionPosition() -> void:
	position = (_sourceNode.position + _destinationNode.position) / 2.0

func ConnectingNodeClosed() -> void:
	queue_free()

func UpdateText() -> void:
	_buttonElement.fullText = connectionMorphology + ":" + str(numConnections)
	pass
