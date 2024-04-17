extends Node
class_name BrainVisualizer
## The root node, while this doesnt handle UI directly, it does handle some of the coordination with FeagiCore

@export var FEAGI_configuration: FeagiGeneralSettings
@export var default_FEAGI_network_settings: FeagiEndpointDetails

var UI_manager: UIManager:
	get: return _UI_manager

var _UI_manager: UIManager

#NOTE: This is where it all starts, if you wish to see how BV connects to FEAGI, start here
func _ready() -> void:
	
	# Zeroth step is just to collect references and make connections
	_UI_manager = $UIManager
	FeagiCore.connection_state_changed.connect(_on_connection_state_change)
	FeagiCore.genome_load_state_changed.connect(_on_genome_state_change)
	FeagiCore.about_to_reload_genome.connect(_on_genome_reloading)
	
	# First step is to load configuration for FeagiCore
	FeagiCore.load_FEAGI_settings(FEAGI_configuration)
	
	# Try to grab the network settings from javascript, but manually define the network settings to use as fallback if the javascript fails
	FeagiCore.attempt_connection_via_javascript_details(default_FEAGI_network_settings)
	

func _on_connection_state_change(current_state: FeagiCore.CONNECTION_STATE, prev_state: FeagiCore.CONNECTION_STATE) -> void:
	match(current_state):
		FeagiCore.CONNECTION_STATE.CONNECTED:
			# We are connected
			pass
		FeagiCore.CONNECTION_STATE.DISCONNECTED:
			if prev_state == FeagiCore.CONNECTION_STATE.CONNECTED:
				var tell_user: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("Connection Lost!", "Connection to FEAGI has been lost!")
				_UI_manager.window_manager.spawn_popup(tell_user)

func _on_genome_reloading() -> void:
	_UI_manager.FEAGI_about_to_reset_genome()

func _on_genome_state_change(current_state: FeagiCore.GENOME_LOAD_STATE, prev_state: FeagiCore.GENOME_LOAD_STATE) -> void:
	match(current_state):
		FeagiCore.GENOME_LOAD_STATE.GENOME_LOADED_LOCALLY:
			# Connected and ready to go
			_UI_manager.FEAGI_confirmed_genome()
		_:
			if prev_state == FeagiCore.GENOME_LOAD_STATE.GENOME_LOADED_LOCALLY:
				# had genome but now dont
				_UI_manager.FEAGI_no_genome()
				
