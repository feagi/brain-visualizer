extends VBoxContainer
class_name LeftBarMemoryParameters

## User pressed update button, the following changes are requested
signal user_requested_update(changed_values: Dictionary)

var _line_initial_neuron_lifespan: FloatInput
var _line_lifespan_growth_rate: FloatInput
var _line_longterm_memory_threshold: FloatInput


var _update_button: TextButton_Element

var _growing_cortical_update: Dictionary

func _ready():
	_line_initial_neuron_lifespan = $initial_neuron_lifespan/initial_neuron_lifespan
	_line_lifespan_growth_rate = $lifespan_growth_rate/lifespan_growth_rate
	_line_longterm_memory_threshold = $longterm_memory_threshold
	_update_button = $Update_Button
	
	_line_initial_neuron_lifespan.float_confirmed.connect(user_request_initial_neuron_lifespan)
	_line_lifespan_growth_rate.float_confirmed.connect(user_request_lifespan_growth_rate)
	_line_longterm_memory_threshold.float_confirmed.connect(user_request_longterm_memory_threshold)


## set initial values from FEAGI Cache
func display_cortical_properties(cortical_reference: MemoryCorticalArea) -> void:
	_line_initial_neuron_lifespan.current_float = cortical_reference.initial_neuron_lifespan
	_line_lifespan_growth_rate.current_float = cortical_reference.lifespan_growth_rate
	_line_longterm_memory_threshold.current_float = cortical_reference.longterm_memory_threshold

## User pressed update button
func _user_requests_update() -> void:
	if _growing_cortical_update == {}:
		# If user presses update button but no properties are set to change, do nothing
		_update_button.disabled = true
		return
	print("User requests %d changes to cortical details" % [len(_growing_cortical_update.keys())])
	user_requested_update.emit(_growing_cortical_update)
	_growing_cortical_update = {}

func user_request_initial_neuron_lifespan(value: int) -> void:
	_growing_cortical_update["neuron_init_lifespan"] = value

func user_request_lifespan_growth_rate(value: int) -> void:
	_growing_cortical_update["neuron_lifespan_growth_rate"] = value

func user_request_longterm_memory_threshold(value: int) -> void:
	_growing_cortical_update["neuron_longterm_mem_threshold"] = value

# Connected via TSCN to editable textboxes
func _enable_update_button():
	_update_button.disabled = false
