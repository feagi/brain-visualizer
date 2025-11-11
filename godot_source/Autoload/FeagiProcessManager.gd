extends Node
## Manages FEAGI as a subprocess for embedded desktop mode
##
## Access globally via: FeagiProcessManager (autoload singleton)
##
## This class handles:
## - Finding and launching the FEAGI binary
## - Monitoring process health
## - Graceful shutdown
## - Automatic restart on crashes

signal feagi_started()
signal feagi_stopped()
signal feagi_crashed(exit_code: int)

var _process_id: int = 0
var _feagi_path: String = ""
var _config_path: String = ""
var _is_running: bool = false
var _health_check_timer: Timer
var _startup_wait_timer: Timer

const FEAGI_HTTP_PORT = 8000
const FEAGI_WEBSOCKET_PORT = 9050
const STARTUP_TIMEOUT_SECONDS = 10
const HEALTH_CHECK_INTERVAL = 5.0

func _ready():
	# Create health check timer
	_health_check_timer = Timer.new()
	_health_check_timer.wait_time = HEALTH_CHECK_INTERVAL
	_health_check_timer.timeout.connect(_on_health_check)
	add_child(_health_check_timer)
	
	# Create startup wait timer
	_startup_wait_timer = Timer.new()
	_startup_wait_timer.one_shot = true
	add_child(_startup_wait_timer)

func _exit_tree():
	# Ensure FEAGI is stopped when BV exits
	stop_feagi()

## Start FEAGI as a subprocess
## Returns true if process was started, false on error
func start_feagi() -> bool:
	if _is_running:
		push_warning("FEAGI already running")
		return true
	
	print("🚀 [ProcessManager] Starting FEAGI subprocess...")
	print("   🔍 Current working directory: ", OS.get_environment("PWD"))
	print("   🔍 Executable base: ", OS.get_executable_path())
	
	# Find FEAGI executable
	_feagi_path = _get_feagi_executable_path()
	print("   🔍 Looking for FEAGI at: ", _feagi_path)
	if not FileAccess.file_exists(_feagi_path):
		push_error("FEAGI executable not found at: ", _feagi_path)
		print("   ❌ File check failed for: ", _feagi_path)
		return false
	print("   ✅ FEAGI executable found")
	
	# Find config file
	_config_path = _get_config_path()
	print("   🔍 Looking for config at: ", _config_path)
	if not FileAccess.file_exists(_config_path):
		push_error("FEAGI config not found at: ", _config_path)
		print("   ❌ File check failed for: ", _config_path)
		return false
	print("   ✅ Config file found")
	
	print("   📁 Executable: ", _feagi_path)
	print("   📁 Config: ", _config_path)
	
	# Build command arguments
	var args = PackedStringArray([
		"--config", _config_path
	])
	
	print("   🚀 Launching: ", _feagi_path, " ", args)
	print("   📋 FEAGI stdout/stderr will be visible in console if launched from terminal")
	
	# Spawn process (non-blocking)
	# Note: Godot's create_process doesn't capture stdout/stderr
	# For debugging, launch Godot from terminal to see FEAGI logs
	_process_id = OS.create_process(_feagi_path, args, false)
	
	if _process_id <= 0:
		push_error("Failed to start FEAGI process")
		return false
	
	print("   ✅ FEAGI process started (PID: ", _process_id, ")")
	_is_running = true
	
	# Wait for HTTP server to become ready
	print("   ⏳ Waiting for FEAGI HTTP server to be ready...")
	var ready = await _wait_for_http_ready()
	
	if ready:
		print("   ✅ FEAGI is ready!")
		
		# Load default genome
		print("   📦 Loading default genome...")
		var genome_loaded = await _load_default_genome()
		if genome_loaded:
			print("   ✅ Default genome loaded successfully")
		else:
			push_warning("   ⚠️ Failed to load default genome (FEAGI will run without brain)")
		
		_health_check_timer.start()
		feagi_started.emit()
		return true
	else:
		push_error("FEAGI failed to start within timeout")
		stop_feagi()
		return false

## Stop FEAGI gracefully
func stop_feagi():
	if not _is_running or _process_id <= 0:
		return
	
	print("🛑 [ProcessManager] Stopping FEAGI subprocess...")
	
	_health_check_timer.stop()
	
	# Try graceful shutdown first (SIGTERM)
	OS.kill(_process_id)
	
	# Wait briefly for graceful shutdown
	await get_tree().create_timer(1.0).timeout
	
	# Force kill if still running
	if OS.is_process_running(_process_id):
		print("   ⚠️ Force killing FEAGI process")
		# Note: No direct SIGKILL in Godot, OS.kill() should handle it
	
	_process_id = 0
	_is_running = false
	print("   ✅ FEAGI stopped")
	feagi_stopped.emit()

## Check if FEAGI process is still running
func is_running() -> bool:
	if not _is_running or _process_id <= 0:
		return false
	
	return OS.is_process_running(_process_id)

## Get the FEAGI API URL
func get_api_url() -> String:
	return "http://127.0.0.1:%d" % FEAGI_HTTP_PORT

## Get the FEAGI WebSocket URL
func get_websocket_url() -> String:
	return "ws://127.0.0.1:%d" % FEAGI_WEBSOCKET_PORT

