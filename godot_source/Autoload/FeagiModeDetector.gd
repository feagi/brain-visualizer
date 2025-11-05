extends Node
## FEAGI Mode Detector - Auto-detects and configures connection mode
##
## This autoload runs FIRST (before FeagiCore) and determines which FEAGI mode to use:
## - EMBEDDED: Desktop with embedded FEAGI extension (in-process, microsecond latency)
## - REMOTE_DESKTOP: Desktop connecting to external FEAGI (network, millisecond latency)  
## - REMOTE_WEB: Web build connecting to cloud FEAGI (internet, variable latency)
##
## Order of precedence for mode selection:
## 1. Environment variable (FEAGI_MODE=embedded|remote)
## 2. User settings file (user://feagi_connection_settings.json)
## 3. Automatic detection (platform + extension availability)

enum FEAGI_MODE {
	EMBEDDED,        ## Desktop + embedded FEAGI (in-process, optimal performance)
	REMOTE_DESKTOP,  ## Desktop + remote FEAGI (network, flexible deployment)
	REMOTE_WEB       ## Web + remote FEAGI (cloud, accessible anywhere)
}

## Current detected/selected mode
var mode: FEAGI_MODE = FEAGI_MODE.REMOTE_WEB

## Is FEAGI embedded extension available?
var embedded_extension_available: bool = false

## Configuration for current mode
var config: Dictionary = {}

func _enter_tree():
	# This runs BEFORE _ready() and BEFORE FeagiCore
	# Critical for early mode detection
	detect_and_configure_mode()

func detect_and_configure_mode():
	"""Detect platform, check extensions, determine mode, and apply configuration"""
	print("\n" + "=".repeat(60))
	print("🔍 FEAGI Mode Detector")
	print("=".repeat(60))
	
	# Step 1: Platform detection
	var platform = _detect_platform()
	print("Platform: %s" % platform)
	
	# Step 2: Extension availability
	embedded_extension_available = ClassDB.class_exists("FeagiEmbedded")
	if embedded_extension_available:
		print("FEAGI Embedded Extension: ✅ Available")
	else:
		print("FEAGI Embedded Extension: ❌ Not available")
	
	# Step 3: Check environment override
	var env_mode = OS.get_environment("FEAGI_MODE").to_lower()
	if env_mode:
		print("Environment Override: FEAGI_MODE=%s" % env_mode)
	
	# Step 4: Check user settings
	var user_preference = _load_user_preference()
	if user_preference:
		print("User Preference: %s" % user_preference)
	
	# Step 5: Determine mode
	mode = _determine_mode(platform, env_mode, user_preference)
	
	# Step 6: Apply configuration
	_apply_configuration()
	
	print("\n📋 Selected Mode: %s" % _mode_to_string(mode))
	print("=".repeat(60) + "\n")

func _detect_platform() -> String:
	"""Detect platform: web, desktop, mobile, unknown"""
	if OS.has_feature("web"):
		return "web"
	elif OS.has_feature("desktop"):
		return "desktop"
	elif OS.has_feature("mobile"):
		return "mobile"
	else:
		return "unknown"

func _load_user_preference() -> String:
	"""Load user's saved mode preference from user:// directory"""
	var settings_path = "user://feagi_connection_settings.json"
	
	if not FileAccess.file_exists(settings_path):
		return ""
	
	var file = FileAccess.open(settings_path, FileAccess.READ)
	if not file:
		return ""
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_warning("Failed to parse user settings: %s" % json_text)
		return ""
	
	var data = json.get_data()
	return data.get("mode", "")

func _determine_mode(platform: String, env_override: String, user_pref: String) -> FEAGI_MODE:
	"""Determine FEAGI mode based on platform, overrides, and availability"""
	
	# Web builds MUST use remote
	if platform == "web":
		return FEAGI_MODE.REMOTE_WEB
	
	# Non-desktop platforms use remote
	if platform != "desktop":
		return FEAGI_MODE.REMOTE_DESKTOP
	
	# Desktop platform - check overrides and availability
	
	# Environment override takes highest priority
	if env_override == "embedded" or env_override == "in-process":
		if embedded_extension_available:
			return FEAGI_MODE.EMBEDDED
		else:
			push_warning("FEAGI_MODE=embedded requested but extension not available. Falling back to remote.")
			return FEAGI_MODE.REMOTE_DESKTOP
	
	if env_override == "remote" or env_override == "external":
		return FEAGI_MODE.REMOTE_DESKTOP
	
	# User preference (from settings file)
	if user_pref == "embedded":
		if embedded_extension_available:
			return FEAGI_MODE.EMBEDDED
		else:
			push_warning("User prefers embedded mode but extension not available. Using remote.")
			return FEAGI_MODE.REMOTE_DESKTOP
	
	if user_pref == "remote":
		return FEAGI_MODE.REMOTE_DESKTOP
	
	# Auto-detect (default behavior)
	if embedded_extension_available:
		# Prefer embedded if available (best performance)
		return FEAGI_MODE.EMBEDDED
	else:
		# Fall back to remote
		return FEAGI_MODE.REMOTE_DESKTOP

