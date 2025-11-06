extends Node
class_name BrainVisualizer
## The root node, while this doesnt handle UI directly, it does handle some of the coordination with FeagiCore

@export var FEAGI_configuration: FeagiGeneralSettings
@export var default_FEAGI_network_settings: FeagiEndpointDetails

var UI_manager: UIManager:
	get: return _UI_manager

var _UI_manager: UIManager
var _feagi_embedded = null  # Holds FeagiEmbedded instance (RefCounted)

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
		print("🦀 [BV] Desktop mode detected - launching embedded FEAGI (PHASE 1 TEST)...")
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
	
	# Create embedded FEAGI instance (RefCounted - don't add to tree)
	_feagi_embedded = ClassDB.instantiate("FeagiEmbedded")
	if not _feagi_embedded:
		push_error("Failed to instantiate FeagiEmbedded")
		print("⚠️ [BV] Falling back to remote mode...")
		_UI_manager.update_loading_status("Failed to create FEAGI instance - using remote mode...")
		FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
		return
	
	# Initialize FEAGI
	print("🦀 [BV] Initializing FEAGI components (this may take a few seconds)...")
	_UI_manager.update_loading_status("Initializing FEAGI components...")
	
	if not _feagi_embedded.initialize_default():
		push_error("Failed to initialize embedded FEAGI")
		print("⚠️ [BV] Falling back to remote mode...")
		_UI_manager.update_loading_status("FEAGI initialization failed - using remote mode...")
		_feagi_embedded = null  # Release reference
		FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
		return
	
	print("✅ [BV] Embedded FEAGI initialized successfully!")
	print("   HTTP API: ", _feagi_embedded.get_api_url())
	
	# Start burst engine
	print("🦀 [BV] Starting burst engine...")
	_UI_manager.update_loading_status("Starting FEAGI burst engine...")
	
	if _feagi_embedded.start():
		print("✅ [BV] Burst engine started!")
		_UI_manager.update_loading_status("FEAGI started successfully!")
	else:
		push_warning("Burst engine did not start (this is OK if no genome loaded yet)")
	
	# Wait for HTTP server to bind (async spawn needs a moment)
	# CRITICAL: Give HTTP server more time to fully initialize and accept connections
	_UI_manager.update_loading_status("Waiting for FEAGI HTTP server...")
	await get_tree().create_timer(2.0).timeout  # 2 seconds for server to fully bind and be ready
	print("⏱️ [BV] HTTP server wait complete - attempting connection...")
	
	# Store reference for FeagiCore
	if "embedded_feagi_instance" in FeagiCore:
		FeagiCore.embedded_feagi_instance = _feagi_embedded
	
	# Update loading status
	_UI_manager.update_loading_status("Connecting to embedded FEAGI...")
	
	print("✅ [BV] Embedded FEAGI fully initialized and ready")
	print("   Mode: In-process (no WebSocket connection needed)")
	print("   HTTP API: ", _feagi_embedded.get_api_url())
	print("   Swagger UI: http://127.0.0.1:8000/swagger-ui/")
	print("   Use HTTP API for genome operations, FFI for real-time control")
	
	# Create endpoint details for embedded FEAGI
	var api_url = _feagi_embedded.get_api_url()  # e.g. "http://127.0.0.1:8000"
	var ws_url = "ws://127.0.0.1:9050"  # WebSocket (may not be used in embedded mode)
	var endpoint_details = FeagiEndpointDetails.create_from(api_url, ws_url)
	
	# CRITICAL: We MUST call this even in embedded mode to:
	# 1. Perform initial health check (/v1/system/health_check)
	# 2. Discover if genome is loaded
	# 3. Trigger genome download if available
	# 4. Set genome_load_state to GENOME_READY (enables 3D scene)
	# The WebSocket will be skipped automatically since we're using HTTP transport
	print("🔗 [BV] Initiating HTTP connection to embedded FEAGI...")
	FeagiCore.attempt_connection_to_FEAGI(endpoint_details)
