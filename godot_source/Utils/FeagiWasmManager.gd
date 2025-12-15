extends Node
class_name FeagiWasmManager

## High-level manager for FEAGI WASM engine in Brain Visualizer
##
## Provides a clean interface for genome loading, burst processing, and storage
## operations. Handles async operations via signals.

signal genome_loaded
signal burst_processed(result: Dictionary)
signal error_occurred(error: String)
signal storage_initialized
signal genome_saved(genome_id: String)
signal genome_deleted(genome_id: String)

var wasm_decoder: WASMDecoder
var feagi_engine: JavaScriptObject = null
var is_initialized: bool = false
var is_storage_initialized: bool = false

func _ready() -> void:
	if not OS.has_feature("web"):
		print("⚠️ Not web platform - FEAGI WASM not available")
		return
	
	wasm_decoder = WASMDecoder.new()
	_initialize_engine()

func _initialize_engine() -> void:
	"""Initialize FeagiEngine asynchronously"""
	if not WASMDecoder.ensure_feagi_wasm_loaded():
		# Not ready yet, try again next frame
		await get_tree().process_frame
		_initialize_engine()
		return
	
	# Wait a bit for module to load
	if not WASMDecoder.is_feagi_engine_ready():
		await get_tree().create_timer(0.1).timeout
		_initialize_engine()
		return
	
	# Create engine instance
	feagi_engine = WASMDecoder.create_feagi_engine()
	if feagi_engine == null:
		emit_signal("error_occurred", "Failed to create FEAGI engine")
		return
	
	is_initialized = true
	print("✅ FeagiEngine initialized successfully")

## Initialize IndexedDB storage
func init_storage() -> void:
	"""Initialize IndexedDB storage (async via Promise)"""
	if not is_initialized:
		emit_signal("error_occurred", "Engine not initialized")
		return
	
	JavaScriptBridge.eval("""
	(function() {
		engine.initStorage().then(function() {
			window.__feagi_storage_init_complete = true;
			window.__feagi_storage_init_error = null;
		}).catch(function(e) {
			window.__feagi_storage_init_complete = false;
			window.__feagi_storage_init_error = String(e);
		});
	})();
	""")
	
	_poll_storage_init()

func _poll_storage_init() -> void:
	"""Poll to check if storage initialization completed"""
	var complete = JavaScriptBridge.eval("window.__feagi_storage_init_complete === true")
	var error = JavaScriptBridge.eval("window.__feagi_storage_init_error")
	
	if complete:
		JavaScriptBridge.eval("window.__feagi_storage_init_complete = null; window.__feagi_storage_init_error = null;")
		is_storage_initialized = true
		emit_signal("storage_initialized")
	elif error != null and typeof(error) == TYPE_STRING and error != "":
		JavaScriptBridge.eval("window.__feagi_storage_init_complete = null; window.__feagi_storage_init_error = null;")
		emit_signal("error_occurred", "Storage init failed: " + error)
	else:
		# Still initializing, check again next frame
		await get_tree().process_frame
		_poll_storage_init()

## Load genome from JSON string
func load_genome_from_json(genome_json: String) -> void:
	"""Load genome from JSON string (async via Promise)"""
	if not is_initialized:
		emit_signal("error_occurred", "Engine not initialized")
		return
	
	if feagi_engine == null:
		emit_signal("error_occurred", "Engine is null")
		return
	
	# Call async loadGenome via JavaScript
	# Since we can't await Promises in GDScript, we'll poll for completion
	JavaScriptBridge.eval("""
	(function() {
		var genomeJson = """ + JSON.stringify(genome_json) + """;
		engine.loadGenome(genomeJson).then(function() {
			window.__feagi_genome_load_complete = true;
			window.__feagi_genome_load_error = null;
		}).catch(function(e) {
			window.__feagi_genome_load_complete = false;
			window.__feagi_genome_load_error = String(e);
		});
	})();
	""")
	
	# Poll for completion
	_poll_genome_load()

