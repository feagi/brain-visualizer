extends GraphNode
class_name CortexNode

enum CONNECTIONTYPES {Default}

var friendlyName: String:
	set(v): _Label.text = v
	get: return _Label.text

var corticalID: String:
	get: return _corticalID
	set(v):
		_corticalID = v
		title = v
		name = v
		_Label.name = v
		
var corticalType: REF.CORTICALTYPE
var usingCustomLocation: bool = false

var _corticalID: String
var _Label: Label_Sub


func _init(cortexID: String, cortexOverview: Dictionary):
	super()
	_Label = Label_Sub.new()
	add_child(_Label)
	
	corticalID = cortexID
	friendlyName = cortexOverview["friendlyName"]
	if "position" in cortexOverview.keys():
		position_offset = cortexOverview["position"]
		usingCustomLocation = true
	
	set_slot_enabled_left(0, true)
	set_slot_enabled_right(0, true)
	
	set_slot_type_left(0, int(CONNECTIONTYPES.Default))
	set_slot_type_right(0, int(CONNECTIONTYPES.Default))






