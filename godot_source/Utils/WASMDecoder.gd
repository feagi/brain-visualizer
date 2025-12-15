extends Object
class_name WASMDecoder

## @cursor:ffi-safe
## Thin wrapper to load and invoke the browser-side WASM decoder via JS.
## Desktop builds should keep using the native GDExtension.
##
## Also provides FeagiEngine integration for full neural processing in browser.

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
							try { 
								return wasm_bindgen.decode_type_11(bytes);
							}
							catch(e){ 
								console.error('FEAGI WASM decode error:', e);
								return {success:false, error:String(e), areas: {}, total_neurons: 0}; 
							}
						};
					}).catch(function(e){ console.error('FEAGI WASM init failed:', e); });
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
		return {"success": false, "error": "WASM returned non-string result", "areas": {}, "total_neurons": 0}
	
	# Parse the JSON string to get the actual result
	var json = JSON.new()
	var parse_result = json.parse(json_result)
	if parse_result != OK:
		return {"success": false, "error": "Failed to parse WASM JSON result", "areas": {}, "total_neurons": 0}
	
	var js_result = json.data
	if typeof(js_result) == TYPE_DICTIONARY:
		return js_result
	else:
		return {"success": false, "error": "Invalid result type after JSON parse", "areas": {}, "total_neurons": 0}

## ============================================================================
## FeagiEngine Integration (Phase 4)
## ============================================================================

## Ensure feagi-wasm module is loaded and FeagiEngine is available
static func ensure_feagi_wasm_loaded() -> bool:
	if not is_web_platform():
		return false
	
	# Get wasm directory from project settings
	var wasm_dir_variant = ProjectSettings.get_setting("application/wasm_dir")
	var wasm_dir: String = String(wasm_dir_variant) if wasm_dir_variant != null else "wasm/"
	if wasm_dir == "":
		wasm_dir = "wasm/"
	if not wasm_dir.ends_with("/"):
		wasm_dir += "/"
	var wasm_js = wasm_dir.replace("\\", "\\\\").replace("'", "\\'")
	JavaScriptBridge.eval("window.__feagi_wasm_dir='" + wasm_js + "';")
	
	var ok = JavaScriptBridge.eval("""
	(function(){
		if (window.__feagi_engine_ready) return true;
		if (!window.__feagi_engine_loading){
			window.__feagi_engine_loading = true;
			var base = window.location.origin + window.location.pathname.replace(/[^/]*$/, '');
			var wasmDir = window.__feagi_wasm_dir || 'wasm/';
			if (wasmDir[wasmDir.length - 1] !== '/') wasmDir += '/';
			var jsUrl = base + wasmDir + 'feagi_wasm.js';
			
			// Use dynamic import for ES6 modules
			import(jsUrl).then(function(module) {
				return module.default();
			}).then(function(wasm) {
				window.__feagi_wasm_module = wasm;
				window.__feagi_engine_ready = true;
				window.__feagi_engine_loading = false;
				console.log('✅ FEAGI WASM engine loaded');
			}).catch(function(e) {
				console.error('❌ FEAGI WASM engine load failed:', e);
				window.__feagi_engine_loading = false;
			});
		}
		return !!window.__feagi_engine_ready;
	})();
	""")
	return bool(ok)

## Check if FeagiEngine is ready
static func is_feagi_engine_ready() -> bool:
	if not is_web_platform():
		return false
	var ready = JavaScriptBridge.eval("window.__feagi_engine_ready === true")
	return bool(ready)

## Create a new FeagiEngine instance
static func create_feagi_engine() -> JavaScriptObject:
	if not is_web_platform():
		return null
	
	if not is_feagi_engine_ready():
		push_warning("FeagiEngine not ready. Call ensure_feagi_wasm_loaded() first.")
		return null
	
	var engine = JavaScriptBridge.eval("""
	(function() {
		if (!window.__feagi_wasm_module || !window.__feagi_wasm_module.FeagiEngine) {
			return null;
		}
		try {
			// Create engine instance
			var engine = new window.__feagi_wasm_module.FeagiEngine();
			// Store globally for APIRequestWorker to access
			window.__feagi_engine = engine;
			return engine;
		} catch(e) {
			console.error('Failed to create FeagiEngine:', e);
			return null;
		}
	})();
	""")
	
	if engine == null:
		push_error("Failed to create FeagiEngine instance")
		return null
	
	return engine

## Load genome into FeagiEngine
static func load_genome(engine: JavaScriptObject, genome_json: String) -> Dictionary:
	if not is_web_platform():
		return {"success": false, "error": "Not web platform"}
	
	if engine == null:
		return {"success": false, "error": "Engine is null"}
	
	# Store genome JSON temporarily and call async method
	JavaScriptBridge.eval("window.__temp_genome_json = " + JSON.stringify(genome_json))
	var result = JavaScriptBridge.eval("""
	(function() {
		try {
			var genomeJson = window.__temp_genome_json;
			// Call async method - note: this is a Promise, but we can't await in GDScript
			// So we'll need to handle this differently
			var promise = engine.loadGenome(genomeJson);
			// For now, return a pending status
			// The actual implementation should use signals or polling
			delete window.__temp_genome_json;
			return JSON.stringify({success: true, pending: true, message: 'Genome loading initiated'});
		} catch(e) {
			delete window.__temp_genome_json;
			return JSON.stringify({success: false, error: String(e)});
		}
	})();
	""")
	
	if typeof(result) != TYPE_STRING:
		return {"success": false, "error": "Invalid result type"}
	
	var json = JSON.new()
	var parse_result = json.parse(result)
	if parse_result != OK:
		return {"success": false, "error": "Failed to parse result"}
	
	return json.data

