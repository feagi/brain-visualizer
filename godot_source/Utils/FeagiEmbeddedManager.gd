extends Node
class_name FeagiEmbeddedManager
## Manages FEAGI connection - automatically chooses embedded or external mode
##
## This manager provides a unified interface for FEAGI regardless of connection mode:
## - EMBEDDED: FEAGI runs in-process (desktop only, microsecond latency)
## - EXTERNAL: FEAGI runs as separate server (any platform, network communication)
##
## BV code doesn't need to know which mode is active - the manager handles it.

signal feagi_initialized(success: bool)
signal feagi_started(success: bool)
signal genome_loaded(success: bool)
signal connection_status_changed(connected: bool)

enum FeagiMode {
	EMBEDDED,    ## Using native Rust extension (desktop-only, in-process)
	EXTERNAL,    ## Using separate FEAGI server (any platform, network)
	DISABLED     ## No FEAGI available
}

var feagi_mode: FeagiMode = FeagiMode.DISABLED
var feagi_instance: Object = null  ## FeagiEmbedded instance (if embedded mode)
var api_url: String = ""
var ws_viz_port: int = 9050

## User preference (can be set via settings UI)
var prefer_embedded: bool = true  ## Default to embedded if available

func _ready():
	detect_feagi_mode()

## Detect and select FEAGI mode based on platform and availability
func detect_feagi_mode():
	print("\n🔍 [FEAGI-MGR] Detecting FEAGI mode...")
	
	# Check if running on desktop (embedded FEAGI only works on desktop)
	if not OS.has_feature("desktop"):
		print("   Platform: ", OS.get_name(), " (non-desktop)")
		print("   → Using EXTERNAL mode (embedded not available)")
		feagi_mode = FeagiMode.EXTERNAL
		return
	
	# Check if embedded extension is available
	if ClassDB.class_exists("FeagiEmbedded"):
		print("   ✅ FeagiEmbedded extension found!")
		
		# Check user preference
		if prefer_embedded:
			print("   → Using EMBEDDED mode (in-process, microsecond latency)")
			feagi_mode = FeagiMode.EMBEDDED
		else:
			print("   → Using EXTERNAL mode (user preference)")
			feagi_mode = FeagiMode.EXTERNAL
	else:
		print("   ⚠️  FeagiEmbedded extension not found")
		print("   → Using EXTERNAL mode")
		feagi_mode = FeagiMode.EXTERNAL
	
	# Check for environment variable override
	var env_mode = OS.get_environment("FEAGI_MODE")
	if env_mode == "external":
		print("   🔧 Environment override: FEAGI_MODE=external")
		feagi_mode = FeagiMode.EXTERNAL

## Initialize FEAGI (either embedded or configure external connection)
func initialize_feagi(config_path: String = "") -> bool:
	print("\n🚀 [FEAGI-MGR] Initializing FEAGI...")
	
	match feagi_mode:
		FeagiMode.EMBEDDED:
			return _initialize_embedded(config_path)
		FeagiMode.EXTERNAL:
			return _initialize_external()
		_:
			push_error("No FEAGI mode available")
			return false

## Initialize embedded FEAGI (in-process)
func _initialize_embedded(config_path: String) -> bool:
	print("   Mode: EMBEDDED (in-process)")
	
	feagi_instance = ClassDB.instantiate("FeagiEmbedded")
	if not feagi_instance:
		push_error("Failed to instantiate FeagiEmbedded")
		return false
	
	var success: bool = false
	if config_path.is_empty():
		# Use embedded defaults
		print("   Using embedded defaults (API: :8000, WebSocket: :9050)")
		success = feagi_instance.initialize_default()
	else:
		# Load from config file
		print("   Loading config: ", config_path)
		success = feagi_instance.initialize_from_config(config_path)
	
	if success:
		api_url = feagi_instance.get_api_url()
		print("   ✅ FEAGI initialized!")
		print("   HTTP API: ", api_url)
		print("   Mode: Hybrid (FFI for hot-path, HTTP for complex ops)")
	else:
		push_error("Failed to initialize embedded FEAGI")
	
	feagi_initialized.emit(success)
	return success

## Configure external FEAGI connection
func _initialize_external() -> bool:
	print("   Mode: EXTERNAL (network)")
	
	# Read from environment or use defaults
	api_url = OS.get_environment("FEAGI_API_URL")
	if api_url.is_empty():
		api_url = "http://127.0.0.1:8000"
	
	var ws_host = OS.get_environment("FEAGI_WS_HOST")
	if not ws_host.is_empty() and ":" in ws_host:
		ws_viz_port = int(ws_host.get_slice(":", 1))
	else:
		ws_viz_port = 9050
	
	print("   HTTP API: ", api_url)
	print("   WebSocket Viz: ws://127.0.0.1:", ws_viz_port)
	print("   Note: External FEAGI must be running separately")
	
	feagi_initialized.emit(true)
	return true

