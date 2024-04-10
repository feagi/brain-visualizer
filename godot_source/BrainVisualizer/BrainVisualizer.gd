extends Node
class_name BrainVisualizer
## The root node, while this doesnt handle UI directly, it does handle some of the coordination with FeagiCore

@export var FEAGI_configuration: FeagiGeneralSettings
@export var default_FEAGI_network_settings: FeagiEndpointDetails

var UI_manager: UIManager:
	get: return _UI_manager

var _UI_manager: UIManager

func _ready() -> void:
	# The BV Startup function
	
	# Zeroth step is just to collect references and make connections
	_UI_manager = $UIManager
	FeagiCore.connection_state_changed.connect(_on_connection_state_change)
	
	# First step is to load configuration for FeagiCore
	FeagiCore.load_FEAGI_settings(FEAGI_configuration)
	
	# Define the network endpoint settings
	# NOTE: Right now we are loading a static file, we need to switch this to something more dynamic later
	FeagiCore.attempt_connection(default_FEAGI_network_settings)
	

func _on_connection_state_change(current_state: FeagiCore.CONNECTION_STATE, _prev_state: FeagiCore.CONNECTION_STATE) -> void:
	match(current_state):
		FeagiCore.CONNECTION_STATE.CONNECTED:
			# We are connected, get other important info
			FeagiCore.requests.get_burst_delay()
