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
	var win = JavaScriptBridge.get_interface("window")
	if win:
		win.set("__feagi_wasm_dir", wasm_dir)
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
		return {}
	# Ensure loader ran at least once
	var ready: bool = ensure_wasm_loaded()
	if not ready:
		# Not ready yet; caller can retry on next frame
		return {"success": false, "error": "WASM not ready", "areas": {}, "total_neurons": 0}
	# Convert to JS Uint8Array and call exported decoder wrapper
	var js_u8 = JavaScriptBridge.create_object("Uint8Array", [bytes])
	var win = JavaScriptBridge.get_interface("window")
	if win and win.has_method("__feagi_decode_type_11"):
		var js_result = win.call("__feagi_decode_type_11", js_u8)
		return js_result if typeof(js_result) == TYPE_DICTIONARY else {}
	return {"success": false, "error": "WASM not initialized", "areas": {}, "total_neurons": 0}
