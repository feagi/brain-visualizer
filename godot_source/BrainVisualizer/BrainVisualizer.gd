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
	# Force recompilation: v2 - check binary existence before choosing mode
	if FeagiModeDetector.is_embedded():
		# Desktop mode - check if FEAGI binary exists in exported app location
		# In exported apps, the binary won't exist, so use embedded extension
		var feagi_binary_path = ""
		if OS.has_feature("editor"):
			# Editor mode - check project path
			feagi_binary_path = ProjectSettings.globalize_path("res://../../feagi/target/release/feagi")
		else:
			# Exported app - check app bundle location
			var os_name = OS.get_name()
			if os_name == "macOS":
				feagi_binary_path = OS.get_executable_path().get_base_dir() + "/../Resources/bin/feagi"
			elif os_name == "Windows":
				feagi_binary_path = OS.get_executable_path().get_base_dir() + "/bin/feagi.exe"
			else:
				feagi_binary_path = OS.get_executable_path().get_base_dir() + "/bin/feagi"
		
		var feagi_binary_exists = FileAccess.file_exists(feagi_binary_path)
		print("   [DEBUG] FEAGI binary path: ", feagi_binary_path)
		print("   [DEBUG] FEAGI binary exists: ", feagi_binary_exists)
		
		if feagi_binary_exists:
			# FEAGI binary exists - use subprocess (editor mode or bundled binary)
			print("🦀 [BV] FEAGI binary found - launching FEAGI subprocess...")
			_initialize_feagi_subprocess()
		else:
			# No FEAGI binary - use embedded extension (exported app)
			print("🦀 [BV] No FEAGI binary found - initializing FEAGI embedded extension...")
			_initialize_feagi_embedded()
	else:
		# HTML5 or remote desktop mode
		print("🌐 [BV] Remote mode - connecting to external FEAGI...")
		# Try to grab the network settings from javascript, but manually define the network settings to use as fallback if the javascript fails
		FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
	
	# Any other connections
	FeagiCore.feagi_local_cache.amalgamation_pending.connect(_on_amalgamation_request)

## Poll embedded FEAGI logs every frame
## CRITICAL: This drains the log channel from worker threads
func _process(_delta: float) -> void:
	if _feagi_embedded:
		_feagi_embedded.poll_logs()

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

## Initialize FEAGI as a subprocess (desktop mode)
func _initialize_feagi_subprocess():
	print("🦀 [BV] Starting FEAGI subprocess...")
	
	# Show loading screen
	_UI_manager.update_loading_status("Starting FEAGI...")
	
	# Start FEAGI process
	var started = await FeagiProcessManager.start_feagi()
	
	if not started:
		push_error("Failed to start FEAGI subprocess")
		print("⚠️ [BV] FEAGI subprocess failed to start - falling back to remote mode...")
		_UI_manager.update_loading_status("Connecting to external FEAGI...")
		# In native apps, JavaScript integration doesn't work, so connect directly
		if OS.has_feature("web"):
			FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
		else:
			# Native app - connect directly to default endpoint
			FeagiCore.attempt_connection_to_FEAGI(default_FEAGI_network_settings)
		return
	
	print("✅ [BV] FEAGI subprocess started successfully!")
	print("   HTTP API: ", FeagiProcessManager.get_api_url())
	print("   WebSocket: ", FeagiProcessManager.get_websocket_url())
	print("   Swagger UI: http://127.0.0.1:8000/swagger-ui/")
	
	# Now connect to FEAGI normally (same as remote mode!)
	_UI_manager.update_loading_status("Connecting to FEAGI...")
	
	var api_url = FeagiProcessManager.get_api_url()
	var ws_url = FeagiProcessManager.get_websocket_url()
	var endpoint_details = FeagiEndpointDetails.create_from(api_url, ws_url)
	
	print("🔗 [BV] Connecting to FEAGI subprocess...")
	FeagiCore.attempt_connection_to_FEAGI(endpoint_details)

