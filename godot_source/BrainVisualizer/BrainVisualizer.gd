extends Node
class_name BrainVisualizer
## The root node, while this doesnt handle UI directly, it does handle some of the coordination with FeagiCore

@export var FEAGI_configuration: FeagiGeneralSettings
@export var default_FEAGI_network_settings: FeagiEndpointDetails

var UI_manager: UIManager:
	get: return _UI_manager

var _UI_manager: UIManager
var _feagi_embedded = null  # Holds FeagiEmbedded instance (RefCounted)
var _feagi_wasm_manager: FeagiWasmManager = null  # Holds FeagiWasmManager instance (web builds)

#NOTE: This is where it all starts, if you wish to see how BV connects to FEAGI, start here
func _ready() -> void:
	
	# Zeroth step is just to collect references and make connections
	_UI_manager = $UIManager
	FeagiCore.genome_load_state_changed.connect(_on_genome_state_change)
	FeagiCore.about_to_reload_genome.connect(_on_genome_reloading)
	
	# Register UIManager with ShutdownManager for shutdown screen
	ShutdownManager.register_ui_manager(_UI_manager)
	
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
		if OS.has_feature("web"):
			# Web build - check if we should use standalone WASM mode
			_initialize_feagi_wasm()
			
			# Check URL parameter to see if we should skip remote FEAGI
			var standalone_mode = JavaScriptIntegrations.get_url_parameter("standalone")
			if standalone_mode == "true" or standalone_mode == "1":
				print("🌐 [BV] Standalone WASM mode - skipping remote FEAGI connection")
				# Try to auto-load genome from same directory
				_try_auto_load_genome_from_directory()
				return
			
			# Check if launched from FEAGI Desktop - use environment variables if available
			var launched_from_desktop = OS.get_environment("LAUNCHED_FROM_FEAGI_DESKTOP").to_lower()
			if launched_from_desktop == "true":
				# Use environment variables set by feagi-desktop
				var api_url = OS.get_environment("FEAGI_API_URL")
				if api_url.is_empty():
					api_url = "http://127.0.0.1:8000"
				
				var ws_host = OS.get_environment("FEAGI_WS_HOST")
				if ws_host.is_empty():
					ws_host = "127.0.0.1"
				
				var ws_port_str = OS.get_environment("FEAGI_WS_PORT")
				var ws_port = int(ws_port_str) if ws_port_str else 9050
				var ws_url = "ws://%s:%d" % [ws_host, ws_port]
				
				print("   [BV] Using FEAGI Desktop environment variables:")
				print("   [BV]   API URL: %s" % api_url)
				print("   [BV]   WebSocket: %s" % ws_url)
				
				var endpoint_details = FeagiEndpointDetails.create_from(api_url, ws_url)
				FeagiCore.attempt_connection_to_FEAGI(endpoint_details)
			else:
				# Web build - try JavaScript first, fallback to defaults
				# But also allow standalone mode if no FEAGI URL is provided
				var feagi_url = JavaScriptIntegrations.get_url_parameter("feagi_url")
				var ip_address = JavaScriptIntegrations.get_url_parameter("ip_address")
				if (feagi_url == null or feagi_url == "") and (ip_address == null or ip_address == ""):
					print("🌐 [BV] No FEAGI URL provided - using standalone WASM mode")
					print("🌐 [BV] To connect to remote FEAGI, add ?feagi_url=... or ?ip_address=... to URL")
					# Try to auto-load genome from same directory
					_try_auto_load_genome_from_directory()
				else:
					FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
		else:
			# Desktop remote mode
			print("🌐 [BV] Remote mode - connecting to external FEAGI...")
			# Check if launched from FEAGI Desktop - use environment variables if available
			var launched_from_desktop = OS.get_environment("LAUNCHED_FROM_FEAGI_DESKTOP").to_lower()
			if launched_from_desktop == "true":
				# Use environment variables set by feagi-desktop
				var api_url = OS.get_environment("FEAGI_API_URL")
				if api_url.is_empty():
					api_url = "http://127.0.0.1:8000"
				
				var ws_host = OS.get_environment("FEAGI_WS_HOST")
				if ws_host.is_empty():
					ws_host = "127.0.0.1"
				
				var ws_port_str = OS.get_environment("FEAGI_WS_PORT")
				var ws_port = int(ws_port_str) if ws_port_str else 9050
				var ws_url = "ws://%s:%d" % [ws_host, ws_port]
				
				print("   [BV] Using FEAGI Desktop environment variables:")
				print("   [BV]   API URL: %s" % api_url)
				print("   [BV]   WebSocket: %s" % ws_url)
				
				var endpoint_details = FeagiEndpointDetails.create_from(api_url, ws_url)
				FeagiCore.attempt_connection_to_FEAGI(endpoint_details)
			else:
				# Desktop remote mode - try JavaScript first, fallback to defaults
				FeagiCore.attempt_connection_to_FEAGI_via_javascript_details(default_FEAGI_network_settings)
	
	# Any other connections
	FeagiCore.feagi_local_cache.amalgamation_pending.connect(_on_amalgamation_request)

