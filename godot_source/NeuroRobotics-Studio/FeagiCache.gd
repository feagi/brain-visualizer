extends Node
class_name FeagiCache

# This script holds cached data for feagi, both directly and in processed forms

signal FullCorticalData_Updated(FullCorticalData: Dictionary)

####################################
####### FEAGI Direct Inputs ########
####################################
# These vars come directly from FEAGI (with minimal cleanup processing)

######### Directly Usable ##########
var pns_current_IPU: Dictionary:
	set(v): _pns_current_IPU = v
	get: return _pns_current_IPU
var pns_current_OPU: Dictionary:
	set(v): _pns_current_OPU = v
	get: return _pns_current_OPU

var genome_areaIDList: Dictionary:
	set(v): _genome_areaIDList = v
	get: return _genome_areaIDList
var genome_morphologyList: Array:
	set(v): _genome_morphologyList = v
	get: return _genome_morphologyList
var genome_fileName: String:
	set(v): _genome_fileName = v
	get: return _genome_fileName
var genome_corticalAreaIDList: Array:
	set(v): 
		_genome_corticalAreaIDList = v; 
	get: return _genome_corticalAreaIDList
var genome_corticalAreaNameList: Array:
	set(v): _genome_corticalAreaNameList = v
	get: return _genome_corticalAreaNameList
var genome_cortical_id_name_mapping: Dictionary:
	set(v): 
		_genome_cortical_id_name_mapping = v
	get: return _genome_cortical_id_name_mapping
var genome_corticalMappings: Dictionary:
	set(v): 
		_genome_corticalMappings = v
		FCD_Genome_CorticalMappings = true
		Update_FullCorticalData()
	get: return _genome_corticalMappings
var circuit_list: Array:
	set(v): _circuit_list = v;
	get: return _circuit_list
var circuit_size: Array:
	set(v): _circuit_size = v;
	get: return _circuit_size

var connectome_properties_mappings: Dictionary:
	set(v): 
		_connectome_properties_mappings = v
	get: return _connectome_properties_mappings

var connectome_corticalAreas_detailed: Dictionary:
	set(v): 
		_connectome_corticalAreas_detailed = v
		FCD_ConnectomeCorticalAreasDetailed = true
		Update_FullCorticalData()
	get: return _connectome_corticalAreas_detailed

var burst_rate: float:
	set(v): _burst_rate = v
	get: return _burst_rate

######### Internal Caching #########
var _pns_current_IPU: Dictionary
var _pns_current_OPU: Dictionary

var _genome_areaIDList: Dictionary
var _genome_morphologyList: Array
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

###### Other Internal Values #######
var _allConnectionReferencess: Array # IDs used to connect cortexes to each other

####################################
###### FEAGI Processed Inputs ######
####################################
# These vars have been processed, often because they have multiple dependencies



var FCD_ConnectomeCorticalAreasDetailed = false
var FCD_Genome_CorticalMappings = false
var fullCorticalData := {}
func Update_FullCorticalData(): # Update an easy to use dictionary with mappings easily set up
	# check if prerequisites are ready to go
	if(!FCD_ConnectomeCorticalAreasDetailed): return
	if(!FCD_Genome_CorticalMappings): return
	# prereqs passed
	fullCorticalData = InitMappingData(connectome_corticalAreas_detailed, genome_corticalMappings)
	FullCorticalData_Updated.emit(fullCorticalData)



####################################
######### Data Management ##########
####################################

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
