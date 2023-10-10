extends Object
class_name PackedNetworkResponse
## A way to hold a response from a HTTPRequest
# I wish gdscript supported structs....

var result: RequestWorker.Result
var response_code: int
var incoming_headers: PackedStringArray
var response_body: PackedByteArray

func _init(feagi_result: RequestWorker.Result, feagi_response_code: int, feagi_incoming_headers: PackedStringArray, feagi_response_body: PackedByteArray) -> void:
    result = feagi_result
    response_code = feagi_response_code
    incoming_headers =  feagi_incoming_headers
    response_body = feagi_response_body