## Poll embedded FEAGI logs every frame
## CRITICAL: This drains the log channel from worker threads
func _process(_delta: float) -> void:
	if _feagi_embedded:
		_feagi_embedded.poll_logs()

## Handle window close request
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Block the quit until shutdown completes
		get_tree().set_auto_accept_quit(false)
		
		# Start async shutdown sequence
		_perform_shutdown_async()

## Perform async shutdown with UI updates
func _perform_shutdown_async() -> void:
	# Delegate to ShutdownManager for graceful shutdown with UI
	await ShutdownManager.request_shutdown_async()
	
	# Now allow quit
	print("🛑 [BV] Shutdown complete - quitting app")
	get_tree().quit()

## Cleanup when exiting (emergency fallback)
func _exit_tree() -> void:
	# Last chance cleanup (shouldn't need this if _notification worked)
	# Use synchronous version since _exit_tree doesn't support await
	ShutdownManager.request_shutdown()

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

## Phase 4: Initialize FEAGI WASM engine for web builds
func _initialize_feagi_wasm() -> void:
	"""Initialize FEAGI WASM engine for web platform"""
	_feagi_wasm_manager = FeagiWasmManager.new()
	add_child(_feagi_wasm_manager)
	
	# Connect signals
	_feagi_wasm_manager.genome_loaded.connect(_on_wasm_genome_loaded)
	_feagi_wasm_manager.burst_processed.connect(_on_wasm_burst_processed)
	_feagi_wasm_manager.error_occurred.connect(_on_wasm_error_occurred)
	_feagi_wasm_manager.storage_initialized.connect(_on_wasm_storage_initialized)
	_feagi_wasm_manager.genome_saved.connect(_on_wasm_genome_saved)
	
	print("✅ FEAGI WASM manager initialized")

func _on_wasm_genome_loaded() -> void:
	"""Handle genome loaded event from WASM engine"""
	print("✅ [BV] WASM genome loaded")
	# Notify UI manager (similar to FeagiCore genome ready)
	_UI_manager.FEAGI_confirmed_genome()

func _on_wasm_burst_processed(result: Dictionary) -> void:
	"""Handle burst processed event from WASM engine"""
	if result.has("fired_neurons"):
		# Convert fired neurons to visualization format
		# This will need to integrate with existing visualization system
		print("📊 [BV] Burst processed: ", result.get("neuron_count", 0), " neurons fired")
		# TODO: Update visualization with fired neurons

func _on_wasm_error_occurred(error: String) -> void:
	"""Handle error from WASM engine"""
	push_error("FEAGI WASM error: " + error)
	StatusReporter.report_error("FEAGI WASM: " + error)

func _on_wasm_storage_initialized() -> void:
	"""Handle storage initialization"""
	print("✅ [BV] WASM storage initialized")

func _on_wasm_genome_saved(genome_id: String) -> void:
	"""Handle genome saved event"""
	print("✅ [BV] Genome saved to storage: ", genome_id)

