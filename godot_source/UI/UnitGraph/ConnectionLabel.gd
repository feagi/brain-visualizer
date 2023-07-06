extends Newnit_Box
class_name Connection_Label


var numConnections: int:
	get: return _numConnections
	set(v):
		_numConnections = v
		UpdateText()

var _sourceNode: CortexNode
var _destinationNode: CortexNode
var _numConnections: int
var _buttonElement: Element_Base

func _init(sourceNode: CortexNode, destinationNode: CortexNode,
 numberConnections: int, graph: GraphCore):
	
	graph.add_child(self)
	var activationDict = {
		"ID": sourceNode.corticalID + "_" + destinationNode.corticalID,
		"type": "box",
		"components": [
			{
				"type":"button",
				"ID":"openMorphologyButton",
			},
		]
		
	}
	Activate(activationDict)
	
	_buttonElement = children[0]
	_sourceNode = sourceNode
	_destinationNode = destinationNode
	numConnections = numberConnections
	
	
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
	_buttonElement.fullText = str(numConnections)
	pass
