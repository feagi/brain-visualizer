extends RefCounted
class_name FeagiRequestOutput
## The object that a feagi response worker outputs at the end of its work, error or not (right now only [APIRequestWorker]s, but this can be extended for other worker types in the future)

var failed_requirement_key: StringName = "" ## If defined, the request was never made, the request terminated early due to a failed requirement. Use this to define the failure reason
var has_timed_out: bool = false ## Did FEAGI not respond?
var has_errored: bool = false ## Did feagi return an error (HTTP 400)
var is_mid_poll: bool = false ## Is this a polling call output that isnt finished?
var response_body: PackedByteArray = [] # The raw data FEAGI returned to us
var response_code: int = 0 # HTTP response code (0 = no response, 200 = success, 4xx/5xx = error)
var failed_requirement: bool: ## If a requirement was failed in [FEAGIRequests]
	get: return failed_requirement_key != ""
var success: bool: ## If everything went ok
	get: return !(has_timed_out or has_errored or failed_requirement)

func _init(timed_out: bool, errored: bool, mid_poll: bool, data: PackedByteArray, reason_failed: StringName = "", http_code: int = 0):
	has_timed_out = timed_out
	has_errored = errored
	is_mid_poll = mid_poll
	response_body = data
	failed_requirement_key = reason_failed
	response_code = http_code

## We didn't even make a call, this is just used by [FEAGIRequests] to handle a precondition failure
static func requirement_fail(reason_failed_key: StringName) -> FeagiRequestOutput:
	return FeagiRequestOutput.new(false, false, false, [], reason_failed_key, 0)

## Generate a sucessful response
static func response_success(http_response: PackedByteArray, is_mid_poll: bool, http_code: int = 200) -> FeagiRequestOutput: 
	return FeagiRequestOutput.new(false, false, is_mid_poll, http_response, "", http_code)

## Generate a response where feagi didnt respond to the http call
static func response_no_response(is_mid_poll: bool) -> FeagiRequestOutput:
	return FeagiRequestOutput.new(true, false, is_mid_poll, [], "", 0)

## Generate a response where feagi responded with an error
static func response_error_response(http_response: PackedByteArray, is_mid_poll: bool, http_code: int = 400) -> FeagiRequestOutput:
	return FeagiRequestOutput.new(false, true, is_mid_poll, http_response, "", http_code)

## Best used in requests were multiple calls were made, but we wish to return an overall success
static func generic_success() -> FeagiRequestOutput:
	return FeagiRequestOutput.new(false, false, false, [], "", 200)


func decode_response_as_string() -> String:
	return response_body.get_string_from_utf8()

## Returns the byte array as a dictionary, with some error checking that causes an empty dict to return if something is wrong
func decode_response_as_dict() -> Dictionary:
	var string: String = response_body.get_string_from_utf8()
	# Some endpoints may return trailing null bytes or extra whitespace.
	# Normalize before parsing so callers can treat malformed payloads as empty dictionaries.
	string = string.replace("\u0000", "").strip_edges()
	if string == "":
		return {}
	var parser := JSON.new()
	var parse_error: Error = parser.parse(string)
	if parse_error == OK and parser.data is Dictionary:
		return parser.data
	return {}

## Returns the byte array as an Array, with some error checking that causes an empty array to return if something is wrong
func decode_response_as_array() -> Array:
	var string: String = response_body.get_string_from_utf8()
	string = string.replace("\u0000", "").strip_edges()
	if string == "":
		return []
	var parser := JSON.new()
	var parse_error: Error = parser.parse(string)
	if parse_error == OK and parser.data is Array:
		return parser.data
	return []

#TODO We need a standard for error handling.
## Returns the generic error that feagi returned as an array, with the first var being the error code and the second the friendly description
func decode_response_as_generic_error_code() -> PackedStringArray:
	var error_code: StringName = "UNDECODABLE"
	var friendly_description: StringName = "UNDECODABLE"
	var response_string: String = response_body.get_string_from_utf8()
	
	# Check if response is empty
	if response_string == "":
		return PackedStringArray([error_code, friendly_description])
	
	var trimmed_response: String = response_string.strip_edges()
	
	# Check if response looks like JSON (starts with { or [)
	var is_json: bool = trimmed_response.begins_with("{") or trimmed_response.begins_with("[")
	
	if is_json:
		# Try to parse as JSON - parse_string returns null on failure
		var feagi_error_response = JSON.parse_string(trimmed_response)
		if feagi_error_response is Dictionary:
			# Try FEAGI's current format first
			if "error_code" in feagi_error_response.keys():
				error_code = str(feagi_error_response["error_code"])
			elif "code" in feagi_error_response.keys():
				error_code = str(feagi_error_response["code"])
			
			if "message" in feagi_error_response.keys():
				friendly_description = str(feagi_error_response["message"])
			elif "description" in feagi_error_response.keys():
				friendly_description = str(feagi_error_response["description"])
		else:
			# JSON parsing failed or returned non-dictionary, treat as plain text error
			friendly_description = trimmed_response
			error_code = "JSON_PARSE_FAILED"
	else:
		# Not JSON, treat as plain text error message
		friendly_description = trimmed_response
		error_code = "PLAIN_TEXT_ERROR"
	
	return PackedStringArray([error_code, friendly_description])
