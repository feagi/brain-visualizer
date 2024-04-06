extends Node
class_name FEAGIHTTPAPI
# Holds all APIRequestWorkers as children and manages them.

enum HTTP_HEALTH {
	NO_CONNECTION,
	ERROR,
	CONNECTABLE
}

signal FEAGI_http_health_changed(health: HTTP_HEALTH)
signal FEAGI_returned_error(error_identifier_and_friendly_description: PackedStringArray, request_definition: APIRequestWorkerDefinition) # FEAGI responded with an error identifier (or 'UNDECODABLE' if unable to be decoded)
signal FEAGI_unresponsive(request_definition: APIRequestWorkerDefinition)

var address_list: FEAGIHTTPAddressList = null
var http_health: HTTP_HEALTH:
	get: 
		return _http_health

var _API_request_worker_prefab: PackedScene = preload("res://addons/FeagiCoreIntegration/FeagiCore/Networking/API/APIRequestWorker.tscn")
var _headers_to_use: PackedStringArray
var _http_health: HTTP_HEALTH  = HTTP_HEALTH.NO_CONNECTION

## Used to setup (or reset) the HTTP API for a specific FEAGI instance
func connect_http(feagi_root_web_address: StringName, headers: PackedStringArray) -> void:
	_headers_to_use = headers
	address_list = FEAGIHTTPAddressList.new(feagi_root_web_address)
	kill_all_children() # in case of a reset, make sure any stranglers are gone

## Disconnect all HTTP systems from FEAGI
func disconnect_http() -> void:
	kill_all_children()
	_http_health = HTTP_HEALTH.NO_CONNECTION
	FEAGI_http_health_changed.emit(_http_health)
	address_list = null
	
## Stop all HTTP Requests currently processing
func kill_all_children() -> void:
	for child: Node in get_children():
		child.queue_free()

## Make a call to FEAGI using HTTP. Make sure to use the returned worker reference to get the response output when complete
func make_HTTP_call(request_definition: APIRequestWorkerDefinition) -> APIRequestWorker: # v2
	var worker: APIRequestWorker = _API_request_worker_prefab.instantiate()
	add_child(worker)
	worker.setup_and_run_from_definition(_headers_to_use, request_definition)
	return worker

## Runs a health check call over HTTP, updates the cache with the results (notably genome availability), and informs core about connectability
func run_HTTP_healthcheck() -> void:
	#NOTE: Due to the more unique usecase, we are keeping this function here instead of [FEAGIRequests]
	var health_check_request: APIRequestWorkerDefinition = FEAGIHTTPCallList.GET_healthCheck_FEAGI_VALIDATION()
	var health_check_worker: APIRequestWorker = make_HTTP_call(health_check_request)
	
	await health_check_worker.worker_done
	
	var cortical_area_data: APIRequestWorkerOutput = health_check_worker.retrieve_output_and_close()
	if cortical_area_data.has_timed_out:
		_http_health = HTTP_HEALTH.NO_CONNECTION
		FEAGI_http_health_changed.emit(_http_health)
		return
	if cortical_area_data.has_errored:
		_http_health = HTTP_HEALTH.ERROR
		FEAGI_http_health_changed.emit(HTTP_HEALTH.ERROR)
		#TODO do something with the error code?
		return
	
	var health_data: Dictionary = cortical_area_data.decode_response_as_dict()
	FeagiCore.feagi_local_cache.update_health_from_FEAGI_dict(health_data)
	_http_health = HTTP_HEALTH.CONNECTABLE
	FEAGI_http_health_changed.emit(HTTP_HEALTH.CONNECTABLE)
	








