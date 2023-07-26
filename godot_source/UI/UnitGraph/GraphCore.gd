extends GraphEdit
class_name GraphCore

signal CortexSelected(cortex: CortexID)
signal ConnectionSelected(source: CortexID, destination: CortexID)
signal ConnectionRequest(source: CortexID, destination: CortexID)
signal DisconnectionRequest(source: CortexID, destination: CortexID)


const DEFAULT_SPAWN_WIDTH: int = 150
const DEFAULT_HEIGHT_GAP: int = 10

var cortexNodes: Dictionary # CortexIDStr -> CortexNode
var connections: CBConnectionDB

# NOTE, THe above data structure is not efficient, REPLACE
var _UIManRef: UI_Manager

func _ready():
	FeagiVarUpdates.Internal_corticalMapSummary.connect(_SpawnNodesFromFullCorticalData)

	connection_request.connect(_ConnectingNodesTogether)
	disconnection_request.connect(_DisconnectingNodesFromEachOther)
	node_selected.connect(_NodeSelected)

	arrange_nodes_button_hidden = true
	right_disconnects = true
	_UIManRef = get_parent()
	connections = CBConnectionDB.new()

####################################
############ User Input ############
####################################

# Proxy for Node Selection Event
func _NodeSelected(nodeReference: CortexNode) -> void:
	CortexSelected.emit(nodeReference.corticalID)

func _ConnectionLabelPressed(label: Connection_Label) -> void:
	ConnectionSelected.emit(label.sourceNode.friendlyName, label.destinationNode.friendlyName) # TODO these need to be IDs with later BV change

# Proxy for signal for user connecting nodes
func _ConnectingNodesTogether(sourceNodeID: String, _fromPort: int, destNodeID: String, _toPort: int) -> void:
	ConnectionRequest.emit(CortexID.new(sourceNodeID), CortexID.new(destNodeID))

# Proxy for signal for user disconnecting nodes
func _DisconnectingNodesFromEachOther(sourceNodeID: String, _fromPort: int, destNodeID: String, _toPort: int) -> void:
	DisconnectionRequest.emit(CortexID.new(sourceNodeID), CortexID.new(destNodeID))
	# Temp Until more work with Cache
	RemoveVisibleConnection(cortexNodes[sourceNodeID], cortexNodes[destNodeID])


####################################
###### Single Entity Handling ######
####################################

# Spawns a individual node with its required settings (not connections)
func SpawnCorticalNode(ID: CortexID, friendlyName: String, positionFromFeagi: Vector2i, isPositionDefinedFromFeagi: bool) -> CortexNode:
	var newNode: CortexNode = CortexNode.new(ID, friendlyName, isPositionDefinedFromFeagi, self, positionFromFeagi)
	cortexNodes[ID.ID] = newNode
	return newNode

# Spawns a Label (which also automatically negotiates a connection line) connecting 2 nodes together
func CreateVisibleConnection(srcNode: CortexNode, dstNode: CortexNode, numConnections: int) -> Connection_Label:
	var newLabel: Connection_Label = Connection_Label.new(srcNode, dstNode, numConnections, self)
	newLabel.ButtonPressed.connect(_ConnectionLabelPressed)
	connections.AddConnection(srcNode.corticalID, dstNode.corticalID, newLabel)
	return newLabel

# Removes a cortical Area from CB, and by default also all the connections to and from it
func RemoveCorticalNode(ID: CortexID, automaticallyRemoveVisualConnections: bool = true) -> void:
	var deletingNode: CortexNode = cortexNodes[ID.ID]
	cortexNodes.erase(ID.ID)
	if automaticallyRemoveVisualConnections:
		_RemoveAllVisualConnectionsToCorticalArea(ID)

	deletingNode.DestroySelf()

# Removes a Connection from CB
func RemoveVisibleConnection(srcNode: CortexNode, dstNode: CortexNode) -> void:
	var label: Connection_Label = connections.GetSpecificConnectionLabel(srcNode.corticalID, dstNode.corticalID)
	label.DestroyConnection()
	connections.RemoveConnection(srcNode.corticalID, dstNode.corticalID)


####################################
####### Mass Entity Handling #######
####################################

# Assuming a blank grid, spawn nodes with connections as per most recently cached FEAGI state
func _SpawnNodesFromFullCorticalData(fullCorticalData: Dictionary) -> void:
	
	# looped vars up here to reduce GC
	var curCortexID: CortexID
	var cortexContext: Dictionary
	var spawnedNode: CortexNode
	var cortexType: StringName
	var cortexTypeIndex: int
	
	var numColumns = REF.CORTICALTYPE.size()
	var widths: PackedInt32Array = []
	widths.resize(numColumns)
	var heights: PackedInt32Array = []
	heights.resize(numColumns)
	heights.fill(0)
	for i in range(numColumns):
		widths[i] = ((DEFAULT_SPAWN_WIDTH / -2) * numColumns) + (i * DEFAULT_SPAWN_WIDTH)
	
	for cortexIDStr in fullCorticalData.keys():
		curCortexID = CortexID.new(cortexIDStr)
		cortexContext = fullCorticalData[curCortexID.str]
		cortexType = cortexContext.type.to_upper()
		cortexTypeIndex = REF.CORTICALTYPE[cortexType]

		if "position" not in cortexContext.keys():
			spawnedNode = SpawnCorticalNode(curCortexID, cortexContext["friendlyName"], Vector2i(widths[cortexTypeIndex], heights[cortexTypeIndex]), false)
			heights[cortexTypeIndex] = heights[cortexTypeIndex] + int(spawnedNode.size.y) + DEFAULT_HEIGHT_GAP
		else:
			spawnedNode = SpawnCorticalNode(curCortexID, cortexContext["friendlyName"], cortexContext["position"], true)

	var connectionCount: int  # init here to reduce GC
	var _srcCortex: CortexNode # init here to reduce GC
	var _dstCortex: CortexNode # init here to reduce GC
	# This loop runs under the assumption that the connectome mapping only shows in -> out
	# Yes we need a seperate for loop for this. Too Bad!
	for srcCortexIDStr in fullCorticalData.keys():
		cortexContext = fullCorticalData[srcCortexIDStr]
		if cortexContext["connectedTo"] != {}:
			# we have connections to map
			for dstCortexIDStr in cortexContext["connectedTo"].keys():
				connectionCount = cortexContext["connectedTo"][dstCortexIDStr]
				_srcCortex = cortexNodes[srcCortexIDStr]
				_dstCortex = cortexNodes[dstCortexIDStr]
				CreateVisibleConnection(_srcCortex, _dstCortex, connectionCount)

# Removes all Visual Connections for a specific Cortical Area Node
func _RemoveAllVisualConnectionsToCorticalArea(area: CortexID) -> void:
	var preceedingConnections: Array[Connection_Label] = connections.GetConnectionLabelsWithSource(area)
	var followingConnections: Array[Connection_Label] = connections.GetConnectionLabelsWithDestination(area)

	for c in preceedingConnections:
		c.DestroyConnection()
	for c in followingConnections:
		c.DestroyConnection()
