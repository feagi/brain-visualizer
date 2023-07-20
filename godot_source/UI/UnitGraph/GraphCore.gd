extends GraphEdit
class_name GraphCore

signal DataUp(data: Dictionary)

var isActivated := false

const DEFAULT_SPAWN_WIDTH = 150.0
const DEFAULT_HEIGHT_GAP = 10.0

var UIMan: UI_Manager

func _ready():
	Activate() # Temp
	arrange_nodes_button_hidden = true
	connection_request.connect(_ConnectingNodesTogether)
	UIMan = get_parent()

func Activate():
	self.connection_request.connect(_ProcessCortexConnectionRequest)
	self.node_selected.connect(_NodeSelected)
	_ConnectAllNodeSignals()
	
	pass


# Handles Recieving data from UI Manager, and distributing it to the correct element
func RelayDownwards(callType, data: Dictionary = {}):
	match(callType):
		REF.FROM.godot_fullCorticalData:
			_SpawnNodesFromFullCorticalData(data) # TODO - add startup check
			pass

####################################
####### Input Event Handling #######
####################################

# Applying Node connection requests, because for some reason this isn't a built in feature
func _ProcessCortexConnectionRequest(fromNode: StringName, fromPort: int, toNode: StringName, toPort: int) -> void:
	#connect_node(fromNode, fromPort, toNode, toPort)
	pass

func _ProcessConnectionButtonPress(data: Dictionary):
	DataUp.emit(data)

# Handles Node Selection Event
func _NodeSelected(nodeReference):
	DataUp.emit({"CortexSelected": nodeReference.name})

func _ConnectingNodesTogether(sourceNodeID: String, _fromPort: int, destNodeID: String, _toPort: int):
		var sourceNode: CortexNode = _GetNodeByID(sourceNodeID)
		var destNode: CortexNode = _GetNodeByID(destNodeID)
		var data := {
		"event": "NodesLinked",
		"source": sourceNode.friendlyName,
		"destination": destNode.friendlyName
		}
		DataUp.emit(data)
		#UIMan.Windows.MappingDefinition.Open(sourceNode.corticalID, destNode.corticalID)

####################################
######### Node Management ##########
####################################

# Assuming a blank grid, spawn nodes with connections as per most recently cached FEAGI state
func _SpawnNodesFromFullCorticalData(fullCorticalData: Dictionary) -> void:
	var cortex: Dictionary
	
	var numColumns = REF.CORTICALTYPE.size()
	var widths: PackedFloat32Array; widths.resize(numColumns)
	var heights: PackedFloat32Array; heights.resize(numColumns)
	heights.fill(0.0)
	for i in range(numColumns):
		widths[i] = ((DEFAULT_SPAWN_WIDTH / -2) * numColumns) + (i * DEFAULT_SPAWN_WIDTH)
	
	
	for cortexID in fullCorticalData.keys():
		cortex = fullCorticalData[cortexID]
		var spawnedNode = _SpawnCorticalNode(cortexID, cortex)
		var type: String = cortex.type.to_upper()
		var nodeCategoryIndex: int = REF.CORTICALTYPE[type]
		if "position" not in cortex.keys():
			spawnedNode.position_offset = Vector2(widths[nodeCategoryIndex], heights[nodeCategoryIndex])
			heights[nodeCategoryIndex] = heights[nodeCategoryIndex] + spawnedNode.size.y + DEFAULT_HEIGHT_GAP
		else:
			spawnedNode.position_offset = cortex["position"]


	var connectionCount: int  # init here to reduce GC
	# This loop runs under the assumption that the connectome mapping only shows in -> out
	# Yes we need a seperate for loop for this. Too Bad!
	for cortexID in fullCorticalData.keys():
		cortex = fullCorticalData[cortexID]
		if cortex["connectedTo"] != {}:
			# we have connections to map
			for connectionName in cortex["connectedTo"].keys():
				connectionCount = cortex["connectedTo"][connectionName]
				_ProcessCortexConnectionRequest(cortexID, 0, connectionName, 0)
				var conLabel: Connection_Label = Connection_Label.new(_GetNodeByID(cortexID), _GetNodeByID(connectionName), connectionCount, self)


# Spawns a individual node with its required settings (not connections)
func _SpawnCorticalNode(ID: String, CortexOverview: Dictionary) -> CortexNode:
	var newNode: CortexNode = CortexNode.new(ID, CortexOverview)
	add_child(newNode)
	return newNode

# TODO finish me!
# Called on initialization to connect existing cortex signals
func _ConnectAllNodeSignals() -> void:
	var nodeChildren = get_children()
	for child in nodeChildren:
		pass

func _GetNodeByID(ID: String) -> CortexNode:
	var children: Array = get_children()
	for child in children:
		if child.corticalID == ID:
			return child
	assert(false, "Unable to find cortex by ID of " + ID)
	return CortexNode.new("" , {}) # just to allow function to compile, never to be called

