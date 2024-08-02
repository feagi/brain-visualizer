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
	FeagiCore.genome_load_state_changed.connect(_on_genome_state_change)
	#FeagiCore.about_to_reload_genome.connect(_on_genome_reloading)
	
	# First step is to load configuration for FeagiCore
	FeagiCore.load_FEAGI_settings(FEAGI_configuration)
	
	# Try to grab the network settings from javascript, but manually define the network settings to use as fallback if the javascript fails
	FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
	
	# Any other connections
	FeagiCore.feagi_local_cache.amalgamation_pending.connect(_on_amalgamation_request)

func _on_genome_reloading() -> void:
	_UI_manager.FEAGI_about_to_reset_genome()

func _on_genome_state_change(current_state: FeagiCore.GENOME_LOAD_STATE, prev_state: FeagiCore.GENOME_LOAD_STATE) -> void:
	match(current_state):
		FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
			# Connected and ready to go
			_UI_manager.FEAGI_confirmed_genome()
			if !FeagiCore.about_to_reload_genome.is_connected(_on_genome_reloading):
				FeagiCore.about_to_reload_genome.connect(_on_genome_reloading)
		_:
			if prev_state == FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
				# had genome but now dont
				_UI_manager.FEAGI_no_genome()

func _on_amalgamation_request(amalgamation_id: StringName, genome_title: StringName, dimensions: Vector3i) -> void:
	_UI_manager.window_manager.spawn_amalgamation_window(amalgamation_id, genome_title, dimensions)

