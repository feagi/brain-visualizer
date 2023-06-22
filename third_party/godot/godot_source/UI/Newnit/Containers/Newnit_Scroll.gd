extends ScrollContainer
class_name Newnit_Scroll

# This base class is used to construct all Elements, which are parallel in 
# implmentation to Newnits but insteadof holding containers, are UI elements

######################## START Newnit Parallel - this section must match that of Newnit_Base ########################

const NEWNIT_CORE = preload("res://UI/Newnit/PreloadScripts/Newnit_core.gd")

signal DataUp(data: Dictionary, originatingID: StringName, originatingRef: Node)

var ID: StringName:
	get: return _ID

var parent: Node:
	get: return _parent

var parentID: StringName:
	get: return NEWNIT_CORE.Get_ParentID(self)

var childrenIDs: Array:
	get: return NEWNIT_CORE.Func_GetChildIDs(children)

var data: Dictionary:
	get: return NEWNIT_CORE.Get_data(self)

var type: StringName:
	get: return _type

var isUsingPanel: bool:
	get: return _isUsingPanel

var panelRef: Node:
	get: return _panelRef

var hasNewnitParent: bool:
	get: return _hasNewnitParent

var draggable: bool

var _ID: StringName
var _isActivated := false
var _isTopLevel := true
var _runtimeSettableProperties := NEWNIT_CORE.settableProperties
var _type: StringName
var _isUsingPanel: bool
var _panelRef: Node = null
var _parent: Node = null
var _hasNewnitParent: bool = false

func Activate(settings: Dictionary) -> void:
	NEWNIT_CORE.Func_Activate(settings, self)

# Set Properties from dictionary
func SetData(input: Dictionary) -> void:
	NEWNIT_CORE.Func_SetData(input, self)

func GetReferenceByID(searchID: StringName): # returns either a bool or a Node
	if searchID == ID: return self
	for child in children:
		var result = child.GetReferenceByID(searchID)
		if typeof(result) != TYPE_BOOL:
			return result
	return false

func UpdatePosition(newPosition: Vector2) -> void:
	if isUsingPanel: _panelRef.position = newPosition
	else: position = newPosition

func _ResizePanel() -> void:
	_panelRef.size = size

func _get_drag_data(at_position: Vector2):
	if draggable: UpdatePosition(at_position)

func _notification(what):
	if (what == NOTIFICATION_PREDELETE):
		if(isUsingPanel): panelRef.queue_free()

################################################ END Newnit Parallel ################################################

################### START Containers Parallel - this section must match that of other Newnit Containers ##############

const NEWNIT_CONTAINER_CORE = preload("res://UI/Newnit/PreloadScripts/Container_Core.gd")

func SpawnChild(childActivationSettings: Dictionary) -> void:
	NEWNIT_CONTAINER_CORE.Func_SpawnChild(childActivationSettings, self)

func SpawnMultipleChildren(childrenActivationSettings: Array) -> void:
	NEWNIT_CONTAINER_CORE.Func_SpawnMultipleChildren(childrenActivationSettings, self)

func _ActivationPrimary(settings: Dictionary) -> void:
	if(_AlternateActivationPath(settings)): return
	NEWNIT_CONTAINER_CORE.Func__ActivationPrimary(settings, self)

func _getChildData() -> Dictionary:
	return NEWNIT_CONTAINER_CORE.Func__getChildData(self)

func _DataUpProxy(data: Dictionary, recievedID: String, reference: Node) -> void:
	DataUp.emit(data, recievedID, reference)

################################################# END Newnit Containers Parallel #######################

### Start Box Container Unique

var scrollBox: Newnit_Box

var children: Array:
	get: return NEWNIT_CONTAINER_CORE.Get_children(scrollBox)

var specificSettableProps := {
	"alignment": TYPE_INT,
	"vertical": TYPE_INT
}

var vertical: int:
	get: return scrollBox.vertical
	set(v): scrollBox.vertical = v

var alignment: int:
	get: return scrollBox.alignment
	set(v): scrollBox.alignment = v

func _AlternateActivationPath(settings: Dictionary) -> bool:
	
	type = "scrollbar"
	
	# use this to modify element spawning
	scrollBox = Newnit_Box.new()
	add_child(scrollBox)
	
	# modify settings overwrite
	settings["ID"] = ID + "___Box"
	settings["type"] = "box"
	
	scrollBox.Activate(settings)
	
	return true # prevent default activation procedures

func _ActivationSecondary(settings: Dictionary) -> void:
	# skipped
	pass
