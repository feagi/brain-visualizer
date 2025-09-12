extends Object
class_name WASMDecoder

## @cursor:ffi-safe
## Thin wrapper to load and invoke the browser-side WASM decoder via JS.
## Desktop builds should keep using the native GDExtension.

static func is_web_platform() -> bool:
	return OS.has_feature("web")

static func ensure_wasm_loaded() -> bool:
	if not is_web_platform():
		return false
	# Idempotent loader: injects <script> once and initializes wasm module
	# Resolve wasm dir from ProjectSettings in GDScript and expose to JS via window
	var wasm_dir_variant = ProjectSettings.get_setting("application/wasm_dir")
	var wasm_dir: String = String(wasm_dir_variant) if wasm_dir_variant != null else "wasm/"
	if wasm_dir == "":
		wasm_dir = "wasm/"
	if not wasm_dir.ends_with("/"):
		wasm_dir += "/"
	# Set window.__feagi_wasm_dir without calling non-existent 'set' on Window
	var wasm_js = wasm_dir.replace("\\", "\\\\").replace("'", "\\'")
	JavaScriptBridge.eval("window.__feagi_wasm_dir='" + wasm_js + "';")
	var ok = JavaScriptBridge.eval("""
	(function(){
		if (window.__feagi_wasm_ready) return true;
		if (!window.__feagi_wasm_loading){
			window.__feagi_wasm_loading = true;
			var s = document.createElement('script');
			var base = window.location.origin + window.location.pathname.replace(/[^/]*$/, '');
			var wasmDir = window.__feagi_wasm_dir || 'wasm/';
			if (wasmDir[wasmDir.length - 1] !== '/') wasmDir += '/';
			var jsUrl = base + wasmDir + 'feagi_wasm_processing.js';
			var wasmUrl = base + wasmDir + 'feagi_wasm_processing_bg.wasm';
			s.src = jsUrl;
			s.onload = function(){
				if (typeof wasm_bindgen === 'function'){
					// Initialize explicitly with the resolved .wasm URL via fetch to force network request
					fetch(wasmUrl, { credentials: 'same-origin' }).then(function(resp){
						return wasm_bindgen(resp);
					}).then(function(){
						window.__feagi_wasm_ready = true;
						console.log('🦀 WASM module loaded successfully');
						// Install a stable wrapper we can call from Godot
						window.__feagi_decode_type_11 = function(bytes){
							try { 
								console.log('🦀 WASM decode_type_11 called with bytes:', bytes.length);
								var result = wasm_bindgen.decode_type_11(bytes);
								console.log('🦀 WASM decode_type_11 result:', result);
								return result;
							}
							catch(e){ 
								console.error('🦀 WASM decode_type_11 error:', e);
								return {success:false, error:String(e), areas: {}, total_neurons: 0}; 
							}
						};
						console.log('🦀 WASM wrapper function installed');
					}).catch(function(e){ console.error('🦀 WASM init failed:', e); });
				}
			};
			document.head.appendChild(s);
		}
		return !!window.__feagi_wasm_ready;
	})();
	""")
	return bool(ok)

static func is_wasm_ready() -> bool:
	if not is_web_platform():
		return false
	var ready = JavaScriptBridge.eval("window.__feagi_wasm_ready === true")
	return bool(ready)

static func decode_type_11(bytes: PackedByteArray) -> Dictionary:
	if not is_web_platform():
		return {"success": false, "error": "Not web platform", "areas": {}, "total_neurons": 0}
	
	# Ensure loader ran at least once
	var ready: bool = ensure_wasm_loaded()
	if not ready:
		# Not ready yet; caller can retry on next frame
		return {"success": false, "error": "WASM not ready", "areas": {}, "total_neurons": 0}
	
	# Check if WASM function is available
	var has = JavaScriptBridge.eval("typeof window.__feagi_decode_type_11 === 'function'")
	if not bool(has):
		return {"success": false, "error": "WASM not initialized", "areas": {}, "total_neurons": 0}
	
	# Early return for empty bytes
	if bytes.size() == 0:
		return {"success": false, "error": "Empty byte array", "areas": {}, "total_neurons": 0}
	
	# Convert PackedByteArray to regular Array for JavaScript (only when needed)
	var bytes_array: Array = []
	bytes_array.resize(bytes.size())
	for i in range(bytes.size()):
		bytes_array[i] = bytes[i]
	
	# Store bytes array in a global temporarily, then call the WASM function
	JavaScriptBridge.eval("window.__temp_feagi_bytes = " + var_to_str(bytes_array))
	var json_result = JavaScriptBridge.eval("""
	(function() {
		try {
			var bytes_array = window.__temp_feagi_bytes;
			var uint8_array = new Uint8Array(bytes_array);
			var result = window.__feagi_decode_type_11(uint8_array);
			delete window.__temp_feagi_bytes;
			
			// Ensure result is a proper object for Godot
			if (!result || typeof result !== 'object') {
				return JSON.stringify({success: false, error: 'WASM returned invalid result', areas: {}, total_neurons: 0});
			}
			
			// Convert JavaScript object to Godot-compatible format
			// The areas is a Map, we need to convert it to a plain object
			var areas_obj = {};
			if (result.areas && typeof result.areas.forEach === 'function') {
				// It's a Map, convert to plain object
				result.areas.forEach(function(value, key) {
					areas_obj[key] = {
						x_array: Array.from(value.x_array || []),
						y_array: Array.from(value.y_array || []),
						z_array: Array.from(value.z_array || []),
						p_array: Array.from(value.p_array || [])
					};
				});
			} else if (result.areas && typeof result.areas === 'object') {
				// Already a plain object
				areas_obj = result.areas;
			}
			
			var godot_result = {
				success: result.success === true,
				error: String(result.error || ''),
				areas: areas_obj,
				total_neurons: Number(result.total_neurons || 0)
			};
			
			console.log('🦀 Converted result for Godot:', godot_result);
			// Return as JSON string since JavaScriptBridge.eval has issues with complex objects
			return JSON.stringify(godot_result);
		} catch(e) {
			delete window.__temp_feagi_bytes;
			return JSON.stringify({success: false, error: String(e), areas: {}, total_neurons: 0});
		}
	})();
	""")
	
	# Parse JSON result
	if typeof(json_result) != TYPE_STRING:
		print("🦀 WASM JSON result type: ", typeof(json_result), " value: ", json_result)
		return {"success": false, "error": "WASM returned non-string result", "areas": {}, "total_neurons": 0}
	
	print("🦀 WASM JSON result: ", json_result)
	
	# Parse the JSON string to get the actual result
	var json = JSON.new()
	var parse_result = json.parse(json_result)
	if parse_result != OK:
		print("🦀 JSON parse error: ", parse_result)
		return {"success": false, "error": "Failed to parse WASM JSON result", "areas": {}, "total_neurons": 0}
	
	var js_result = json.data
	print("🦀 Parsed WASM result type: ", typeof(js_result))
	if typeof(js_result) == TYPE_DICTIONARY:
		print("🦀 WASM result success: ", js_result.get("success", "missing"))
		print("🦀 WASM result areas count: ", js_result.get("areas", {}).size())
		return js_result
	else:
		print("🦀 WASM result raw: ", js_result)
		return {"success": false, "error": "Invalid result type after JSON parse", "areas": {}, "total_neurons": 0}
