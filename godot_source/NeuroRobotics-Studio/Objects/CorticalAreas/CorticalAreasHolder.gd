extends Object
## Holds the various cortical area cached data and proccess them automatically
class_name CorticalAreasHolder


var CO_corticalAreas_list_detailed: Dictionary:
	get: return _connectome_corticalAreas_list_detailed

var GE_corticalMap: Dictionary:
	get: return _genome_corticalMap

var IN_corticalMapSummary: Dictionary:
	get: return _internal_corticalMapSummary

var timeOfLastMappingUpdate: float:
	get: return _timeofLastMappingUpdate

var secondsSinceLastMappingUpdate: float:
	get: return  _timeofLastMappingUpdate - Time.get_unix_time_from_system()



var _timeofLastMappingUpdate: float
var _connectome_corticalAreas_list_detailed: Dictionary = {}
var _genome_corticalMap: Dictionary = {}
var _internal_corticalMapSummary: Dictionary
var _CorticalAreasMapped2IDs: Dictionary
var _coreRef: Core


func _init(coreReference: Core) -> void:
	_coreRef = coreReference

func Get_connectome_corticalAreas_list_detailed( mapping: Dictionary) -> void:
	_connectome_corticalAreas_list_detailed = mapping
	FeagiVarUpdates.connectome_corticalAreas_list_detailed.emit(mapping)
	Update_internal_corticalMapSummary()

func Get_genome_corticalMap(mapping: Dictionary) -> void:
	_genome_corticalMap = mapping
	FeagiVarUpdates.genome_corticalMap.emit(mapping)
	Update_internal_corticalMapSummary()

func Get_UpdateCorticalArea(corticalAreaID: CortexID, data: Dictionary) -> void:
	if corticalAreaID.str in _CorticalAreasMapped2IDs.keys():
		_CorticalAreasMapped2IDs[corticalAreaID.str].ApplyDictionary(data)
		return
	#_CorticalAreasMapped2IDs[corticalAreaID.str] = CorticalArea.new(corticalAreaID, )

#func Add_CorticalArea(corticalAreaID: CortexID, friendlyName: String)
# TODO later

# Temp do not keep TODO
func ID2Name(ID: CortexID) -> String:
	return CO_corticalAreas_list_detailed[ID.ID]["name"]

# Dictionary {
# 	StringIDOfCortex:
#		{ 
#		  "friendlyName: String, human readable name of cortex
#		  "connectedTo": [Str Array of connected cortexes, using the cortex IDs from FEAGI directly]
#		  "type": String, IPU, OPU, Memory, Custom
#		  "position": Vector2, but only if given
func Update_internal_corticalMapSummary() -> void:
	if _connectome_corticalAreas_list_detailed == {} || _genome_corticalMap == {}: return
	
	var output := {}
	# preinit to minimize garbage collection
	var specificCortexData := {}
	for cortexID in _connectome_corticalAreas_list_detailed.keys():
		specificCortexData["friendlyName"] = _connectome_corticalAreas_list_detailed[cortexID]["name"]
		specificCortexData["connectedTo"] = _genome_corticalMap[cortexID]
		specificCortexData["type"] = _connectome_corticalAreas_list_detailed[cortexID]["type"]
		if len(_connectome_corticalAreas_list_detailed[cortexID]["position"]) == 2:
			specificCortexData["position"] = Vector2(_connectome_corticalAreas_list_detailed[cortexID]["position"][0], _connectome_corticalAreas_list_detailed[cortexID]["position"][1])
		
		output[cortexID] = specificCortexData.duplicate()
		specificCortexData = {}  # reset
	
	_internal_corticalMapSummary = output
	FeagiVarUpdates.Internal_corticalMapSummary.emit(_internal_corticalMapSummary)
