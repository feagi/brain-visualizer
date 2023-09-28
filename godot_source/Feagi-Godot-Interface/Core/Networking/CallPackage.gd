extends Object
class_name CallPackage
## Contains all info required to make a call to feagi, and what functions to handle the response
## Three Cheers for Dependency Injection!

var complete_URL: StringName
var call_method: HTTPClient.Method 
var initial_response_function: Callable
var data_to_send: Variant
var data_to_buffer: Variant
var polling_method: PollingMethodInterface
var polling_complete_response_function: Callable
var polling_gap_seconds: float
var is_polling: bool = false

func _init(complete_URL_in: StringName, call_method_in: HTTPClient.Method, initial_response_function_in: Callable, data_to_send_in: Variant = {},
  data_to_buffer_in: Variant = null, polling_method_in: PollingMethodInterface = null, polling_complete_response_function_in: Callable = Callable(),
  polling_gap_seconds_in: float = 0.5) -> void:
    complete_URL = complete_URL_in
    call_method = call_method_in
    initial_response_function = initial_response_function_in
    data_to_send = data_to_send_in
    data_to_buffer = data_to_buffer_in
    polling_method = polling_method_in
    polling_complete_response_function = polling_complete_response_function_in
    polling_gap_seconds = polling_gap_seconds_in
    if polling_method != null:
      is_polling = true