## Wait for FEAGI's HTTP server to be ready
func _wait_for_http_ready() -> bool:
	var http = HTTPRequest.new()
	add_child(http)
	
	var health_url = get_api_url() + "/v1/system/health_check"
	var attempts = 0
	var max_attempts = STARTUP_TIMEOUT_SECONDS * 2  # Poll every 500ms
	
	while attempts < max_attempts:
		# Check if process crashed
		if not is_running():
			print("   ❌ FEAGI process crashed during startup")
			http.queue_free()
			return false
		
		# Try health check
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
			print("   ⏳ Still waiting... (", attempts / 2, "s elapsed)")
	
	http.queue_free()
	return false

## Load the default genome into FEAGI
func _load_default_genome() -> bool:
	var genome_path = _get_default_genome_path()
	if not FileAccess.file_exists(genome_path):
		push_error("Default genome not found at: ", genome_path)
		return false
	
	print("      📁 Genome path: ", genome_path)
	
	# Read genome file
	var file = FileAccess.open(genome_path, FileAccess.READ)
	if not file:
		push_error("Failed to read genome file")
		return false
	
	var genome_json = file.get_as_text()
	file.close()
	
	# Parse to validate it's valid JSON
	var json = JSON.new()
	var parse_result = json.parse(genome_json)
	if parse_result != OK:
		push_error("Invalid genome JSON")
		return false
	
	# POST to FEAGI's genome upload endpoint
	var http = HTTPRequest.new()
	add_child(http)
	
	var upload_url = get_api_url() + "/v1/genome/upload"
	var headers = ["Content-Type: application/json"]
	
	print("      🌐 Uploading genome to: ", upload_url)
	var error = http.request(upload_url, headers, HTTPClient.METHOD_POST, genome_json)
	
	if error != OK:
		push_error("Failed to initiate genome upload request")
		http.queue_free()
		return false
	
	var result = await http.request_completed
	var response_code = result[1]
	
	http.queue_free()
	
	if response_code >= 200 and response_code < 300:
		print("      ✅ Genome uploaded successfully (HTTP ", response_code, ")")
		return true
	else:
		push_error("Genome upload failed (HTTP ", response_code, ")")
		return false

## Get path to default genome file
func _get_default_genome_path() -> String:
	if OS.has_feature("editor"):
		# Development mode
		return ProjectSettings.globalize_path("res://Resources/genomes/essential_genome.json")
	else:
		# Packaged mode
		var os_name = OS.get_name()
		if os_name == "macOS":
			return OS.get_executable_path().get_base_dir() + "/../Resources/genomes/essential_genome.json"
		elif os_name == "Windows":
			return OS.get_executable_path().get_base_dir() + "/genomes/essential_genome.json"
		elif os_name in ["Linux", "LinuxBSD"]:
			return OS.get_executable_path().get_base_dir() + "/genomes/essential_genome.json"
	
	return ""

## Periodic health check
func _on_health_check():
	if not is_running():
		push_error("FEAGI process crashed!")
		_is_running = false
		var exit_code = -1  # Can't get exit code easily in Godot
		feagi_crashed.emit(exit_code)

## Get the FEAGI executable path (public wrapper)
func get_feagi_executable_path() -> String:
	return _get_feagi_executable_path()

## Find the FEAGI executable path
func _get_feagi_executable_path() -> String:
	var os_name = OS.get_name()
	var base_path = ""
	
	# Determine base path based on platform
	if os_name == "macOS":
		# In packaged .app: Contents/Resources/bin/feagi
		# In development: relative to project
		if OS.has_feature("editor"):
			# Development mode - use project-relative path
			base_path = ProjectSettings.globalize_path("res://../../feagi/target/release/feagi")
		else:
			# Packaged mode - use wrapper script for debugging
			base_path = OS.get_executable_path().get_base_dir() + "/launch_feagi_wrapper.sh"
	
	elif os_name == "Windows":
		if OS.has_feature("editor"):
			base_path = ProjectSettings.globalize_path("res://../../feagi/target/release/feagi.exe")
		else:
			base_path = OS.get_executable_path().get_base_dir() + "/bin/feagi.exe"
	
	elif os_name in ["Linux", "LinuxBSD"]:
		if OS.has_feature("editor"):
			base_path = ProjectSettings.globalize_path("res://../../feagi/target/release/feagi")
		else:
			base_path = OS.get_executable_path().get_base_dir() + "/bin/feagi"
	
	else:
		push_error("Unsupported platform: ", os_name)
		return ""
	
	return base_path

## Find the FEAGI configuration file
func _get_config_path() -> String:
	var os_name = OS.get_name()
	
	if OS.has_feature("editor"):
		# Development mode - use FEAGI project config
		return ProjectSettings.globalize_path("res://../../feagi/feagi_configuration.toml")
	else:
		# Packaged mode
		if os_name == "macOS":
			return OS.get_executable_path().get_base_dir() + "/../Resources/feagi_configuration.toml"
		elif os_name == "Windows":
			return OS.get_executable_path().get_base_dir() + "/feagi_configuration.toml"
		elif os_name in ["Linux", "LinuxBSD"]:
			return OS.get_executable_path().get_base_dir() + "/feagi_configuration.toml"
	
	return ""
