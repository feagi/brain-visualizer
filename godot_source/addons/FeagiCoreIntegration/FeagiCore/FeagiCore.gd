extends Node
## Autoloaded, root of all communication adn data to / from FEAGI

#region Statics / consts

enum CONNECTION_STATE {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	DISCONNECTING
}

#endregion


var connection_state: CONNECTION_STATE = CONNECTION_STATE.DISCONNECTED
var network: FEAGINetworking
var genome_requests
var genome_cache


# Zeroth Stage loading. FEAGICore initialization starts here
func _enter_tree():
	network = FEAGINetworking.new()
	network.name = "FEAGINetworking"
	add_child(network)
	var http_node: FEAGIHTTPAPI = FEAGIHTTPAPI.new()
	http_node.name = "FEAGIHTTPAPI"
	network.add_child(http_node)

	# TEST
	attempt_connection(load("res://addons/FeagiCoreIntegration/FeagiCore/Config/network_local_default.tres"))
	
	# At this point, the scripts are initialized, but no attempt to connect to FEAGI was made.

## Use this to attempt connecting to FEAGI using details from the javascript. Returns true is javascript retireved valid info (DOES NOT MEAN CONNECTION WORKED)
func attempt_connection_via_javascript_details() -> bool:
	var endpoint_details: FeagiEndpointDetails = JavaScriptIntegrations.grab_feagi_endpoint_details()
	if endpoint_details.is_invalid():
		return false
	attempt_connection(endpoint_details)
	return true

func attempt_connection(feagi_endpoint_details: FeagiEndpointDetails) -> void:
	if connection_state != CONNECTION_STATE.DISCONNECTED:
		push_error("FEAGICORE: Cannot initiate a new connection when one is already active!")
		return
	network.check_connection_to_FEAGI(feagi_endpoint_details)


