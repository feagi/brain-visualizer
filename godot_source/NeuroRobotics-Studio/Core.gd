extends Node
class_name Core

####################################
####### Configuration & Setup ######
####################################
#var FEAGI_RootAddress = ""
#
## Get Requests
#var SEC = "HTTP://"

@export var languageISO := "eng" #TODO proxy changes to UI manager

func _ready():
	var http_type = JavaScriptBridge.eval(""" 
		function get_port() {
			var url_string = window.location.href;
			var url = new URL(url_string);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("http_type");
			return ipAddress;
		}
		get_port();
		""")
	if http_type != null:
		AddressList.FEAGI_SEC = http_type
	var port_disabled = JavaScriptBridge.eval(""" 
		function get_port() {
			var url_string = window.location.href;
			var url = new URL(url_string);
			const searchParams = new URLSearchParams(url.search);
			const ipAddress = searchParams.get("port_disabled");
			return ipAddress;
		}
		get_port();
		""")
	if port_disabled == "true":
		AddressList.rootAddress = str(network_setting.api_ip_address)
	else:
		AddressList.rootAddress = str(network_setting.api_ip_address) + ":" + str(network_setting.api_port_address)
	print("CORE FEAGI ROOTADDRESS: ", AddressList.rootAddress)
	# # # Build the bridge # # # 
	Autoload_variable.Core_BV = $GlobalUISystem/Brain_Visualizer
	Autoload_variable.Core_notification = $GlobalUISystem/Brain_Visualizer/notification
	Autoload_variable.Core_Camera = $GlobalUISystem/Brain_Visualizer/Node3D/Camera3D
	# Retrieve relvant Child Nodes
	NetworkAPI = $GlobalNetworkSystem
	UIManager = $GlobalUISystem
	FeagiCache = $FeagiCache
	# Connect Cache First
	FeagiCache.FullCorticalData_Updated.connect(Relay_fullCorticalData)
	
	# Activate Children
	UIManager.Activate(languageISO)
	UIManager.DataUp.connect(RetrieveEvents)
	UIManager.cache = $FeagiCache
	
	# Lets pull latest info from FEAGI and trigger respective updates
	Update_CortinalAreasIDs()
	Update_MorphologyList()
	Update_GenomeFileName()
	Update_ConnectomeMappingReport()
	Update_CorticalAreaNameList()
	Update_Genome_CorticalMappings()
	GET_health_status()
	Update_Genome_CorticalMappings()
	GET_Connectome_CorticalAreas_Detailed()

####################################
####### Process From Below ########
####################################

# Respond to any events at the core level
# TODO this should be going through cache
func RetrieveEvents(data: Dictionary) -> void:
	if "CortexSelected" in data.keys():
			Update_Genome_CorticalArea_SPECIFIC(data["CortexSelected"])
	if "updatedBurstRate" in data.keys():
			Update_BurstRate(data["updatedBurstRate"])
	pass
	
####################################
##### Update Feagi Dependents ######
####################################

# These are used to update certain elements from Feagi Directly