## Load genome from file (for web builds, uses WASM engine)
func load_genome_from_file(path: String) -> void:
	"""Load genome from file path"""
	if OS.has_feature("web"):
		# Web build - use HTTP fetch (file must be in same directory or subdirectory)
		if _feagi_wasm_manager == null:
			_initialize_feagi_wasm()
			await get_tree().process_frame
		
		if _feagi_wasm_manager != null:
			_load_genome_via_file_api(path)
		else:
			push_error("FEAGI WASM manager not initialized")
	else:
		# Desktop build - use file system directly
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var genome_json = file.get_as_text()
			file.close()
			# Desktop build - use existing FEAGI (embedded or remote)
			# TODO: Integrate with existing genome loading mechanism
			push_warning("Genome loading from file not yet integrated for desktop mode")

## Load genome using HTTP fetch (web builds only)
func _load_genome_via_file_api(filename: String) -> void:
	"""Load genome file using HTTP fetch (file must be accessible via HTTP)"""
	if not OS.has_feature("web") or _feagi_wasm_manager == null:
		push_error("File loading only available on web builds with WASM")
		return
	
	# Trigger async load
	JavaScriptIntegrations.load_file_via_http(filename)
	
	# Wait for load to complete
	var genome_json = await _load_file_async(filename)
	if genome_json != null and genome_json != "":
		_feagi_wasm_manager.load_genome_from_json(genome_json)
	else:
		push_error("Failed to load genome file: " + filename)

## Try to auto-load genome from same directory (web builds)
func _try_auto_load_genome_from_directory() -> void:
	"""Try to find and load genome files in the same directory"""
	if not OS.has_feature("web"):
		return
	
	# Ensure WASM manager is initialized
	if _feagi_wasm_manager == null:
		_initialize_feagi_wasm()
		# Wait a frame for initialization
		await get_tree().process_frame
	
	if _feagi_wasm_manager == null:
		push_error("Failed to initialize FEAGI WASM manager")
		return
	
	# Check for common genome file names
	var genome_files = ["genome.json", "brain.json", "connectome.json"]
	for filename in genome_files:
		print("🔍 [BV] Checking for genome file: " + filename)
		var genome_json = await _load_file_async(filename)
		if genome_json != null and genome_json != "":
			print("✅ [BV] Auto-loaded genome from: " + filename)
			_feagi_wasm_manager.load_genome_from_json(genome_json)
			return
	
	print("ℹ️ [BV] No genome file found in directory - use 'Load Genome' button to load manually")

## Load file asynchronously via HTTP
func _load_file_async(filename: String) -> String:
	"""Load file asynchronously and return contents"""
	if not OS.has_feature("web"):
		return ""
	
	# Trigger async load
	JavaScriptIntegrations.load_file_via_http(filename)
	
	# Poll for result (non-blocking)
	var max_attempts = 50  # 5 seconds max
	for i in range(max_attempts):
		var result = JavaScriptIntegrations.poll_file_load_result()
		if result != "":
			return result
		await get_tree().process_frame
	
	return ""

## Show file picker for genome loading (web builds)
func show_genome_file_picker() -> void:
	"""Show HTML5 file picker for genome loading"""
	if not OS.has_feature("web") or _feagi_wasm_manager == null:
		push_error("File picker only available on web builds with WASM")
		return
	
	JavaScriptIntegrations.show_file_picker_for_genome(self, "_on_genome_file_selected")
	# Poll for result in next frame
	_check_file_picker_result()

func _check_file_picker_result() -> void:
	"""Poll for file picker result"""
	var result = JavaScriptIntegrations.poll_file_picker_result()
	if result != "":
		_on_genome_file_selected(result)
	elif result == "":
		# Still waiting or cancelled - check again next frame
		await get_tree().process_frame
		_check_file_picker_result()

func _on_genome_file_selected(genome_json: String) -> void:
	"""Callback when genome file is selected via file picker"""
	if genome_json != null and genome_json != "":
		_feagi_wasm_manager.load_genome_from_json(genome_json)
	else:
		push_error("Failed to load genome file")

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
	
	# Register with ShutdownManager for cleanup
	ShutdownManager.register_embedded_instance(_feagi_embedded)
	
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
