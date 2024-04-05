extends RefCounted
class_name APIRequestWorkerOutput
## The object that API worker outputs at the end of its work, error or not

var has_timed_out: bool = false ## Did FEAGI not respond?
var has_errored: bool = false ## Did feagi return an error (HTTP 400)
var is_mid_poll: bool = false ## Is this a polling call output that isnt finished?
var response_body: PackedByteArray = [] # The raw data FEAGI returned to us


func _init(timed_out: bool, errored: bool, mid_poll: bool, data: PackedByteArray):
	has_timed_out = timed_out
	has_errored = errored
	is_mid_poll = mid_poll
	response_body = data

## Generate a sucessful response
static func response_success(http_response: PackedByteArray, is_mid_poll: bool) -> APIRequestWorkerOutput: 
	return APIRequestWorkerOutput.new(false, false, is_mid_poll, http_response)

## Generate a response where feagi didnt respond to the http call
static func response_no_response(is_mid_poll: bool) -> APIRequestWorkerOutput:
	return APIRequestWorkerOutput.new(true, false, is_mid_poll, [])

static func response_error_response(http_response: PackedByteArray, is_mid_poll: bool) -> APIRequestWorkerOutput:
	return APIRequestWorkerOutput.new(false, true, is_mid_poll, http_response)


func decode_response_as_string() -> String:
	return response_body.get_string_from_utf8()

## Returns the byte array as a dictionary, with some error checking that causes an empty dict to return if something is wrong
func decode_response_as_dict() -> Dictionary:
	var string: String = response_body.get_string_from_utf8()
	if string == "":
		return {}
	var dict =  JSON.parse_string(string)
	if dict is Dictionary:
		return dict
	return {}

# Returns the generic error that feagi returned as an array, with the first var being the error code and the second the friendly description
func decode_response_as_generic_error_code() -> PackedStringArray:
	var error_code: StringName = "UNDECODABLE"
	var friendly_description: StringName = "UNDECODABLE"
	var feagi_error_response = JSON.parse_string(response_body.get_string_from_utf8()) # should be dictionary but may be null
	if feagi_error_response is Dictionary:
		if "code" in feagi_error_response.keys():
			error_code = feagi_error_response["code"]
		if "description" in feagi_error_response.keys():
			friendly_description = feagi_error_response["description"]
	return PackedStringArray([error_code, friendly_description])