# The Godot Style guide can't stop me because I can't read!
# HTTP://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html#one-statement-per-line
#TODO name these functions much better to be consistant
# Run these to grab latest information from Feagi, and eventually trigger an update on all dependents
# WARNING: due to network latency, there is a delay between calling this and results appearing.
# Design your code with this in mind, it may be best to include any changes you desire in the _Relay function
# Note: _CR means custom relay function
func Update_IPUs(): Call_GET(AddressList.GET_feagi_pns_current_ipu, _Relay_IPUs)
func Update_OPUs(): Call_GET(AddressList.GET_feagi_pns_current_opu, _Relay_OPUs)
func Update_CortinalAreasIDs(): Call_GET(AddressList.GET_genome_corticalAreaIDList, _Relay_CorticalAreasIDs)
func Update_MorphologyList(): Call_GET(AddressList.GET_genome_morphologyList, _Relay_MorphologyList)
func Update_GenomeFileName(): Call_GET(AddressList.GET_genome_fileName, _Relay_GenomeFileName)
func Update_Genome_CorticalMappings(): Call_GET(AddressList.GET_genome_corticalMap, _Relay_Genome_CorticalMappings)
func Update_ConnectomeMappingReport(): Call_GET(AddressList.GET_connectome_properties_mappings, _Relay_ConnectomeMappingReport)
func Update_CorticalAreaNameList(): Call_GET(AddressList.GET_genome_corticalAreaNameList, _Relay_CorticalAreaNameList)
func GOTO_CORTICALLOCATION(input_name): Call_GET(AddressList.GET_genome_corticalNameLocation_CORTICALNAMEEQUALS+input_name, _Relay_CorticalAreaLOCATION)
func Update_Genome_CorticalArea_SPECIFIC(corticalAreaID: String): Call_GET(AddressList.GET_genome_corticalArea_CORTICALAREAEQUALS, _Relay_GET_Genome_CorticalArea, corticalAreaID ) 
func Update_Dimensions(): Call_GET(AddressList.GET_connectome_properties_dimensions, _Relay_Dimensions)
func Update_Refresh_Rate(): Call_GET(AddressList.GET_burstEngine_stimulationPeriod, _Relay_Get_BurstRate)
func Update_Cortical_grab_id(input): Call_GET(AddressList.GET_genome_corticalIDNameMapping+input, _Relay_Cortical_grab_id)
func Update_Afferent_list(input): Call_GET(AddressList.GET_genome_corticalMappings_afferents_corticalArea_CORTICALAREAEQUALS+input, _Relay_Afferent)
func Update_Efferent_list(input): Call_GET(AddressList.GET_genome_corticalMappings_efferents_corticalArea_CORTICALAREAEQUALS+input, _Relay_Efferent)
func Get_Morphology_information(morphologyName: String): Call_GET(AddressList.GET_genome_morphologyNameEQUALS+morphologyName, _Relay_Morphology_information)
func Get_Morphology_information_CR(morphologyName: String, relayFunc): Call_GET(AddressList.GET_genome_morphologyNameEQUALS+morphologyName, relayFunc)
func GET_USUAGE_MORPHOLOGY(input): Call_GET(AddressList.GET_genome_morphologyUsage_MORPHOLOGYNAMEEQUALS+input, _Relay_Morphology_usuage)
func Update_destination(input): Call_GET(AddressList.GET_genome_mappingProperties_CORTICALAREAEQUALS+input, _Relay_Update_Destination)
func Get_circuit_list(): Call_GET(AddressList.GET_genome_circuits, _Relay_circuit_list)
func Get_circuit_size(name_input): Call_GET(AddressList.GET_genome_circuitSize_CIRCUITNAMEEQUALS+name_input, _Relay_circuit_size)
func Get_mem_data(input_name: String): Call_GET(AddressList.GET_monitoring_neuron_membranePotential_CORTICALAREAEQUALS+input_name, _Relay_Update_mem)
func Get_syn_data(input_name: String): Call_GET(AddressList.GET_monitoring_neuron_synapticPotential_CORTICALAREAEQUALS+input_name, _Relay_Update_syn)
func Get_CorticalTypeOptions(input_name: String): Call_GET(AddressList.GET_genome_corticalTypeOptions_CORTICALTYPEQUALS+input_name, _Relay_update_OPU)
func GET_BurstRate(): Call_GET(AddressList.GET_burstEngine_stimulationPeriod, _Relay_Get_BurstRate)
func GET_health_status(): Call_GET(AddressList.GET_healthCheck, _Relay_Get_Health)
func GET_Connectome_CorticalAreas_Detailed(): Call_GET(AddressList.GET_connectome_corticalAreas_list_detailed, _Relay_ConnectomeCorticalAreasListDetailed)

