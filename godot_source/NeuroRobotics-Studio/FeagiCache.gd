extends Node

# This script holds cached data for feagi, both directly and in processed forms

var _coreRef: Core

####################################
####### FEAGI Direct Inputs ########
####################################
# These vars come directly from FEAGI (with minimal cleanup processing)

######### Directly Usable ##########
var pns_current_IPU: Dictionary: #TODO clean
	get: return _pns_current_IPU
	set(v): _pns_current_IPU = v
	
var pns_current_OPU: Dictionary: #TODO clean
	get: return _pns_current_OPU
	set(v): _pns_current_OPU = v

var genome_fileName: String:
	get: return _genome_fileName
	set(v): _genome_fileName = v

var circuit_list: Array:
	get: return _circuit_list
	set(v): _circuit_list = v;
	
var circuit_size: Array:
	get: return _circuit_size
	set(v): _circuit_size = v;

var burst_rate: float:
	get: return _burst_rate
	set(v): 
		_burst_rate = v
		FeagiVarUpdates.burstEngine_stimulationPeriod.emit(v)

var morphologies: MorphologiesHolder 
var corticalAreas: CorticalAreasHolder 


######### Internal Caching #########
var _pns_current_IPU: Dictionary
var _pns_current_OPU: Dictionary
var _genome_fileName: String
var _genome_corticalAreaIDList: Array
var _genome_corticalAreaNameList: Array
var _genome_cortical_id_name_mapping: Dictionary
var _genome_corticalMappings: Dictionary
var _circuit_list : Array
var _circuit_size : Array
var _connectome_properties_mappings: Dictionary
var _connectome_corticalAreas_detailed: Dictionary
var _burst_rate: float


# Vars required for activation
var _activated: bool = false
var _morphologyListRetrieved: bool = false
var _corticalAreaListRetrieved: bool = false
## Ran from Core, will only proceed once all required values are retrieved
func Activation() -> void:
	if _activated: return
	if !_morphologyListRetrieved: return
	if !_corticalAreaListRetrieved: return
	



# Convert Raw Connectome data from feagi to a dictionary structure usable by the node graph
# Dictionary {
# 	StringIDOfCortex:
#		{ 
#		  "friendlyName: String, human readable name of cortex
#		  "connectedTo": [Str Array of connected cortexes, using the cortex IDs from FEAGI directly]
#		  "type": String, IPU, OPU, Memory, Custom
#		  "position": Vector2, but only if given
func InitMappingData(connectomeDetailed: Dictionary, corticalMapping: Dictionary) -> Dictionary:
	
	var output := {}
	# preinit to minimize garbage collection
	var specificCortexData := {}
	
	for cortexID in connectomeDetailed.keys():
		specificCortexData["friendlyName"] = connectomeDetailed[cortexID]["name"]
		specificCortexData["connectedTo"] = corticalMapping[cortexID]
		specificCortexData["type"] = connectomeDetailed[cortexID]["type"]
		if len(connectomeDetailed[cortexID]["position"]) == 2:
			specificCortexData["position"] = Vector2(connectomeDetailed[cortexID]["position"][0], connectomeDetailed[cortexID]["position"][1])
		
		output[cortexID] = specificCortexData.duplicate()
		specificCortexData = {}  # reset
	
	return output
