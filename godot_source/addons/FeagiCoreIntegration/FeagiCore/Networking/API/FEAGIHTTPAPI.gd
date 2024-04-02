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

var http_health: HTTP_HEALTH = HTTP_HEALTH.NO_CONNECTION
var call_list: FEAGIHTTPCallList ## All the calls one can send to the FEAGI API, wrapped in an easy class


var _API_request_worker_prefab: PackedScene = preload("res://addons/FeagiCoreIntegration/FeagiCore/Networking/API/APIRequestWorker.tscn")
var _headers_to_use: PackedStringArray

## Used to setup (or reset) the HTTP API for a specific FEAGI instance
func setup(feagi_root_web_address: StringName, headers: PackedStringArray) -> void:
	call_list = FEAGIHTTPCallList.new(feagi_root_web_address)
	call_list.initiate_call_to_FEAGI.connect(_FEAGI_API_Request)
	_headers_to_use = headers
	kill_all_children() # in case of a reset, make sure any stranglers are gone

## Stop all HTTP Requests currently processing
func kill_all_children() -> void:
	for child: Node in get_children():
		child.queue_free()

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

func _feagi_responsed_success(return_body: PackedByteArray, request_definition: APIRequestWorkerDefinition) -> void:
	if !request_definition.follow_up_function.is_valid():
		push_error("FEAGI NETWORK HTTP: Invalid follow up function defined for %s!" % request_definition.full_address)
		return
	request_definition.follow_up_function.call(return_body, request_definition)

func _feagi_responsed_midpoll_success(return_body: PackedByteArray, request_definition: APIRequestWorkerDefinition) -> void:
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
