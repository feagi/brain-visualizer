extends GraphNode
class_name CortexNode

enum CONNECTIONTYPES {Default}

var friendlyName: String:
	set(v): _Label.text = v
	get: return _Label.text

var corticalID: CortexID:
	get: return _corticalID
	set(v):
		_corticalID = v
		title = v.str
		name = v.str
		_Label.name = v.str
		
var corticalType: REF.CORTICALTYPE
var isPositionFromFeagi: bool = false

var _corticalID: CortexID
var _Label: Label_Sub
var _graphCoreRef: GraphCore


func _init(cortexID: CortexID, niceName: String, isPositionDefinedFromFeagi: bool, graph: GraphCore, positionFromFeagi: Vector2i):
	
#	super()
	_graphCoreRef = graph
	_graphCoreRef.add_child(self)

	_Label = Label_Sub.new()
	add_child(_Label)
	
	corticalID = cortexID
	friendlyName = niceName
	
	set_slot_enabled_left(0, true)
	set_slot_enabled_right(0, true)
	
	set_slot_type_left(0, int(CONNECTIONTYPES.Default))
	set_slot_type_right(0, int(CONNECTIONTYPES.Default))
	
	isPositionFromFeagi = isPositionDefinedFromFeagi
	position_offset = positionFromFeagi
	node_deselected.connect(saveNewPositionInFEAGI)

func DestroySelf() -> void:
	queue_free()

func saveNewPositionInFEAGI() -> void:
	isPositionFromFeagi = true
	var posToSend: Dictionary = {"cortical_coordinates_2d": HelperFuncs.Vector2i2Array(position_offset) }
	#_graphCoreRef._UIManRef.CoreRef.FEAGICalls.PUT_GE_corticalArea(posToSend, corticalID.STR)
