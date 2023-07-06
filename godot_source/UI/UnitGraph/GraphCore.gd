extends GraphEdit
class_name GraphCore

var isActivated := false

signal DataUp(data: Dictionary)

func _ready():
	Activate() # Temp
	arrange_nodes_button_hidden = true


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
	connect_node(fromNode, fromPort, toNode, toPort)

# Handles Node Selection Event
func _NodeSelected(nodeReference):
	DataUp.emit({"CortexSelected": nodeReference.name})

####################################
######### Node Management ##########
####################################

# Assuming a blank grid, spawn nodes with connections as per most recently cached FEAGI state
func _SpawnNodesFromFullCorticalData(fullCorticalData: Dictionary) -> void:
	var cortex: Dictionary
	for cortexID in fullCorticalData.keys():
		cortex = fullCorticalData[cortexID]
		var spawnedNode = _SpawnCorticalNode(cortexID, cortex)
	
	# This loop runs under the assumption that the connectome mapping only shows in -> out
	# Yes we need a seperate for loop for this. Too Bad!
	for cortexID in fullCorticalData.keys():
		cortex = fullCorticalData[cortexID]
		if cortex["connectionsStrIDs"] != []:
			# we have connections to map
			for connection in cortex["connectionsStrIDs"]:
				_ProcessCortexConnectionRequest(cortexID, 0, connection, 0)
	
	
	pass

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

#func _GetNodeByID() -> CortexNode:
#	pass
