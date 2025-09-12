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
						// Install a stable wrapper we can call from Godot
						window.__feagi_decode_type_11 = function(bytes){
							try { return wasm_bindgen.decode_type_11(bytes); }
							catch(e){ return {success:false, error:String(e)}; }
						};
					}).catch(function(e){ console.error('WASM init failed:', e); });
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
	var js_result = JavaScriptBridge.eval("""
	(function() {
		try {
			var bytes_array = window.__temp_feagi_bytes;
			var uint8_array = new Uint8Array(bytes_array);
			var result = window.__feagi_decode_type_11(uint8_array);
			delete window.__temp_feagi_bytes;
			return result;
		} catch(e) {
			delete window.__temp_feagi_bytes;
			return {success: false, error: String(e), areas: {}, total_neurons: 0};
		}
	})();
	""")
	return js_result if typeof(js_result) == TYPE_DICTIONARY else {"success": false, "error": "Invalid result type", "areas": {}, "total_neurons": 0}
