extends VBoxContainer
class_name LeftBarMemoryParameters

## User pressed update button, the following changes are requested
signal user_requested_update(changed_values: Dictionary)

var _line_initial_neuron_lifespan: IntInput
var _line_lifespan_growth_rate: IntInput
var _line_longterm_memory_threshold: IntInput


var _update_button: TextButton_Element

var _growing_cortical_update: Dictionary

func _ready():
	_line_initial_neuron_lifespan = $initial_neuron_lifespan/initial_neuron_lifespan
	_line_lifespan_growth_rate = $lifespan_growth_rate/lifespan_growth_rate
	_line_longterm_memory_threshold = $longterm_memory_threshold/longterm_memory_threshold
	_update_button = $Update_Button
	
	_line_initial_neuron_lifespan.int_confirmed.connect(user_request_initial_neuron_lifespan)
	_line_lifespan_growth_rate.int_confirmed.connect(user_request_lifespan_growth_rate)
	_line_longterm_memory_threshold.int_confirmed.connect(user_request_longterm_memory_threshold)


## set initial values from FEAGI Cache
func display_cortical_properties(cortical_reference: MemoryCorticalArea) -> void:
	_line_initial_neuron_lifespan.current_int = cortical_reference.initial_neuron_lifespan
	_line_lifespan_growth_rate.current_int = cortical_reference.lifespan_growth_rate
	_line_longterm_memory_threshold.current_int = cortical_reference.longterm_memory_threshold
	
	cortical_reference.initial_neuron_lifespan_updated.connect(_feagi_initial_neuron_lifespan)
	cortical_reference.lifespan_growth_rate_updated.connect(_feagi_lifespan_growth_rate)
	cortical_reference.longterm_memory_threshold_updated.connect(_feagi_longterm_memory_threshold)
	
	
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

func _feagi_initial_neuron_lifespan(value: int, _cortical_ref) -> void:
	_line_initial_neuron_lifespan.current_int = value

func _feagi_lifespan_growth_rate(value: int, _cortical_ref) -> void:
	_line_lifespan_growth_rate.current_int = value

func _feagi_longterm_memory_threshold(value: int, _cortical_ref) -> void:
	_line_longterm_memory_threshold.current_int  = value

# Connected via TSCN to editable textboxes
func _enable_update_button():
	_update_button.disabled = false
