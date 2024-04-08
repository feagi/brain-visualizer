extends Node
class_name BrainVisualizer
## The root node, while this doesnt handle UI directly, it does handle some of the coordination with FeagiCore

@export var FEAGI_configuration: FeagiGeneralSettings
@export var default_FEAGI_network_settings: FeagiEndpointDetails

var top_bar: TopBar:
	get: return _top_bar
var notification_system:
	get: return _notification_system

var _top_bar: TopBar
var _notification_system: NotificationSystem


func _ready() -> void:
	# The BV Startup function
	
	# Zeroth step is just to collect references and make connections
	_top_bar = $TopBar
	_notification_system = $NotificationSystem
	_top_bar.resized.connect(_top_bar_resized)
	_top_bar_resized()
	
	# First step is to load configuration for FeagiCore
	FeagiCore.load_FEAGI_settings(FEAGI_configuration)
	
	# Define the network endpoint settings
	# NOTE: Right now we are loading a static file, we need to switch this to something more dynamic later
	FeagiCore.attempt_connection(default_FEAGI_network_settings)



## Used to reposition notifications so they dont intersect with top bar
func _top_bar_resized() -> void:
	_notification_system.position.y = _top_bar.size.y + _top_bar.position.y
