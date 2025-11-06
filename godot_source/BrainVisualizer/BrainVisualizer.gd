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
	FeagiCore.about_to_reload_genome.connect(_on_genome_reloading)
	
	# First step is to load configuration for FeagiCore
	FeagiCore.load_FEAGI_settings(FEAGI_configuration)
	
	# NEW: Check runtime mode and initialize accordingly
	if FeagiModeDetector.is_embedded():
		# Desktop with embedded FEAGI extension
		print("🦀 [BV] Desktop mode detected - launching embedded FEAGI...")
		_initialize_embedded_feagi()
	else:
		# HTML5 or desktop remote mode (existing behavior)
		print("🌐 [BV] Remote mode - connecting to external FEAGI...")
		# Try to grab the network settings from javascript, but manually define the network settings to use as fallback if the javascript fails
		FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
	
	# Any other connections
	FeagiCore.feagi_local_cache.amalgamation_pending.connect(_on_amalgamation_request)

func _on_genome_reloading() -> void:
	_UI_manager.FEAGI_about_to_reset_genome()

func _on_genome_state_change(current_state: FeagiCore.GENOME_LOAD_STATE, prev_state: FeagiCore.GENOME_LOAD_STATE) -> void:
	print("BRAINVISUALIZER: [3D_SCENE_DEBUG] Received genome state change: ", FeagiCore.GENOME_LOAD_STATE.keys()[prev_state], " -> ", FeagiCore.GENOME_LOAD_STATE.keys()[current_state])
	
	match(current_state):
		FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
			# Connected and ready to go
			print("BRAINVISUALIZER: [3D_SCENE_DEBUG] ✅ GENOME_READY received - calling UI manager to initialize 3D scene")
			_UI_manager.FEAGI_confirmed_genome()
			if !FeagiCore.about_to_reload_genome.is_connected(_on_genome_reloading):
				FeagiCore.about_to_reload_genome.connect(_on_genome_reloading)
		_:
			if prev_state == FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
				# had genome but now dont
				print("BRAINVISUALIZER: [3D_SCENE_DEBUG] ⚠️ Lost genome readiness - calling UI manager to disable 3D scene")
				_UI_manager.FEAGI_no_genome()

func _on_amalgamation_request(amalgamation_id: StringName, genome_title: StringName, dimensions: Vector3i) -> void:
	_UI_manager.window_manager.spawn_amalgamation_window(amalgamation_id, genome_title, dimensions)

## Initialize embedded FEAGI (desktop mode only)
func _initialize_embedded_feagi():
	print("🦀 [BV] Initializing embedded FEAGI...")
	
	# Show loading screen phase: "Starting FEAGI..."
	_UI_manager.update_loading_status("Starting FEAGI...")
	
	# Verify extension is available
	if not ClassDB.class_exists("FeagiEmbedded"):
		push_error("Embedded mode selected but FeagiEmbedded extension not found!")
		print("⚠️ [BV] Falling back to remote mode...")
		_UI_manager.update_loading_status("FEAGI embedded not available - using remote mode...")
		FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
		return
	
	# Create embedded FEAGI instance
	var feagi_embedded = ClassDB.instantiate("FeagiEmbedded")
	if not feagi_embedded:
		push_error("Failed to instantiate FeagiEmbedded")
		print("⚠️ [BV] Falling back to remote mode...")
		_UI_manager.update_loading_status("Failed to create FEAGI instance - using remote mode...")
		FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
		return
	
	add_child(feagi_embedded)
	feagi_embedded.name = "FeagiEmbedded"
	
	# Initialize FEAGI
	print("🦀 [BV] Initializing FEAGI components (this may take a few seconds)...")
	_UI_manager.update_loading_status("Initializing FEAGI components...")
	
	if not feagi_embedded.initialize_default():
		push_error("Failed to initialize embedded FEAGI")
		print("⚠️ [BV] Falling back to remote mode...")
		_UI_manager.update_loading_status("FEAGI initialization failed - using remote mode...")
		feagi_embedded.queue_free()
		FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
		return
	
	print("✅ [BV] Embedded FEAGI initialized successfully!")
	print("   HTTP API: ", feagi_embedded.get_api_url())
	
	# Start burst engine
	print("🦀 [BV] Starting burst engine...")
	_UI_manager.update_loading_status("Starting FEAGI burst engine...")
	
	if feagi_embedded.start():
		print("✅ [BV] Burst engine started!")
		_UI_manager.update_loading_status("FEAGI started successfully!")
	else:
		push_warning("Burst engine did not start (this is OK if no genome loaded yet)")
	
	# Wire embedded FEAGI to FeagiCore
	# FeagiCore will use HTTP API for complex operations (genome load, etc.)
	var api_url = feagi_embedded.get_api_url()
	var endpoint_details = FeagiEndpointDetails.new()
	endpoint_details.API_address = api_url
	endpoint_details.websocket_host = "127.0.0.1"
	endpoint_details.websocket_visualization_port = 9050
	
	# Store reference for Settings menu (if FeagiCore has this field)
	if "embedded_feagi_instance" in FeagiCore:
		FeagiCore.embedded_feagi_instance = feagi_embedded
	
	# Update loading status
	_UI_manager.update_loading_status("Connecting to embedded FEAGI...")
	
	# Continue with existing connection flow (for HTTP API and WebSocket)
	# This reuses all existing BV code!
	FeagiCore.attempt_connection_to_FEAGI(endpoint_details)
