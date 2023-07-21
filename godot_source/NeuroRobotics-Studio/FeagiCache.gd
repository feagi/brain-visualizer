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
var genome_corticalAreaIDList # DELETE ME
var _genome_corticalAreaNameList: Array
var _genome_cortical_id_name_mapping: Dictionary
var _genome_corticalMappings: Dictionary
var _circuit_list : Array
var _circuit_size : Array
var _connectome_properties_mappings: Dictionary
var _connectome_corticalAreas_detailed: Dictionary
var _burst_rate: float




