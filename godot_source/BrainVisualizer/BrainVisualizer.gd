extends Node
class_name BrainVisualizer
## The root node, while this doesnt handle UI directly, it does handle some of the coordination with FeagiCore

@export var FEAGI_configuration: FeagiGeneralSettings
@export var default_FEAGI_network_settings: FeagiEndpointDetails

func _ready() -> void:
	# The BV Startup function
	
	# First step is to load configuration for FeagiCore
	FeagiCore.load_FEAGI_settings(FEAGI_configuration)
	
	# Define the network endpoint settings
	# NOTE: Right now we are loading a static file, we need to switch this to something more dynamic later
	FeagiCore.attempt_connection(default_FEAGI_network_settings)