func _poll_genome_load() -> void:
	"""Poll to check if genome load completed"""
	var complete = JavaScriptBridge.eval("window.__feagi_genome_load_complete === true")
	var error = JavaScriptBridge.eval("window.__feagi_genome_load_error")
	
	if complete:
		JavaScriptBridge.eval("window.__feagi_genome_load_complete = null; window.__feagi_genome_load_error = null;")
		if WASMDecoder.is_genome_loaded(feagi_engine):
			emit_signal("genome_loaded")
		else:
			emit_signal("error_occurred", "Genome load completed but not loaded")
	elif error != null and typeof(error) == TYPE_STRING and error != "":
		JavaScriptBridge.eval("window.__feagi_genome_load_complete = null; window.__feagi_genome_load_error = null;")
		emit_signal("error_occurred", error)
	else:
		# Still loading, check again next frame
		await get_tree().process_frame
		_poll_genome_load()

## Process a neural burst
func process_burst(input_data: Dictionary = {}) -> Dictionary:
	if not is_initialized:
		emit_signal("error_occurred", "Engine not initialized")
		return {"success": false, "error": "Engine not initialized"}
	
	if not WASMDecoder.is_genome_loaded(feagi_engine):
		emit_signal("error_occurred", "No genome loaded")
		return {"success": false, "error": "No genome loaded"}
	
	var result = WASMDecoder.process_burst(feagi_engine, input_data)
	if result.get("success", false):
		emit_signal("burst_processed", result)
	return result

## Get engine statistics
func get_stats() -> Dictionary:
	if not is_initialized:
		return {"success": false, "error": "Engine not initialized"}
	
	return WASMDecoder.get_engine_stats(feagi_engine)

## Check if genome is loaded
func is_genome_loaded() -> bool:
	if not is_initialized or feagi_engine == null:
		return false
	return WASMDecoder.is_genome_loaded(feagi_engine)

## Save genome to IndexedDB storage
func save_genome_to_storage(genome_id: String) -> void:
	"""Save genome to IndexedDB storage (async via Promise)"""
	if not is_initialized:
		emit_signal("error_occurred", "Engine not initialized")
		return
	
	if not is_storage_initialized:
		init_storage()
		await storage_initialized
	
	JavaScriptBridge.eval("""
	(function() {
		engine.saveGenome('""" + genome_id + """').then(function() {
			window.__feagi_genome_save_complete = true;
			window.__feagi_genome_save_error = null;
		}).catch(function(e) {
			window.__feagi_genome_save_complete = false;
			window.__feagi_genome_save_error = String(e);
		});
	})();
	""")
	
	_poll_genome_save(genome_id)

func _poll_genome_save(genome_id: String) -> void:
	"""Poll to check if genome save completed"""
	var complete = JavaScriptBridge.eval("window.__feagi_genome_save_complete === true")
	var error = JavaScriptBridge.eval("window.__feagi_genome_save_error")
	
	if complete:
		JavaScriptBridge.eval("window.__feagi_genome_save_complete = null; window.__feagi_genome_save_error = null;")
		emit_signal("genome_saved", genome_id)
	elif error != null and typeof(error) == TYPE_STRING and error != "":
		JavaScriptBridge.eval("window.__feagi_genome_save_complete = null; window.__feagi_genome_save_error = null;")
		emit_signal("error_occurred", "Failed to save genome: " + error)
	else:
		# Still saving, check again next frame
		await get_tree().process_frame
		_poll_genome_save(genome_id)

## Load genome from IndexedDB storage
func load_genome_from_storage(genome_id: String) -> void:
	"""Load genome from IndexedDB storage (async via Promise)"""
	if not is_initialized:
		emit_signal("error_occurred", "Engine not initialized")
		return
	
	if not is_storage_initialized:
		init_storage()
		await storage_initialized
	
	JavaScriptBridge.eval("""
	(function() {
		engine.loadGenomeFromStorage('""" + genome_id + """').then(function() {
			window.__feagi_genome_load_complete = true;
			window.__feagi_genome_load_error = null;
		}).catch(function(e) {
			window.__feagi_genome_load_complete = false;
			window.__feagi_genome_load_error = String(e);
		});
	})();
	""")
	
	_poll_genome_load()

## Download genome as JSON string
func download_genome() -> String:
	if not is_initialized or feagi_engine == null:
		return ""
	
	return WASMDecoder.download_genome(feagi_engine)

## Reset engine state
func reset_engine() -> void:
	if not is_initialized or feagi_engine == null:
		return
	
	JavaScriptBridge.eval("engine.reset()")
	is_storage_initialized = false

