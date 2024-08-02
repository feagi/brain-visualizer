extends Node
class_name FEAGIHTTPAPI
# Holds all APIRequestWorkers as children and manages them.

enum HTTP_HEALTH {
	NO_CONNECTION,
	ERROR,
	CONNECTABLE,
	RETRYING
}

const HEALTH_CHECK_WORKER_NAME: StringName = "POLLING_HEALTHCHECK_WORKER"

signal FEAGI_http_health_changed(previous_health: HTTP_HEALTH, current_health: HTTP_HEALTH)
signal HTTP_worker_retrying(retry_count: int, max_retry_count, worker: APIRequestWorker, request_definition: APIRequestWorkerDefinition)

var address_list: FEAGIHTTPAddressList = null
var http_health: HTTP_HEALTH:
	get: 
		return _http_health

var _API_request_worker_prefab: PackedScene = preload("res://addons/FeagiCoreIntegration/FeagiCore/Networking/API/APIRequestWorker.tscn")
var _headers_to_use: PackedStringArray
var _http_health: HTTP_HEALTH  = HTTP_HEALTH.NO_CONNECTION
var _retrying_workers: Array[APIRequestWorker] = []

## Used to setup (or reset) the HTTP API for a specific FEAGI instance
func setup(feagi_root_web_address: StringName, headers: PackedStringArray) -> void:
	_headers_to_use = headers
	address_list = FEAGIHTTPAddressList.new(feagi_root_web_address)
	_kill_all_web_workers() # in case of a reset, make sure any stranglers are gone

## Disconnect all HTTP systems from FEAGI
func disconnect_http() -> void:
	_kill_all_web_workers()
	if _http_health != HTTP_HEALTH.NO_CONNECTION:
		_http_health = HTTP_HEALTH.NO_CONNECTION
		# Do not emit in this case, if we are requesting to kill HTTP dont signal up again about it
	address_list = null


## Make a call to FEAGI using HTTP. Make sure to use the returned worker reference to get the response output when complete
func make_HTTP_call(request_definition: APIRequestWorkerDefinition) -> APIRequestWorker:
	var worker: APIRequestWorker = _API_request_worker_prefab.instantiate()
	add_child(worker)
	worker.setup_and_run_from_definition(_headers_to_use, request_definition)
	return worker


## Runs a (single) health check call over HTTP, updates the cache with the results (notably genome availability), and informs core about connectability
func confirm_connectivity() -> void:
	# NOTE: This FEAGI request does not modify anything in FEAGI state on its own, we have full control here
	# NOTE: The signals for retrying are purposfully not connected, since we dont want to trigger those paths yet
	var response_data: FeagiRequestOutput = await FeagiCore.requests.single_health_check_call()

	if response_data.has_timed_out:
		_request_state_change(HTTP_HEALTH.NO_CONNECTION)
		return
	if response_data.has_errored:
		_request_state_change(HTTP_HEALTH.ERROR)
		return

	_request_state_change(HTTP_HEALTH.CONNECTABLE)

## Requests killing the health check polling worker specifically
func kill_polling_healthcheck_worker() -> void:
	for node in get_children():
		if node.name == HEALTH_CHECK_WORKER_NAME:
			(node as APIRequestWorker).kill_worker()
			return

func _request_state_change(new_state: HTTP_HEALTH) -> void:
	var prev_state: HTTP_HEALTH = _http_health
	_http_health = new_state
	if prev_state != HTTP_HEALTH.NO_CONNECTION and new_state == HTTP_HEALTH.NO_CONNECTION:
		# We went from some form of connection to none, close all web workers
		_kill_all_web_workers()
	FEAGI_http_health_changed.emit(prev_state, new_state)
	

## Stop all HTTP Requests currently processing
func _kill_all_web_workers() -> void:
	for child: Node in get_children():
		if child is APIRequestWorker:
			(child as APIRequestWorker).kill_worker()
		else:
			child.queue_free()
	_retrying_workers = []

## When a worker is retrying, this function is run per retry
func _worker_retrying(current_retry_attempt: int, max_number_retries: int, request_definition: APIRequestWorkerDefinition, retrying_worker: APIRequestWorker):
	if len(_retrying_workers) == 0:
		push_warning("FEAGI HTTP: A HTTP worker has entered the retrying state! Retry %d / %d" % [current_retry_attempt, max_number_retries])
		_request_state_change(HTTP_HEALTH.RETRYING)
	
	if !(retrying_worker in _retrying_workers):
		_retrying_workers.append(retrying_worker)
		retrying_worker.worker_recovered_from_retrying.connect(_retrying_worker_recovered_from_retrying)
		retrying_worker.worker_failed_to_recover_from_retrying.connect(_retrying_worker_failed_to_recover)
	
	HTTP_worker_retrying.emit(current_retry_attempt, max_number_retries, request_definition, retrying_worker)
	
# Why are you locked in the bathroom?
func _retrying_worker_recovered_from_retrying(worker: APIRequestWorker):
	push_warning("FEAGI HTTP: A HTTP worker has recovered from the retrying state!") # using warning to make things easier to read
	var index: int = _retrying_workers.find(worker)
	if index != -1:
		_retrying_workers.remove_at(index)
	if len(_retrying_workers) == 0:
		# if there are no more recovering workers, then we have recovered!
		_request_state_change(HTTP_HEALTH.CONNECTABLE)

# Are you talking to me?
func _retrying_worker_failed_to_recover(worker: APIRequestWorker):
	push_error("FEAGI HTTP: A HTTP worker has failed to recover from the retrying state!")
	_request_state_change(HTTP_HEALTH.NO_CONNECTION)
	var index: int = _retrying_workers.find(worker)
	if index != -1:
		_retrying_workers.remove_at(index)

