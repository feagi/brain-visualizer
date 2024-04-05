extends Node
class_name FEAGIHTTPAPI
# Holds all APIRequestWorkers as children and manages them.

enum HTTP_HEALTH {
	NO_CONNECTION,
	ERROR,
	CONNECTABLE
}

signal FEAGI_http_health_changed(health: HTTP_HEALTH)
signal FEAGI_returned_error(error_identifier: StringName, errored_request_definition: APIRequestWorkerDefinition) # FEAGI responded with an error identifier (or 'UNDECODABLE' if unable to be decoded)
signal FEAGI_unresponsive(unresponded_request_definition: APIRequestWorkerDefinition)

var http_health: HTTP_HEALTH:
	get: 
		return _http_health
	set(v): 
		# Always inform if the health changes, but repeatadly inform of no connection
		if v == HTTP_HEALTH.NO_CONNECTION or v != _http_health:
			_http_health = v
			FEAGI_http_health_changed.emit(v)
var call_list: FEAGIHTTPCallList ## All the calls one can send to the FEAGI API, wrapped in an easy class


var _API_request_worker_prefab: PackedScene = preload("res://addons/FeagiCoreIntegration/FeagiCore/Networking/API/APIRequestWorker.tscn")
var _headers_to_use: PackedStringArray
var _http_health: HTTP_HEALTH  = HTTP_HEALTH.NO_CONNECTION

## Used to setup (or reset) the HTTP API for a specific FEAGI instance
func connect_http(feagi_root_web_address: StringName, headers: PackedStringArray) -> void:
	_headers_to_use = headers
	
	call_list = FEAGIHTTPCallList.new(feagi_root_web_address)
	call_list.initiate_call_to_FEAGI.connect(_FEAGI_API_Request)
	
	kill_all_children() # in case of a reset, make sure any stranglers are gone

## Disconnect all HTTP systems from FEAGI
func disconnect_http() -> void:
	kill_all_children()
	call_list = null
	http_health = HTTP_HEALTH.NO_CONNECTION
	
## Stop all HTTP Requests currently processing
func kill_all_children() -> void:
	for child: Node in get_children():
		child.queue_free()

## Used by the special health check http call to control the state of this [FEAGIHTTPAPI]
func FEAGI_healthcheck_responded(current_health: HTTP_HEALTH) -> void:
	http_health = current_health

func FEAGI_API_Request(request_definition: APIRequestWorkerDefinition) -> APIRequestWorker: # v2
	var worker: APIRequestWorker = _API_request_worker_prefab.instantiate()
	add_child(worker)
	worker.setup_and_run_from_definition(_headers_to_use, request_definition)
	return worker

## For sending out HTTP Requests, best not to call directly, use the function in call_list
func _FEAGI_API_Request(request_definition: APIRequestWorkerDefinition) -> void:
	var worker: APIRequestWorker = _API_request_worker_prefab.instantiate()
	add_child(worker)
	worker.setup_and_run_from_definition(_headers_to_use, request_definition)
	
	# connect signals
	worker.FEAGI_responded_success.connect(_feagi_responsed_success)
	worker.FEAGI_responded_success_midpoll.connect(_feagi_responsed_success)
	worker.FEAGI_responded_error.connect(_feagi_responded_error)
	worker.FEAGI_unresponsive.connect(_feagi_unresponsive)

## Feagi responded with an HTTP 200
func _feagi_responsed_success(return_body: PackedByteArray, request_definition: APIRequestWorkerDefinition) -> void:
	if !request_definition.follow_up_function.is_valid():
		push_error("FEAGI NETWORK HTTP: Invalid follow up function defined for %s!" % request_definition.full_address)
		return
	request_definition.follow_up_function.call(return_body, request_definition)

## Feagi responded with an HTTP 200 but this is a midpoll call
func _feagi_responsed_midpoll_success(return_body: PackedByteArray, request_definition: APIRequestWorkerDefinition) -> void:
	if !request_definition.mid_poll_function.is_valid():
		push_error("FEAGI NETWORK HTTP: Invalid mid poll function defined for %s!" % request_definition.full_address)
		return
	request_definition.mid_poll_function.call(return_body, request_definition)

## FEAGI responded but with an error
func _feagi_responded_error(_http_status: int, return_body: PackedByteArray, request_definition: APIRequestWorkerDefinition) -> void:
	var error_code: StringName = "UNDECODABLE"
	var feagi_error_response = JSON.parse_string(return_body.get_string_from_utf8()) # should be dictionary but may be null
	if feagi_error_response is Dictionary:
		if "code" in feagi_error_response.keys():
			error_code = feagi_error_response["code"]
	FEAGI_returned_error.emit(error_code, request_definition)

## FEAGI didn't respond. likely crashed
func _feagi_unresponsive(request_definition: APIRequestWorkerDefinition) -> void:
	FEAGI_unresponsive.emit(request_definition)





