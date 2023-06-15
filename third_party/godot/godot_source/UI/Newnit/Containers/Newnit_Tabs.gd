extends TabContainer
class_name Newnit_Tabs

# This base class is used to construct all Elements, which are parallel in 
# implmentation to Newnits but insteadof holding containers, are UI elements

######################## START Newnit Parallel - this section must match that of Newnit_Base ########################

const NEWNIT_CORE = preload("res://UI/Newnit/PreloadScripts/Newnit_core.gd")

signal DataUp(data: Dictionary, originatingID: StringName, originatingRef: Node)

var ID: StringName:
	get: return _ID

var parent: Node:
	get: return get_node("../")

var parentID: StringName:
	get: return NEWNIT_CORE.Get_ParentID(self)

var childrenIDs: Array:
	get: return NEWNIT_CORE.Func_GetChildIDs(children)

var data: Dictionary:
	get: return NEWNIT_CORE.Get_data(self)

var type: StringName:
	get: return _type

var _ID: StringName
var _isActivated := false
var _isTopLevel := true
var _runtimeSettableProperties := NEWNIT_CORE.settableProperties
var _type: StringName

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
			return child
	return false

################################################ END Newnit Parallel ################################################

################### START Containers Parallel - this section must match that of other Newnit Containers ##############

const NEWNIT_CONTAINER_CORE = preload("res://UI/Newnit/PreloadScripts/Container_Core.gd")

var children: Array:
	get: return NEWNIT_CONTAINER_CORE.Get_children(self)

func SpawnChild(childActivationSettings: Dictionary) -> void:
	NEWNIT_CONTAINER_CORE.Func_SpawnChild(childActivationSettings, self)

func SpawnMultipleChildren(childrenActivationSettings: Array) -> void:
	NEWNIT_CONTAINER_CORE.Func_SpawnMultipleChildren(childrenActivationSettings, self)

func _ActivationPrimary(settings: Dictionary) -> void:
	NEWNIT_CONTAINER_CORE.Func__ActivationPrimary(settings, self)

func _getChildData() -> Dictionary:
	return NEWNIT_CONTAINER_CORE.Func__getChildData(self)

func _DataUpProxy(data: Dictionary, recievedID: String, reference: Node) -> void:
	DataUp.emit(data, recievedID, reference)

################################################# END Newnit Containers Parallel #######################

### Start Tab Container Unique

var specificSettableProps := {
	"current_tab": TYPE_INT,
	"tab_alignment": TYPE_INT,
	"use_hidden_tabs_for_min_size": TYPE_BOOL,
	"tab_titles": TYPE_ARRAY,
	"tabs_enabled": TYPE_ARRAY
}
	
var ALL_ENABLED: Array:
	get:
		var o := []
		for i in children:
			o.append(true)
		return o

var ALL_DISABLED: Array:
	get:
		var o := []
		for i in children:
			o.append(false)
		return o

# Allows for mass setting of tab titles
var tab_titles: Array:
	set(v): _SetAllTabTitles(v)

# Allows for mass setting of tab enablement states
var tabs_enabled: Array:
	set(v): _SetAllTabEnableState(v)

func _ActivationSecondary(settings: Dictionary) -> void:
	_runtimeSettableProperties.merge(specificSettableProps)
	
	current_tab = HelperFuncs.GetIfCan(settings, "current_tab", NEWNIT_CONTAINER_CORE.D_current_tab)
	tab_alignment = HelperFuncs.GetIfCan(settings, "tab_alignment", NEWNIT_CONTAINER_CORE.D_tab_alignment)
	use_hidden_tabs_for_min_size = HelperFuncs.GetIfCan(settings, "use_hidden_tabs_for_min_size", NEWNIT_CONTAINER_CORE.D_use_hidden_tabs_for_min_size)
	tab_titles = HelperFuncs.GetIfCan(settings, "tab_titles", [])
	tabs_enabled = HelperFuncs.GetIfCan(settings, "tabs_enabled", ALL_ENABLED)
	type = "tab"
	
	
func _SetAllTabTitles(titles: Array) -> void:
	for i in range(len(titles)):
		set_tab_title(i, titles[i])

func _SetAllTabEnableState(whichEnabled: Array) -> void:
	for i in range(len(whichEnabled)):
		set_tab_hidden(i, whichEnabled[i])