## Initialize FEAGI embedded extension (in-process mode)
## Used in exported apps where FEAGI binary is not bundled
func _initialize_feagi_embedded():
	print("🦀 [BV] Initializing FEAGI embedded extension...")
	
	# Show loading screen
	_UI_manager.update_loading_status("Initializing FEAGI...")
	
	# Check if extension is available
	if not ClassDB.class_exists("FeagiEmbedded"):
		push_error("FeagiEmbedded extension not available!")
		_UI_manager.update_loading_status("FEAGI extension not available - connect to external FEAGI...")
		# Fall back to remote mode
		if OS.has_feature("web"):
			FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
		else:
			FeagiCore.attempt_connection_to_FEAGI(default_FEAGI_network_settings)
		return
	
	# Instantiate embedded FEAGI
	_feagi_embedded = ClassDB.instantiate("FeagiEmbedded")
	if not _feagi_embedded:
		push_error("Failed to instantiate FeagiEmbedded")
		_UI_manager.update_loading_status("Failed to initialize FEAGI - connect to external FEAGI...")
		if OS.has_feature("web"):
			FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
		else:
			FeagiCore.attempt_connection_to_FEAGI(default_FEAGI_network_settings)
		return
	
	_UI_manager.update_loading_status("Starting FEAGI...")
	
	# Initialize with default settings
	print("   [DEBUG] Calling initialize_default()...")
	var init_success = _feagi_embedded.initialize_default()
	print("   [DEBUG] initialize_default() returned: ", init_success)
	if not init_success:
		push_error("Failed to initialize embedded FEAGI")
		_UI_manager.update_loading_status("FEAGI initialization failed - connect to external FEAGI...")
		if OS.has_feature("web"):
			FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
		else:
			FeagiCore.attempt_connection_to_FEAGI(default_FEAGI_network_settings)
		return
	
	# Start FEAGI
	print("   [DEBUG] Calling start()...")
	var start_success = _feagi_embedded.start()
	print("   [DEBUG] start() returned: ", start_success)
	if not start_success:
		push_error("Failed to start embedded FEAGI")
		_UI_manager.update_loading_status("FEAGI failed to start - connect to external FEAGI...")
		if OS.has_feature("web"):
			FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
		else:
			FeagiCore.attempt_connection_to_FEAGI(default_FEAGI_network_settings)
		return
	
	print("✅ [BV] FEAGI embedded extension initialized and started!")
	var api_url = _feagi_embedded.get_api_url()
	print("   HTTP API: ", api_url)
	print("   WebSocket: ws://127.0.0.1:9050")
	
	# Wait for HTTP server to be ready before connecting
	_UI_manager.update_loading_status("Waiting for FEAGI HTTP server...")
	var http_ready = await _wait_for_embedded_http_ready(api_url)
	if not http_ready:
		push_error("FEAGI HTTP server not ready - falling back to remote connection")
		_UI_manager.update_loading_status("FEAGI HTTP server timeout - connect to external FEAGI...")
		if OS.has_feature("web"):
			FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
		else:
			FeagiCore.attempt_connection_to_FEAGI(default_FEAGI_network_settings)
		return
	
	# Now connect to FEAGI via HTTP/WebSocket (same as remote mode)
	_UI_manager.update_loading_status("Connecting to FEAGI...")
	
	var endpoint_details = FeagiEndpointDetails.create_from(api_url, "ws://127.0.0.1:9050")
	print("🔗 [BV] Connecting to embedded FEAGI...")
	FeagiCore.attempt_connection_to_FEAGI(endpoint_details)

## Wait for embedded FEAGI HTTP server to be ready
func _wait_for_embedded_http_ready(api_url: String) -> bool:
	var http = HTTPRequest.new()
	add_child(http)
	
	var health_url = api_url + "/v1/system/health_check"
	var attempts = 0
	var max_attempts = 20  # 10 seconds (poll every 500ms)
	
	while attempts < max_attempts:
		# Try health check directly
		var error = http.request(health_url)
		if error == OK:
			var result = await http.request_completed
			var response_code = result[1]
			
			if response_code == 200:
				print("   ✅ FEAGI HTTP server is ready (attempt ", attempts + 1, ")")
				http.queue_free()
				return true
		
		# Wait before retry
		await get_tree().create_timer(0.5).timeout
		attempts += 1
		
		if attempts % 4 == 0:  # Every 2 seconds
			print("   ⏳ Still waiting for HTTP server... (", attempts / 2, "s elapsed)")
	
	http.queue_free()
	print("   ❌ FEAGI HTTP server not ready after timeout")
	return false
