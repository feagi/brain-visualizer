extends Node
class_name HTTPAPI
# Holds all APIRequestWorkers as children and manages them.

signal FEAGI_returned_error(error_identifier: StringName, errored_request_definition: APIRequestWorkerDefinition) # FEAGI responded with an error identifier (or 'UNDECODABLE' if unable to be decoded)
signal FEAGI_unresponsive(unresponded_request_definition: APIRequestWorkerDefinition)



var _API_request_worker_prefab: PackedScene = preload("res://addons/FeagiCoreIntegration/FeagiCore/Networking/API/APIRequestWorker.tscn")
var _headers_to_use: PackedStringArray

func setup(feagi_root_web_address: StringName, headers: PackedStringArray) -> void:
	endpoints = AddressList.new(feagi_root_web_address)
	_headers_to_use = headers
	kill_all_children()

## For sending out HTTP Requests
func FEAGI_API_Request(request_definition: APIRequestWorkerDefinition) -> void:
	var worker: APIRequestWorker = _API_request_worker_prefab.instantiate()
	worker.setup_and_run_from_definition(request_definition)
	
	# connect signals
	worker.FEAGI_responded_success.connect(_feagi_responsed_success)
	worker.FEAGI_responded_success_midpoll.connect(_feagi_responsed_success)
	worker.FEAGI_responded_error.connect(_feagi_responded_error)
	worker.FEAGI_unresponsive.connect(_feagi_unresponsive)

## Stop all HTTP Requests currently processing
func kill_all_children() -> void:
	for child: Node in get_children():
		child.queue_free()


func _feagi_responsed_success(return_body: PackedByteArray, request_definition: APIRequestWorkerDefinition) -> void:
	request_definition.follow_up_function.call(return_body, request_definition.data_to_hold_for_follow_up_function)

func _feagi_responsed_midpoll_success(return_body: PackedByteArray, request_definition: APIRequestWorkerDefinition) -> void:
	request_definition.mid_poll_function.call(return_body, request_definition.data_to_hold_for_follow_up_function)

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
