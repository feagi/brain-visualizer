extends Object
class_name APIRequestWorkerPool
## Responsible for managing all instances of [APIRequestWorker]

const DEF_MIN_WORKERS_AVAILABLE: int = 5
const API_REQUEST_WORKER_PREFAB: PackedScene = preload("res://Feagi-Godot-Interface/Core/Networking/API/APIRequestWorker.tscn")

var endpoints: AddressList
var API_request_workers_available: Array[APIRequestWorker]

var _headers_to_use: PackedStringArray
var _API_request_worker_parent: Node

func _init(feagi_root_web_address: StringName, headers_to_use: PackedStringArray, API_request_worker_parent: Node) -> void:
	endpoints = AddressList.new(feagi_root_web_address)
	_spawn_initial_workers()
	_headers_to_use = headers_to_use
	_API_request_worker_parent = API_request_worker_parent

## For sending out HTTP Requests
func FEAGI_API_Request(request_definition: APIRequestWorkerDefinition) -> void:
	var worker: APIRequestWorker = _grab_worker()
	worker.setup_and_run_from_definition(request_definition)


## Spawns initial RequestWorkers
func _spawn_initial_workers() -> void:
	for i in DEF_MIN_WORKERS_AVAILABLE:
		API_request_workers_available.append(_spawn_worker())

## Grabs either an available [APIRequestWorker] (or if none are available, spawns one first)
func _grab_worker() -> APIRequestWorker:
	var worker: APIRequestWorker
	if API_request_workers_available.size() > 0:
		worker = API_request_workers_available.pop_back()
	else:
		worker = _spawn_worker()
	return worker

## Spawns a APIRequestWorker
func _spawn_worker() -> APIRequestWorker:
	var worker: APIRequestWorker = API_REQUEST_WORKER_PREFAB.instantiate()
	worker.initialization(self, _headers_to_use, _API_request_worker_parent)
	return worker
