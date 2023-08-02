extends Object
## Holds the various cortical area cached data and proccess them automatically
class_name CorticalAreasHolder


var CO_corticalAreas_list_detailed: Dictionary:
	get: return _connectome_corticalAreas_list_detailed
	set(v):
		_connectome_corticalAreas_list_detailed = v
		_connectome_corticalAreas_list_detailed_justUpdated = true
		_Update_internal_corticalMapSummary()
		FeagiVarUpdates.connectome_corticalAreas_list_detailed.emit(v)

var GE_corticalMap: Dictionary:
	get: return _genome_corticalMap
	set(v):
		_genome_corticalMap = v
		_genome_corticalMap_justUpdated = true
		_Update_internal_corticalMapSummary()
		FeagiVarUpdates.genome_corticalMap.emit(v)

var GE_corticalLocations2D: Dictionary:
	get: return _genome_corticalLocations2D
	set(v):
		_genome_corticalLocations2D = v
		_genome_corticalLocations2D_justUpdated = true
		_Update_internal_corticalMapSummary()
		FeagiVarUpdates.genome_corticalLocations2D.emit(v)

var IN_corticalMapSummary: Dictionary:
	get: return _internal_corticalMapSummary

var timeOfLastMappingUpdate: float:
	get: return _timeofLastMappingUpdate

var secondsSinceLastMappingUpdate: float:
	get: return  _timeofLastMappingUpdate - Time.get_unix_time_from_system()



var _timeofLastMappingUpdate: float
var _connectome_corticalAreas_list_detailed: Dictionary = {}
var _genome_corticalMap: Dictionary = {}
var _genome_corticalLocations2D: Dictionary = {}
var _internal_corticalMapSummary: Dictionary
var _CorticalAreasMapped2IDs: Dictionary
var _coreRef: Core

# for use for updating internal
var _genome_corticalMap_justUpdated: bool = false
var _genome_corticalLocations2D_justUpdated = false
var _connectome_corticalAreas_list_detailed_justUpdated = false


func _init(coreReference: Core) -> void:
	_coreRef = coreReference

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
func _Update_internal_corticalMapSummary() -> void:
	if !(_genome_corticalMap_justUpdated && _genome_corticalMap_justUpdated && _genome_corticalLocations2D_justUpdated): return
	
	_genome_corticalMap_justUpdated = false
	_genome_corticalMap_justUpdated = false
	_genome_corticalLocations2D_justUpdated = false
	
	var output := {}
	# preinit to minimize garbage collection
	var specificCortexData := {}
	for cortexID in _connectome_corticalAreas_list_detailed.keys():
		specificCortexData["friendlyName"] = _connectome_corticalAreas_list_detailed[cortexID]["name"]
		specificCortexData["connectedTo"] = _genome_corticalMap[cortexID]
		specificCortexData["type"] = _connectome_corticalAreas_list_detailed[cortexID]["type"]
		
		
		if len(_connectome_corticalAreas_list_detailed[cortexID]["position"]) == 2:
			specificCortexData["position"] = Vector2(_connectome_corticalAreas_list_detailed[cortexID]["cortical_coordinates_2d"][0], _connectome_corticalAreas_list_detailed[cortexID]["cortical_coordinates_2d"][1])
		
		output[cortexID] = specificCortexData.duplicate()
		specificCortexData = {}  # reset
	
	_internal_corticalMapSummary = output
	FeagiVarUpdates.Internal_corticalMapSummary.emit(_internal_corticalMapSummary)