func Update_BurstRate(newBurstRate: float):
	Call_POST(AddressList.POST_feagi_burstEngine, _Relay_ChangedBurstRate, {"burst_duration": newBurstRate})
	

func Update_cortical_area(input):
	Call_POST(AddressList.POST_genome_corticalArea, _Relay_updated_cortical, input)
	
func Update_custom_cortical_area(input):
	#using _Relay_updated_cortical since they both pass, thats it. leverage the same to save space
	Call_POST(AddressList.POST_genome_customCorticalArea, _Relay_updated_cortical, input)
	
func POST_Request_Brain_visualizer(url, dataIn):
	#using _Relay_updated_cortical since they both pass, thats it. leverage the same to save space
	Call_POST(url, _Relay_updated_cortical, dataIn)
	
func Update_Mapping_Properties(dataIn, extra_name =""): 
	Call_PUT(AddressList.PUT_genome_mappingProperties + extra_name, _Relay_PUT_Mapping_Properties, dataIn)

func PUT_Request_Brain_visualizer(url, dataIn): 
	Call_PUT(url, _Relay_PUT_BV_functions, dataIn)

func Delete_cortical_area(dataIn): 
	Call_DELETE(AddressList.DELETE_genome_corticalArea_CORTICALAREANAMEEQUALS + dataIn, _Relay_DELETE_Cortical_area)

func DELETE_Request_Brain_visualizer(url):
	Call_DELETE(url, _Relay_DELETE_Cortical_area)

func Update_Genome_CorticalArea(dataIn: Dictionary): Call_PUT(AddressList.PUT_genome_corticalArea, _Relay_PUT_Genome_CorticalArea, dataIn)
####################################
###### Relay Feagi Dependents ######
####################################

####### From FEAGI Directly ########
# In this section, add any code that must be called when FEAGI updates these
# values
#TODO error handling

func _Relay_IPUs(_result, _response_code, _headers, body: PackedByteArray):
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	Autoload_variable.Core_notification.generate_notification_message(api_data, _response_code, "Update_IPUs", "/v1/feagi/feagi/pns/current/ipu")
	# FEAGI updated IPUs
	if LogNetworkError(_result): print("Unable to get IPUs"); return
	FeagiCache.pns_current_IPU = JSON.parse_string(body.get_string_from_utf8())

func _Relay_OPUs(_result, _response_code, _headers, body: PackedByteArray):
	# FEAGI updated OPUs
	if LogNetworkError(_result): print("Unable to get OPUs"); return
	FeagiCache.pns_current_OPU = JSON.parse_string(body.get_string_from_utf8())

func _Relay_CorticalAreasIDs(_result, _response_code, _headers, body: PackedByteArray):
	# FEAGI updated Cortical Areas
	if LogNetworkError(_result): print("Unable to get Cortical Area IDs"); return
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	Autoload_variable.Core_notification.generate_notification_message(api_data, _response_code, "_Relay_CorticalAreasIDs", "")
	if api_data != null:
		FeagiCache.genome_corticalAreaIDList = JSON.parse_string(body.get_string_from_utf8())
		UIManager.RelayDownwards(REF.FROM.genome_corticalAreaIdList, FeagiCache.genome_corticalAreaIDList)

func _Relay_ChangedBurstRate(_result, _response_code, _headers, _body: PackedByteArray):
	# FEAGI updated Burst Rate
	if LogNetworkError(_result): print("Unable to change Burst Rate"); return
	#GET_BurstRate() #Confirm new burst rate

