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
var usingCustomLocation: bool = false

var _corticalID: CortexID
var _Label: Label_Sub

# We have to use a positionArr because gdscript doesn't allow null statics
func _init(cortexID: CortexID, niceName: String, positionArr: PackedInt32Array = []):
	super()
	_Label = Label_Sub.new()
	add_child(_Label)
	
	corticalID = cortexID
	friendlyName = niceName
	
	set_slot_enabled_left(0, true)
	set_slot_enabled_right(0, true)
	
	set_slot_type_left(0, int(CONNECTIONTYPES.Default))
	set_slot_type_right(0, int(CONNECTIONTYPES.Default))
	
	if positionArr.size() == 0: return
		
	position_offset = HelperFuncs.Array2Vector2i(positionArr)
	usingCustomLocation = true
	








