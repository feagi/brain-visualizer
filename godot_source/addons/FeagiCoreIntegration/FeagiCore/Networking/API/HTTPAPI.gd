extends Node
class_name HTTPAPI
# Holds all APIRequestWorkers as children and manages them.

var _API_request_worker_prefab: PackedScene# = preload("")

func FEAGI_API_Request(request_definition: APIRequestWorkerDefinition) -> void:
	pass