func _apply_configuration():
	"""Apply mode-specific configuration"""
	match mode:
		FEAGI_MODE.EMBEDDED:
			config = {
				"use_embedded": true,
				"api_url": "http://127.0.0.1:8000",
				"ws_host": "127.0.0.1",
				"ws_viz_port": 9050,
				"transport": "hybrid",  # FFI for hot-path, HTTP for cold-path
				"latency_class": "microsecond",
				"description": "In-process FEAGI (optimal performance, desktop-only)"
			}
			print("\nConfiguration: Embedded (in-process)")
			print("  API: %s (HTTP for complex operations)" % config["api_url"])
			print("  Transport: Direct FFI (~1μs) + HTTP localhost (~1ms)")
			print("  Performance: Optimal (microsecond latency)")
		
		FEAGI_MODE.REMOTE_DESKTOP:
			# Read from environment or use defaults
			var api_url = OS.get_environment("FEAGI_API_URL")
			if api_url.is_empty():
				api_url = "http://127.0.0.1:8000"
			
			var ws_host = OS.get_environment("FEAGI_WS_HOST")
			if ws_host.is_empty():
				ws_host = "127.0.0.1"
			
			var ws_port_str = OS.get_environment("FEAGI_WS_PORT")
			var ws_port = int(ws_port_str) if ws_port_str else 9050
			
			config = {
				"use_embedded": false,
				"api_url": api_url,
				"ws_host": ws_host,
				"ws_viz_port": ws_port,
				"transport": "websocket",
				"latency_class": "network",
				"description": "Remote FEAGI server (flexible, multi-client)"
			}
			print("\nConfiguration: Remote Desktop")
			print("  API: %s" % config["api_url"])
			print("  WebSocket: ws://%s:%d" % [config["ws_host"], config["ws_viz_port"]])
			print("  Transport: WebSocket + HTTP")
			print("  Performance: Network latency (~100μs - 10ms)")
		
		FEAGI_MODE.REMOTE_WEB:
			config = {
				"use_embedded": false,
				"api_url": "",  # Populated from URL params via JavaScript
				"ws_host": "",  # Populated from URL params via JavaScript
				"ws_viz_port": 9050,
				"transport": "websocket",
				"latency_class": "internet",
				"description": "Cloud FEAGI server (accessible anywhere)"
			}
			print("\nConfiguration: Remote Web")
			print("  API: Will be loaded from URL parameters")
			print("  Transport: WebSocket + HTTP")
			print("  Performance: Internet latency (~10-100ms)")

#
# ============ PUBLIC API ============
#

func get_mode() -> FEAGI_MODE:
	"""Get current FEAGI mode"""
	return mode

func is_embedded() -> bool:
	"""Returns true if using embedded FEAGI"""
	return mode == FEAGI_MODE.EMBEDDED

func is_remote() -> bool:
	"""Returns true if using remote FEAGI"""
	return mode != FEAGI_MODE.EMBEDDED

func get_api_url() -> String:
	"""Get HTTP API base URL"""
	return config.get("api_url", "http://127.0.0.1:8000")

func get_ws_viz_port() -> int:
	"""Get WebSocket visualization port"""
	return config.get("ws_viz_port", 9050)

func get_ws_host() -> String:
	"""Get WebSocket host"""
	return config.get("ws_host", "127.0.0.1")

func use_ffi_hot_path() -> bool:
	"""Returns true if FFI should be used for hot-path operations"""
	return config.get("use_embedded", false)

func get_mode_string() -> String:
	"""Get mode as human-readable string"""
	return _mode_to_string(mode)

func get_description() -> String:
	"""Get mode description"""
	return config.get("description", "")

func save_user_preference(pref_mode: String):
	"""Save user's mode preference to persistent storage
	
	Args:
		pref_mode: "embedded", "remote", or "auto"
	"""
	var settings = {
		"mode": pref_mode,
		"saved_at": Time.get_datetime_string_from_system()
	}
	
	var json_text = JSON.stringify(settings, "\t")
	var file = FileAccess.open("user://feagi_connection_settings.json", FileAccess.WRITE)
	if file:
		file.store_string(json_text)
		file.close()
		print("💾 Saved user preference: %s" % pref_mode)
	else:
		push_error("Failed to save user preference")

#
# ============ PRIVATE HELPERS ============
#

func _mode_to_string(m: FEAGI_MODE) -> String:
	match m:
		FEAGI_MODE.EMBEDDED:
			return "EMBEDDED"
		FEAGI_MODE.REMOTE_DESKTOP:
			return "REMOTE_DESKTOP"
		FEAGI_MODE.REMOTE_WEB:
			return "REMOTE_WEB"
		_:
			return "UNKNOWN"