func _Relay_updated_cortical(_result, _response_code, _headers, _body: PackedByteArray):
	var test_json_conv = JSON.new()
	test_json_conv.parse(_body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	Autoload_variable.Core_notification.generate_notification_message(api_data, _response_code, "_Relay_updated_cortical", "/v1/feagi/genome/cortical_area", "POST")
	if LogNetworkError(_result): print("Unable to get Cortical"); return
#	Autoload_variable.Core_BV._on_send_feagi_request_completed(api_data, _response_code, "_Relay_updated_cortical", "/v1/feagi/genome/cortical_area")
	
func _Relay_Get_BurstRate(_result, _response_code, _headers, body: PackedByteArray):
	if LogNetworkError(_result): print("Unable to get Burst Rate"); return
	FeagiCache.burst_rate = float(JSON.parse_string(body.get_string_from_utf8()))
	UIManager.RelayDownwards(REF.FROM.burstEngine, FeagiCache.burst_rate)
	$GlobalUISystem/Brain_Visualizer/notification.generate_notification_message("", _response_code, "_on_get_burst_request_completed", "/v1/feagi/feagi/burst_engine/stimulation_period")

func _Relay_Get_Health(_result, _response_code, _headers, body: PackedByteArray):
	if LogNetworkError(_result): print("Unable to get Burst Rate"); return
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	UIManager.RelayDownwards(REF.FROM.healthstatus, api_data)

func _Relay_Dimensions(_result, _response_code, _headers, body: PackedByteArray):
	#Feagi Updated Dimensions
	if LogNetworkError(_result): print("Unable to get Updated Dimensions"); return
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	var create_json = {}
	if api_data != null:
		for i in api_data:
			create_json[i] = api_data[i]
		Godot_list.genome_data["genome"] = create_json

func _Relay_Cortical_grab_id(_result, _response_code, _headers, body: PackedByteArray):
	#Feagi Updated Dimensions
	if LogNetworkError(_result): print("Unable to get Cortical IDs"); return
	Autoload_variable.Core_BV._on_get_cortical_dst_request_completed(_result, _response_code, _headers, body)

func _Relay_Afferent(_result, _response_code, _headers, body: PackedByteArray):
	#Feagi Updated Dimensions
	if LogNetworkError(_result): print("Unable to get Afferent"); return
	Autoload_variable.Core_BV._on_afferent_request_completed(_result, _response_code, _headers, body)
	
func _Relay_MorphologyList(_result, _response_code, _headers, body: PackedByteArray):
	# FEAGI updated Morphology list
	if LogNetworkError(_result): print("Unable to get Morphology List"); return
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	if api_data != null:
		FeagiCache.genome_morphologyList = JSON.parse_string(body.get_string_from_utf8())
		UIManager.RelayDownwards(REF.FROM.genome_morphologyList, FeagiCache.genome_morphologyList)
	$GlobalUISystem/Brain_Visualizer/notification.generate_notification_message(api_data, _response_code, "_on_morphology_list_request_completed", "/v1/feagi/genome/morphology_list")

func _Relay_GenomeFileName(_result, _response_code, _headers, body: PackedByteArray):
	if LogNetworkError(_result): print("Unable to get Genome File Name"); return
	var stringName := (body.get_string_from_utf8())
	stringName = stringName.replace('"', "") # Remove build in quotation marks
	stringName = stringName.left(-5) # remove the .json
	FeagiCache.genome_fileName =  stringName
	UIManager.RelayDownwards(REF.FROM.genome_fileName, stringName)
	if Autoload_variable.Core_BV.visible:
		Autoload_variable.Core_BV._on_get_genome_name_request_completed(_result, _response_code, _headers, body)

func _Relay_CorticalAreaLOCATION(_result, _response_code, _headers, body: PackedByteArray):
	if LogNetworkError(_result): 
		print("Unable to get Cortical Areas location"); 
		return
	Autoload_variable.Core_Camera._on_grab_location_of_cortical_request_completed(_result, _response_code, _headers, body)
	
func _Relay_CorticalAreaNameList(_result, _response_code, _headers, body: PackedByteArray):
	# FEAGI updated Cortical Area Name list
	if LogNetworkError(_result): print("Unable to get Cortical Areas"); return
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	if api_data != null:
		FeagiCache.genome_corticalAreaNameList = JSON.parse_string(body.get_string_from_utf8())
		UIManager.RelayDownwards(REF.FROM.genome_corticalAreaNameList, FeagiCache.genome_corticalAreaNameList)
	
func _Relay_GET_Genome_CorticalArea(_result, _response_code, _headers, body: PackedByteArray):
	# Note, this is for a specific cortical Area
	if LogNetworkError(_result): print("Unable to get Specific Cortical Area"); return
	var specificCortex = JSON.parse_string(body.get_string_from_utf8())
	# Hacky workaround since godot json gets confused on quotes
	for key in specificCortex.keys():
		if specificCortex[key] is int:
			specificCortex[key] = float(specificCortex[key])
	
	are we going to update FROM cache or here?
	UIManager.RelayDownwards(REF.FROM.genome_corticalArea, specificCortex)
	Autoload_variable.Core_notification.generate_notification_message(specificCortex, _response_code, "_Relay_GET_Genome_CorticalArea", "/v1/feagi/genome/cortical_area")

func _Relay_CorticalMap(_result, _response_code, _headers, body: PackedByteArray):
	# FEAGI updating cortical ID - Name mappings
	if LogNetworkError(_result): print("Unable to get Cortical mapping"); return
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	if api_data != null:
		FeagiCache.genome_cortical_id_name_mapping = JSON.parse_string(body.get_string_from_utf8())
		UIManager.RelayDownwards(REF.FROM.genome_cortical_id_name_mapping, FeagiCache.genome_cortical_id_name_mapping)

func _Relay_Morphology_information(_result, _response_code, _headers, _body: PackedByteArray):
	if LogNetworkError(_result): print("Unable to get Morphology Information"); return
	Autoload_variable.Core_BV._on_get_morphology_request_completed(_result, _response_code, _headers, _body)

func _Relay_Morphology_usuage(_result, _response_code, _headers, _body: PackedByteArray):
	if LogNetworkError(_result): print("Unable to get Morphology Information"); return
	Autoload_variable.Core_BV._on_get_morphology_usuage_request_completed(_result, _response_code, _headers, _body)
	
func _Relay_Update_Destination(_result, _response_code, _headers, _body: PackedByteArray):
	if LogNetworkError(_result): print("Unable to get Destination"); return
	Autoload_variable.Core_BV._on_update_destination_info_request_completed(_result, _response_code, _headers, _body)

func _Relay_Update_mem(_result, _response_code, _headers, _body: PackedByteArray):
	if LogNetworkError(_result): print("Unable to get mem request"); return
	Autoload_variable.Core_BV._on_mem_request_request_completed(_result, _response_code, _headers, _body)

func _Relay_Update_syn(_result, _response_code, _headers, _body: PackedByteArray):
	if LogNetworkError(_result): print("Unable to get Syn"); return
	Autoload_variable.Core_BV._on_syn_request_request_completed(_result, _response_code, _headers, _body)

func _Relay_circuit_list(_result, _response_code, _headers, _body: PackedByteArray):
	if LogNetworkError(_result): print("Unable to get Circuit list"); return
	var test_json_conv = JSON.new()
	test_json_conv.parse(_body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	UIManager.RelayDownwards(REF.FROM.circuit_list, api_data)
	$GlobalUISystem/Brain_Visualizer/notification.generate_notification_message(api_data, _response_code, "_on_circuit_request_request_completed", "/v1/feagi/genome/circuits")
	
func _Relay_circuit_size(_result, _response_code, _headers, _body: PackedByteArray):
	if LogNetworkError(_result): print("Unable to get Circuit list"); return
	var test_json_conv = JSON.new()
	test_json_conv.parse(_body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	UIManager.RelayDownwards(REF.FROM.circuit_size, api_data)

func _Relay_update_OPU(_result, _response_code, _headers, _body):
	if LogNetworkError(_result): print("Unable to get Specific OPU"); return
	var test_json_conv = JSON.new()
	test_json_conv.parse(_body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	UIManager.RelayDownwards(REF.FROM.OPULIST, api_data)
#	Autoload_variable.Core_addition._on_cortical_type_options_request_request_completed(_result, _response_code, _headers, _body)

func _Relay_update_IPU(_result, _response_code, _headers, _body):
	if LogNetworkError(_result): print("Unable to get Specific IPU"); return
	var test_json_conv = JSON.new()
	test_json_conv.parse(_body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	UIManager.RelayDownwards(REF.FROM.IPULIST, api_data)
#	Autoload_variable.Core_addition._on_IPU_list_request_completed(_result, _response_code, _headers, _body)

func _Relay_ConnectomeCorticalAreasListDetailed(_result, _response_code, _headers, body):
	if LogNetworkError(_result): print("Unable to get Connectome Cortical Area List Detailed"); return
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	if api_data != null:
		FeagiCache.connectome_corticalAreas_detailed = JSON.parse_string(body.get_string_from_utf8())

func _Relay_Efferent(_result, _response_code, _headers, _body: PackedByteArray):
	if LogNetworkError(_result): print("Unable to get Efferent"); return
	Autoload_variable.Core_BV._on_information_button_request_completed(_result, _response_code, _headers, _body)

func _Relay_ConnectomeMappingReport(_result, _response_code, _headers, body: PackedByteArray):
	if LogNetworkError(_result): print("Unable to get Connectome Mapping Report"); return
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	if api_data != null:
		FeagiCache.connectome_properties_mappings = JSON.parse_string(body.get_string_from_utf8())

func _Relay_Genome_CorticalMappings(_result, _response_code, _headers, body: PackedByteArray):
	if LogNetworkError(_result): print("Unable to get Connectome Mapping Report"); return
	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	var api_data = test_json_conv.get_data()
	if api_data != null:
		FeagiCache.genome_corticalMappings = JSON.parse_string(body.get_string_from_utf8())

func _Relay_PUT_Genome_CorticalArea(_result, _response_code, _headers, _body: PackedByteArray):
	pass 

func _Relay_PUT_Mapping_Properties(_result, _response_code, _headers, _body: PackedByteArray):
	pass 

func _Relay_PUT_BV_functions(_result, _response_code, _headers, _body: PackedByteArray):
	pass 

func _Relay_DELETE_Cortical_area(_result, _response_code, _headers, _body):
	pass

##### Proxied from FEAGICache ######

# Convert Raw Connectome data from feagi to a dictionary structure usable by the node graph and other systems
# Dictionary {
# 	StringIDOfCortex:
#		{ "cortexReference": IntId (required by node Graph),
#		  "friendlyName: String
#		  "connections": [int array of connected cortexes, using their cortexReference]}
func Relay_fullCorticalData(dataIn: Dictionary):
	UIManager.RelayDownwards(REF.FROM.godot_fullCorticalData, dataIn)
	pass


####################################
############## Calls ###############
####################################

# TODO add error handling should network fail!
func Call_GET(address: String, proxiedFunction, stringToAppend: String = ""):
	NetworkAPI.Call(address + stringToAppend, HTTPClient.METHOD_GET, proxiedFunction)

func Call_POST(address: String, proxiedFunction, data2Send):
	NetworkAPI.Call(address, HTTPClient.METHOD_POST, proxiedFunction, data2Send)

func Call_PUT(address: String, proxiedFunction, data2Send):
	NetworkAPI.Call(address, HTTPClient.METHOD_PUT, proxiedFunction, data2Send)
	
func Call_DELETE(address: String, proxiedFunction):
	NetworkAPI.Call(address, HTTPClient.METHOD_DELETE, proxiedFunction)


####################################
############# Internals ############
####################################

# References
var NetworkAPI : SimpleNetworkAPI
var UIManager : UI_Manager
var FeagiCache: FeagiCache

# TODO: delete this comment block, code now resides in address list. Keep it now for debugging temporarily
#var ADD_GET_IPUList:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/feagi/pns/current/ipu"
#var ADD_GET_OPUList:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/feagi/pns/current/opu"
#var ADD_GET_CorticalAreasIDs:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_area_id_list"
#var ADD_GET_MorphologyList:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/morphology_list"
#var ADD_GET_GenomeFileName:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/file_name"
#var ADD_GET_ConnectomeMappingReport:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/connectome/properties/mappings"
#var ADD_GET_ConnectomCorticalAreasListDetailed:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/connectome/cortical_areas/list/detailed"
#var ADD_GET_CorticalAreaNameList:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_area_name_list"
#var ADD_GET_CorticalAreaNameLOCATION:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_name_location?cortical_name="
#var ADD_GET_Genome_CorticalArea:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_area?cortical_area="
#var ADD_GET_Genome_CorticalMap:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_map"
#var ADD_GET_Afferent:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_mappings/afferents?cortical_area="
#var ADD_GET_Efferent:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_mappings/efferents?cortical_area="
#var ADD_GET_update_destination:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/mapping_properties?src_cortical_area="
#var ADD_GET_circuit_list:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/circuits"
#var ADD_GET_circuit_size:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/circuit_size?circuit_name="
#var ADD_GET_Dimensions:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/connectome/properties/dimensions"
#var ADD_GET_Morphology_types:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/morphology_types"
#var ADD_GET_stimulation_period:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/feagi/burst_engine/stimulation_period"
#var GET_HEALTH_STATUS:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/health_check"
#var ADD_GET_cortical_id:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_area?cortical_area="
#var ADD_GET_Morphology_information:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/morphology?morphology_name="
#var ADD_GET_Morphology_USUAGE_information:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/morphology_usage?morphology_name="
#var ADD_GET_mem:
#	get: return SEC + FEAGI_RootAddress + '/v1/feagi/monitoring/neuron/membrane_potential?cortical_area='
#var ADD_GET_syn:
#	get: return SEC + FEAGI_RootAddress + '/v1/feagi/monitoring/neuron/synaptic_potential?cortical_area='
#var ADD_OPU:
#	get: return SEC + FEAGI_RootAddress + '/v1/feagi/genome/cortical_type_options?cortical_type='
#var ADD_IPU:
#	get: return SEC + FEAGI_RootAddress + '/v1/feagi/genome/cortical_type_options?cortical_type='
#var ADD_Cortical_Name_Map:
#	get: return SEC + FEAGI_RootAddress + '/v1/feagi/genome/cortical_id_name_mapping'
#
## Post Requests
#var ADD_POST_BurstEngine:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/feagi/burst_engine"
#var ADD_POST_Add_Cortical:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_area"
#var ADD_POST_Add_Custom_Cortical:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/custom_cortical_area"
#
## Put Requests
#var ADD_PUT_Genome_CorticalArea:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_area"
#
#var ADD_PUT_Mapping_Properties:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/mapping_properties"
#
#
## Delete Requests
#var ADD_DELETE_remove_cortical_area:
#	get: return SEC + FEAGI_RootAddress + "/v1/feagi/genome/cortical_area?cortical_area_name="

# Error Checking for network requests. Returns true if there was an error
func LogNetworkError(result: int) -> bool:
	match result:
		0: return false # no error
		1: print("Chunked Body Size MisMatched!")
		2: print("Failed to Connect!")
		3: print("Unable to resolve address!")
		4: print("Result failed due to connection (read / write) error")
		5: print("TLS handshake failed!")
		6: print("No response!")
		7: print("Request exceeded maximum size limit!")
		8: print("Result body decompress failed!")
		9: print("General request failure!")
		10: print("Unable to open downloaded file!")
		11: print("Unable to write to downloaded file!")
		12: print("Maximum redirect limit hit!")
		13: print(" Result timed out!")
	return true