## Process a neural burst with FeagiEngine
static func process_burst(engine: JavaScriptObject, input_data: Dictionary = {}) -> Dictionary:
	if not is_web_platform():
		return {"success": false, "error": "Not web platform"}
	
	if engine == null:
		return {"success": false, "error": "Engine is null"}
	
	# Convert input_data to JavaScript object
	var input_json = JSON.stringify(input_data)
	JavaScriptBridge.eval("window.__temp_input_data = " + input_json)
	
	var result = JavaScriptBridge.eval("""
	(function() {
		try {
			var inputData = window.__temp_input_data ? JSON.parse(window.__temp_input_data) : {};
			var resultStr = engine.processBurst(inputData);
			var result = JSON.parse(resultStr);
			delete window.__temp_input_data;
			return JSON.stringify(result);
		} catch(e) {
			delete window.__temp_input_data;
			return JSON.stringify({success: false, error: String(e)});
		}
	})();
	""")
	
	if typeof(result) != TYPE_STRING:
		return {"success": false, "error": "Invalid result type"}
	
	var json = JSON.new()
	var parse_result = json.parse(result)
	if parse_result != OK:
		return {"success": false, "error": "Failed to parse result"}
	
	return json.data

## Get engine statistics
static func get_engine_stats(engine: JavaScriptObject) -> Dictionary:
	if not is_web_platform():
		return {"success": false, "error": "Not web platform"}
	
	if engine == null:
		return {"success": false, "error": "Engine is null"}
	
	var result = JavaScriptBridge.eval("""
	(function() {
		try {
			var statsStr = engine.getStats();
			var stats = JSON.parse(statsStr);
			return JSON.stringify(stats);
		} catch(e) {
			return JSON.stringify({success: false, error: String(e)});
		}
	})();
	""")
	
	if typeof(result) != TYPE_STRING:
		return {"success": false, "error": "Invalid result type"}
	
	var json = JSON.new()
	var parse_result = json.parse(result)
	if parse_result != OK:
		return {"success": false, "error": "Failed to parse result"}
	
	return json.data

## Check if genome is loaded
static func is_genome_loaded(engine: JavaScriptObject) -> bool:
	if not is_web_platform() or engine == null:
		return false
	
	var loaded = JavaScriptBridge.eval("engine.isGenomeLoaded()")
	return bool(loaded)

## Initialize IndexedDB storage
static func init_storage(engine: JavaScriptObject) -> Dictionary:
	if not is_web_platform():
		return {"success": false, "error": "Not web platform"}
	
	if engine == null:
		return {"success": false, "error": "Engine is null"}
	
	# Note: This is async, but we can't await in GDScript
	# The actual implementation should use signals
	var result = JavaScriptBridge.eval("""
	(function() {
		try {
			var promise = engine.initStorage();
			// Return pending status
			return JSON.stringify({success: true, pending: true, message: 'Storage initialization initiated'});
		} catch(e) {
			return JSON.stringify({success: false, error: String(e)});
		}
	})();
	""")
	
	if typeof(result) != TYPE_STRING:
		return {"success": false, "error": "Invalid result type"}
	
	var json = JSON.new()
	var parse_result = json.parse(result)
	if parse_result != OK:
		return {"success": false, "error": "Failed to parse result"}
	
	return json.data

## Save genome to IndexedDB storage
static func save_genome_to_storage(engine: JavaScriptObject, genome_id: String) -> Dictionary:
	if not is_web_platform():
		return {"success": false, "error": "Not web platform"}
	
	if engine == null:
		return {"success": false, "error": "Engine is null"}
	
	var result = JavaScriptBridge.eval("""
	(function() {
		try {
			var promise = engine.saveGenome('""" + genome_id + """');
			return JSON.stringify({success: true, pending: true, message: 'Genome save initiated'});
		} catch(e) {
			return JSON.stringify({success: false, error: String(e)});
		}
	})();
	""")
	
	if typeof(result) != TYPE_STRING:
		return {"success": false, "error": "Invalid result type"}
	
	var json = JSON.new()
	var parse_result = json.parse(result)
	if parse_result != OK:
		return {"success": false, "error": "Failed to parse result"}
	
	return json.data

## Load genome from IndexedDB storage
static func load_genome_from_storage(engine: JavaScriptObject, genome_id: String) -> Dictionary:
	if not is_web_platform():
		return {"success": false, "error": "Not web platform"}
	
	if engine == null:
		return {"success": false, "error": "Engine is null"}
	
	var result = JavaScriptBridge.eval("""
	(function() {
		try {
			var promise = engine.loadGenomeFromStorage('""" + genome_id + """');
			return JSON.stringify({success: true, pending: true, message: 'Genome load initiated'});
		} catch(e) {
			return JSON.stringify({success: false, error: String(e)});
		}
	})();
	""")
	
	if typeof(result) != TYPE_STRING:
		return {"success": false, "error": "Invalid result type"}
	
	var json = JSON.new()
	var parse_result = json.parse(result)
	if parse_result != OK:
		return {"success": false, "error": "Failed to parse result"}
	
	return json.data

## Download genome as JSON
static func download_genome(engine: JavaScriptObject) -> String:
	if not is_web_platform() or engine == null:
		return ""
	
	var genome_json = JavaScriptBridge.eval("engine.downloadGenome()")
	if typeof(genome_json) == TYPE_STRING:
		return genome_json
	return ""
