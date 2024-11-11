extends Node # autoload
class_name AutoLoad_FEAGILogger

enum LEVEL {DEBUG, ACTION, WARNING, ERROR, CRASH} # DEBUG is very specific minute details. ACTION is any request / response from FEAGI, WARNING is something unexpected but that can be handled. ERROR is something that causes a risk of crash, CRASH is something unrecoverable
enum LOCATION {CORE_ETC, CACHE, NETWORK, UI_ETC, BRAIN_MONITOR, CIRCUIT_BUILDER}

var is_ready: bool: 
	get: return _is_ready

var log_debug: bool = true # If debug level logs are written to the log queue at all. ALSO blocks writing debug to console
var print_debug_to_console: bool = false # If debug logs will be printed to the console
var print_action_to_console: bool = true # If action logs will be printed to the console
var print_warning_to_console: bool = true # If warning logs will be printed to the console
var print_errors_crash_to_console: bool = true # If  errors / CRASH will be printed to the console
var max_log_array_size: int = 250 # Max number of log events to store in log queue before starting to purge the oldest one. Larger sizes causes slow downs

var _is_ready: bool = false # Has the initialization function been called? If not, nothing will work
var _current_log_queue: Array[Dictionary] = [] # Actual stored log events
var _crash_handler_callable: Callable ## Callable to UI function to run when showing a crash
# NOTE: The UI itself should have buttons to get the log JSON from this object and save it to where relevant

## Log DEBUG events
func BVLogDebug(message: StringName, location: LOCATION, context_JSON: Dictionary = {}) -> void:
	BVLogGeneric(message, location, LEVEL.DEBUG, context_JSON)

## Log Action events
func BVLogAction(message: StringName, location: LOCATION, context_JSON: Dictionary = {}) -> void:
	BVLogGeneric(message, location, LEVEL.ACTION, context_JSON)

## Log Warning events
func BVLogWarning(message: StringName, location: LOCATION, context_JSON: Dictionary = {}) -> void:
	BVLogGeneric(message, location, LEVEL.WARNING, context_JSON)

## Log Error events
func BVLogError(message: StringName, location: LOCATION, context_JSON: Dictionary = {}) -> void:
	BVLogGeneric(message, location, LEVEL.ERROR, context_JSON)

## Log CRASH event and intiate crashing procedure
func BVCrash(message: StringName, location: LOCATION, context_JSON: Dictionary = {}) -> void:
	if !_is_ready:
		push_error("Unable to use FEAGILogger crash handler as it has not been init!")
		return
	BVLogGeneric(message, location, LEVEL.ERROR, context_JSON)

## Generic log handler function. Handles logging to console and to console log array
func BVLogGeneric(message: StringName, location: LOCATION, level: LEVEL = LEVEL.DEBUG, context_JSON: Dictionary = {}) -> void:
	if !_is_ready:
		push_error("FEAGI LOGGER: Recieved log request before Logging System Init!")
		return
	if level == LEVEL.DEBUG and !log_debug:
		return # disabled
	
	match(level):
		LEVEL.DEBUG:
			if print_debug_to_console:
				print(_generate_console_text(message, location, level, context_JSON))
		LEVEL.ACTION:
			if print_action_to_console:
				print(_generate_console_text(message, location, level, context_JSON))
		LEVEL.WARNING:
			if print_warning_to_console:
				push_warning(_generate_console_text(message, location, level, context_JSON))
		_: # treat errors and crashes the same
			if print_errors_crash_to_console:
				push_error(_generate_console_text(message, location, level, context_JSON))

	var log_object: Dictionary = {
		"event" : message,
		"location" : LOCATION.keys()[location],
		"level": LEVEL.keys()[level]
	}
	if !context_JSON.is_empty():
		log_object["context"] = context_JSON

	if _current_log_queue.size() == max_log_array_size:
		_current_log_queue.pop_front() # this can be slow on larger arrays
		# TODO instead of constantly resizing array, having a circular pointer constant size array would be better
	_current_log_queue.append(log_object)

## Get all stored logs as an ordered JSON array with proper formatting
func get_logs_as_JSON() -> StringName:
	return JSON.stringify(_current_log_queue, "\t")

## Generates console text
func _generate_console_text(message: StringName, location: LOCATION, level: LEVEL, context: Dictionary) -> StringName:
	if context.is_empty():
		return &"%s: %s: %s" % [LEVEL.keys()[level], LOCATION.keys()[location], message]
	else:
		return &"%s: %s: %s \n Context: %s" % [LEVEL.keys()[level], LOCATION.keys()[location], message, JSON.stringify(context)]