## Start FEAGI services
func start_feagi() -> bool:
	if feagi_mode == FeagiMode.EMBEDDED:
		if not feagi_instance:
			push_error("FEAGI instance not initialized")
			return false
		
		print("\n▶️  [FEAGI-MGR] Starting burst engine...")
		var success = feagi_instance.start()
		if success:
			print("   ✅ Burst engine started!")
		else:
			push_error("Failed to start burst engine")
		
		feagi_started.emit(success)
		return success
	else:
		# External mode - assume already running
		print("\n▶️  [FEAGI-MGR] Using external FEAGI (assumed running)")
		feagi_started.emit(true)
		return true

## Stop FEAGI services
func stop_feagi() -> bool:
	if feagi_mode == FeagiMode.EMBEDDED and feagi_instance:
		print("\n⏸️  [FEAGI-MGR] Stopping burst engine...")
		var success = feagi_instance.stop()
		if success:
			print("   ✅ Burst engine stopped")
		return success
	return true

## Set burst frequency (Hz)
func set_burst_frequency(hz: float) -> bool:
	if feagi_mode == FeagiMode.EMBEDDED and feagi_instance:
		# HOT PATH: Direct FFI call (~1μs)
		return feagi_instance.set_burst_frequency(hz)
	else:
		# COLD PATH: HTTP API call (~1-5ms)
		return _set_burst_frequency_via_http(hz)

## Load a genome file
func load_genome(genome_path: String) -> bool:
	# Both modes use HTTP API for genome loading (complex operation)
	print("\n🧠 [FEAGI-MGR] Loading genome: ", genome_path)
	return _load_genome_via_http(genome_path)

## Check if FEAGI is running
func is_running() -> bool:
	if feagi_mode == FeagiMode.EMBEDDED and feagi_instance:
		# HOT PATH: Direct FFI (~100ns)
		return feagi_instance.is_running()
	else:
		# COLD PATH: Would need HTTP health check
		return true  # Simplified for now

## Get neuron count
func get_neuron_count() -> int:
	if feagi_mode == FeagiMode.EMBEDDED and feagi_instance:
		# HOT PATH: Direct FFI (~10μs)
		return feagi_instance.get_neuron_count()
	else:
		# COLD PATH: HTTP API call
		return _get_neuron_count_via_http()

## Check if genome is loaded
func is_genome_loaded() -> bool:
	if feagi_mode == FeagiMode.EMBEDDED and feagi_instance:
		# HOT PATH: Direct FFI (~100ns)
		return feagi_instance.is_genome_loaded()
	else:
		# COLD PATH: HTTP API call
		return _is_genome_loaded_via_http()

## Get the HTTP API base URL (works for both modes)
func get_api_url() -> String:
	return api_url

## Get the WebSocket visualization port
func get_websocket_viz_port() -> int:
	return ws_viz_port

## Get current FEAGI mode
func get_mode() -> FeagiMode:
	return feagi_mode

## Get mode as string
func get_mode_string() -> String:
	match feagi_mode:
		FeagiMode.EMBEDDED:
			return "EMBEDDED"
		FeagiMode.EXTERNAL:
			return "EXTERNAL"
		_:
			return "DISABLED"

## Shutdown FEAGI gracefully
func shutdown():
	print("\n🛑 [FEAGI-MGR] Shutting down...")
	
	if feagi_mode == FeagiMode.EMBEDDED and feagi_instance:
		feagi_instance.shutdown()
		feagi_instance = null
		print("   ✅ Embedded FEAGI shutdown complete")
	
	print("   [FEAGI-MGR] Shutdown complete")

#
# ============ PRIVATE HTTP API HELPERS (for external mode) ============
#

func _set_burst_frequency_via_http(hz: float) -> bool:
	# TODO: Implement HTTP POST to /v1/runtime/burst_frequency
	print("   [TODO] Set burst frequency via HTTP: ", hz)
	return true

func _load_genome_via_http(genome_path: String) -> bool:
	# TODO: Implement HTTP POST to /v1/genome/load
	print("   [TODO] Load genome via HTTP: ", genome_path)
	# This would use HTTPRequest to post to the API
	return true

func _get_neuron_count_via_http() -> int:
	# TODO: Implement HTTP GET from /v1/analytics/neuron_count
	return 0

func _is_genome_loaded_via_http() -> bool:
	# TODO: Implement HTTP GET from /v1/system/health_check
	return false

#
# ============ CLEANUP ============
#

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		shutdown()

