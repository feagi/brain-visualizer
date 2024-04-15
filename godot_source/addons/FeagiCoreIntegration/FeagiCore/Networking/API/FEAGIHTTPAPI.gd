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
signal FEAGI_returned_healthcheck_poll()

var address_list: FEAGIHTTPAddressList = null
var http_health: HTTP_HEALTH:
	get: 
		return _http_health

var _API_request_worker_prefab: PackedScene = preload("res://addons/FeagiCoreIntegration/FeagiCore/Networking/API/APIRequestWorker.tscn")
var _headers_to_use: PackedStringArray
var _http_health: HTTP_HEALTH  = HTTP_HEALTH.NO_CONNECTION
var _polling_health_worker: APIRequestWorker = null

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
		if child is APIRequestWorker:
			(child as APIRequestWorker).kill_worker()
		else:
			child.queue_free()
	

## Make a call to FEAGI using HTTP. Make sure to use the returned worker reference to get the response output when complete
func make_HTTP_call(request_definition: APIRequestWorkerDefinition) -> APIRequestWorker: # v2
	var worker: APIRequestWorker = _API_request_worker_prefab.instantiate()
	add_child(worker)
	worker.setup_and_run_from_definition(_headers_to_use, request_definition)
	return worker

## Runs a (single) health check call over HTTP, updates the cache with the results (notably genome availability), and informs core about connectability
func run_HTTP_healthcheck() -> void:
	#NOTE: Due to the more unique usecase, we are keeping this function here instead of [FEAGIRequests]
	var health_check_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_single_GET_call(FeagiCore.network.http_API.address_list.GET_system_healthCheck,)
	var health_check_worker: APIRequestWorker = make_HTTP_call(health_check_request)
	
	await health_check_worker.worker_done
	
	var response_data: FeagiRequestOutput = health_check_worker.retrieve_output_and_close()
	if response_data.has_timed_out:
		_http_health = HTTP_HEALTH.NO_CONNECTION
		FEAGI_http_health_changed.emit(_http_health)
		return
	if response_data.has_errored:
		_http_health = HTTP_HEALTH.ERROR
		FEAGI_http_health_changed.emit(HTTP_HEALTH.ERROR)
		#TODO do something with the error code?
		return
	
	var health_data: Dictionary = response_data.decode_response_as_dict()
	FeagiCore.feagi_local_cache.update_health_from_FEAGI_dict(health_data)
	_http_health = HTTP_HEALTH.CONNECTABLE
	FEAGI_http_health_changed.emit(HTTP_HEALTH.CONNECTABLE)
	

## Sets up Health polling,  run only once feagi is setup and connect
func poll_HTTP_health() -> void:
	#NOTE: Due to the more unique usecase, we are keeping this function here instead of [FEAGIRequests]
	if _http_health != HTTP_HEALTH.CONNECTABLE:
		push_error("FEAGICORE NETWORKING HTTPAPI: Cannot start polling health if we havent confirmed connection!")
		return
	
	var polling_health_check_request: APIRequestWorkerDefinition = APIRequestWorkerDefinition.define_polling_call(
		FeagiCore.network.http_API.address_list.GET_system_healthCheck,
		HTTPClient.METHOD_GET,
		null,
		5.0,
	)
	
	attempt_kill_poll_health_worker() # Kill current worker if its running
	
	_polling_health_worker = make_HTTP_call(polling_health_check_request)
	_polling_health_worker.worker_retrieved_latest_poll.connect(_retrieved_poll_from_HTTP_health)
	
	await _polling_health_worker.worker_done # This only happens when the health dies

## Kills the polling health worker if its running
func attempt_kill_poll_health_worker() -> void:
	if _polling_health_worker != null:
		_polling_health_worker.kill_worker()
	_polling_health_worker = null

## Upong retrieving poll data from above poll
func _retrieved_poll_from_HTTP_health(response_data: FeagiRequestOutput) -> void:
	
	if response_data.has_timed_out:
		_http_health = HTTP_HEALTH.NO_CONNECTION
		FEAGI_http_health_changed.emit(_http_health)
		return
	if response_data.has_errored:
		_http_health = HTTP_HEALTH.ERROR
		FEAGI_http_health_changed.emit(HTTP_HEALTH.ERROR)
		#TODO do something with the error code?
		return
	
	var health_data: Dictionary = response_data.decode_response_as_dict()
	FeagiCore.feagi_local_cache.update_health_from_FEAGI_dict(health_data)
	FEAGI_returned_healthcheck_poll.emit()




