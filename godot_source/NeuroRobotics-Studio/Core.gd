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


# References
var UIManager: UI_Manager
var FeagiCache: FeagiCache

var NetworkAPI : SimpleNetworkAPI
var callLib: Call
var FEAGIAddresses: AddressList
var FEAGICalls: AddressCalls 

func _ready():
	var SSL: String
	var FEAGIRoot: String
	NetworkAPI = $GlobalNetworkSystem
	UIManager = $GlobalUISystem
	FeagiCache = $FeagiCache
	
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
		SSL = http_type
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
		FEAGIRoot = str(network_setting.api_ip_address)
	else:
		FEAGIRoot = str(network_setting.api_ip_address) + ":" + str(network_setting.api_port_address)
	print("CORE FEAGI ROOTADDRESS: ", FEAGIRoot)

	callLib = Call.new(NetworkAPI)
	FEAGIAddresses = AddressList.new(FEAGIRoot, SSL)
	FEAGICalls = AddressCalls.new(FEAGIAddresses, callLib)
	# # # Build the bridge # # # 
	Autoload_variable.Core_BV = $GlobalUISystem/Brain_Visualizer
	Autoload_variable.Core_notification = $GlobalUISystem/Brain_Visualizer/notification
	Autoload_variable.Core_Camera = $GlobalUISystem/Brain_Visualizer/Node3D/Camera3D
	# Retrieve relvant Child Nodes
	# Connect Cache First
	FeagiCache.FullCorticalData_Updated.connect(Relay_fullCorticalData)
	
	# Activate Children
	UIManager.Activate(languageISO)
	UIManager.DataUp.connect(RetrieveEvents)
	UIManager.cache = $FeagiCache
	
	# Lets pull latest info from FEAGI and trigger respective updates
	FEAGICalls.GET_genome_morphologyList()
	FEAGICalls.GET_genome_fileName()
	FEAGICalls.GET_genome_corticalMap()
	FEAGICalls.GET_healthCheck()
	FEAGICalls.GET_connectome_corticalAreas_list_detailed()

####################################
####### Process From Below ########
####################################

# Respond to any events at the core level
# TODO this should be going through cache
func RetrieveEvents(data: Dictionary) -> void:
	if "CortexSelected" in data.keys():
			FEAGICalls.GET_genome_corticalArea_CORTICALAREAEQUALS(data["CortexSelected"])
	if "updatedBurstRate" in data.keys():
			FEAGICalls.POST_feagi_burstEngine(data["updatedBurstRate"])
	pass

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
	
	#are we going to update FROM cache or here?
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
