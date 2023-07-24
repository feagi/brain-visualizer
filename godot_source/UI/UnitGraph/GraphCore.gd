extends GraphEdit
class_name GraphCore

signal DataUp(data: Dictionary)

var isActivated := false

const DEFAULT_SPAWN_WIDTH = 150.0
const DEFAULT_HEIGHT_GAP = 10.0


var cortexNodes: Dictionary # CortexIDStr -> CortexNode
var connectionLabels: Dictionary # srcCortexIDStr -> dstCortexIDStr -> ConnectionLabel
# NOTE, THe above data structure is not efficient, REPLACE
var _UIManRef: UI_Manager


func _ready():
	FeagiVarUpdates.Internal_corticalMapSummary.connect(_SpawnNodesFromFullCorticalData) # TODO this may not want to be here
	arrange_nodes_button_hidden = true
	connection_request.connect(_ConnectingNodesTogether)
	self.node_selected.connect(_NodeSelected)
	#right_disconnects = true # TODO NEXT
	_UIManRef = get_parent()



# Handles Recieving data from UI Manager, and distributing it to the correct element
# DEPRECATED: TODO REMOVE
func RelayDownwards(callType, data: Dictionary = {}):
	match(callType):
		REF.FROM.godot_fullCorticalData:
			_SpawnNodesFromFullCorticalData(data) # TODO - add startup check
			pass

####################################
###### Single Entity Handling ######
####################################

# Spawns a individual node with its required settings (not connections)
func SpawnCorticalNode(ID: CortexID, friendlyName: String, positionArr: PackedInt32Array = []) -> CortexNode:
	var newNode: CortexNode = CortexNode.new(ID, friendlyName, positionArr)
	add_child(newNode)
	cortexNodes[ID.str] = newNode
	return newNode

func CreateVisibleConnection(srcNode: CortexNode, dstNode: CortexNode, numConnections: int) -> void:
	_VisuallyConnectNodes(srcNode.corticalID, dstNode.corticalID)
	var newLabel: Connection_Label = Connection_Label.new(srcNode, dstNode, numConnections, self)
	
	if srcNode.corticalID.str not in connectionLabels.keys():
		connectionLabels[srcNode.corticalID.str] = {dstNode.corticalID.str: newLabel}
	else:
		connectionLabels[srcNode.corticalID.str][dstNode.corticalID.str] = newLabel
	

# Creates the visible line connection. Called from "connection_request" signal
func _VisuallyConnectNodes(fromNode: CortexID, toNode: CortexID, fromPort: int = 0, toPort: int = 0) -> void:
	connect_node(fromNode.str, fromPort, toNode.str, toPort)

# Proxy for signal for user connecting nodes
func _ConnectingNodesTogether(sourceNodeID: String, _fromPort: int, destNodeID: String, _toPort: int):
	var sourceNode: CortexNode = cortexNodes[sourceNodeID]
	var destNode: CortexNode = cortexNodes[destNodeID]
	var data := {
	"event": "NodesLinked",
	"source": sourceNode.friendlyName,
	"destination": destNode.friendlyName
	}
	DataUp.emit(data)

func _ProcessConnectionButtonPress(data: Dictionary):
	DataUp.emit(data)

# Handles Node Selection Event
func _NodeSelected(nodeReference):
	DataUp.emit({"CortexSelected": nodeReference.name})


####################################
####### Mass Entity Handling #######
####################################

# Assuming a blank grid, spawn nodes with connections as per most recently cached FEAGI state
func _SpawnNodesFromFullCorticalData(fullCorticalData: Dictionary) -> void:
	var cortexContext: Dictionary
	
	var numColumns = REF.CORTICALTYPE.size()
	var widths: PackedFloat32Array; widths.resize(numColumns)
	var heights: PackedFloat32Array; heights.resize(numColumns)
	heights.fill(0.0)
	for i in range(numColumns):
		widths[i] = ((DEFAULT_SPAWN_WIDTH / -2) * numColumns) + (i * DEFAULT_SPAWN_WIDTH)
	
	
	for cortexIDStr in fullCorticalData.keys():
		var curCortexID: CortexID = CortexID.new(cortexIDStr)
		cortexContext = fullCorticalData[curCortexID.str]
		var spawnedNode = SpawnCorticalNode(curCortexID, cortexContext["friendlyName"])
		var type: String = cortexContext.type.to_upper()
		var nodeCategoryIndex: int = REF.CORTICALTYPE[type]
		if "position" not in cortexContext.keys():
			spawnedNode.position_offset = Vector2(widths[nodeCategoryIndex], heights[nodeCategoryIndex])
			heights[nodeCategoryIndex] = heights[nodeCategoryIndex] + spawnedNode.size.y + DEFAULT_HEIGHT_GAP
		else:
			spawnedNode.position_offset = cortexContext["position"]


	var connectionCount: int  # init here to reduce GC
	var _srcCortex: CortexNode # init here to reduce GC
	var _dstCortex: CortexNode # init here to reduce GC
	# This loop runs under the assumption that the connectome mapping only shows in -> out
	# Yes we need a seperate for loop for this. Too Bad!
	for cortexIDStr in fullCorticalData.keys():
		var curCortexID: CortexID = CortexID.new(cortexIDStr)
		cortexContext = fullCorticalData[curCortexID.str]
		if cortexContext["connectedTo"] != {}:
			# we have connections to map
			for connectionName in cortexContext["connectedTo"].keys():
				connectionCount = cortexContext["connectedTo"][connectionName]
				_srcCortex = cortexNodes[curCortexID.str]
				_dstCortex = cortexNodes[connectionName]
				CreateVisibleConnection(_srcCortex, _dstCortex, connectionCount)
