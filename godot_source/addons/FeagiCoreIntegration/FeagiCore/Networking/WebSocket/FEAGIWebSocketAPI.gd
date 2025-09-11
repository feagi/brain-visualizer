extends Node
class_name FEAGIWebSocketAPI

enum WEBSOCKET_HEALTH {
	NO_CONNECTION,
	CONNECTED,
	RETRYING
}

const DEF_SOCKET_INBOUND_BUFFER_SIZE: int = 10000000
const DEF_SOCKET_BUFFER_SIZE: int = 10000000
const DEF_PING_INTERVAL_SECONDS: float = 2.0
const SOCKET_GENOME_UPDATE_FLAG: String = "updated" # FEAGI sends this string via websocket if genome is reloaded / changed
const SOCKET_GENEOME_UPDATE_LATENCY: String = "ping" # TODO DELETE

signal FEAGI_socket_health_changed(previous_health: WEBSOCKET_HEALTH, current_health: WEBSOCKET_HEALTH)
signal FEAGI_socket_retrying_connection(retry_count: int, max_retry_count: int)
signal FEAGI_sent_SVO_data(cortical_ID: StringName, SVO_data: PackedByteArray)
signal FEAGI_sent_direct_neural_points(cortical_ID: StringName, points_data: PackedByteArray)
signal FEAGI_sent_direct_neural_points_bulk(cortical_ID: StringName, x_array: PackedInt32Array, y_array: PackedInt32Array, z_array: PackedInt32Array, p_array: PackedFloat32Array)
signal feagi_requesting_reset()
signal feagi_return_visual_data(SingleRawImage: PackedByteArray)


var socket_health: WEBSOCKET_HEALTH:
	get: return _socket_health

#var _cache_websocket_data: PackedByteArray # outside to try to avoid reallocation penalties # NOTE: Godot doesnt seem to care and reallocates anyways lol
var _socket_web_address: StringName = ""
var _socket: WebSocketPeer
var _socket_health: WEBSOCKET_HEALTH = WEBSOCKET_HEALTH.NO_CONNECTION
var _retry_count: int = 0
var _is_purposfully_disconnecting: bool = false
var _temp_genome_ID: float = 0.0
var _temp_genome_num: int = 0

# Missing cortical area handling
var _missing_cortical_areas: Dictionary = {}  # cortical_id -> {last_warning_time, fetch_attempted}
const MISSING_AREA_WARNING_INTERVAL: float = 10.0  # Only warn every 10 seconds per area

# Case-insensitive cortical area mapping cache
var _case_mapping_cache: Dictionary = {}  # lowercase_id -> actual_cached_id

# Rust-based high-performance deserializer
var _rust_deserializer = null
const WASMDecoder = preload("res://Utils/WASMDecoder.gd")

# Queue Type 11 messages on Web until WASM is ready
var _pending_type11: Array = []
var _waiting_for_wasm: bool = false
var _rust_init_attempts: int = 0
const MAX_RUST_INIT_ATTEMPTS := 5


func _ready():
	# Initialize platform-specific decoding path
	if OS.has_feature("web"):
		print("🌐 Web build detected: using WASM decoder; native GDExtension is unavailable on Web.")
		# Kick off WASM loader early so it's ready by the time data arrives
		WASMDecoder.ensure_wasm_loaded()
	else:
		# Initialize Rust-based high-performance deserializer (REQUIRED on desktop)
		_init_rust_deserializer()

func _init_rust_deserializer() -> void:
	if _rust_deserializer != null:
		return
	if ClassDB.class_exists("FeagiDataDeserializer"):
		_rust_deserializer = ClassDB.instantiate("FeagiDataDeserializer")
		if _rust_deserializer:
			print("🦀 FEAGI Rust deserializer initialized successfully!")
			return
		else:
			push_error("🦀 CRITICAL: Failed to instantiate FEAGI Rust deserializer!")
			return
	# Class not registered yet – retry a few times to allow GDExtension to finish loading
	_rust_init_attempts += 1
	if _rust_init_attempts <= MAX_RUST_INIT_ATTEMPTS:
		var t := get_tree().create_timer(0.25)
		t.timeout.connect(_init_rust_deserializer)
		return
	push_error("🦀 CRITICAL: FeagiDataDeserializer class not found after retries. Ensure addon is installed and library built (debug/release).")
	
	# Reset missing area tracking when genome reloads
	if FeagiCore.feagi_local_cache:
		FeagiCore.feagi_local_cache.cache_reloaded.connect(_on_genome_reloaded)

func _process(_delta: float):
	# On Web, flush queued Type 11 packets once WASM is ready
	if OS.has_feature("web") and WASMDecoder.is_wasm_ready() and _pending_type11.size() > 0:
		# Process all queued before polling socket
		for i in _pending_type11.size():
			var qbytes: PackedByteArray = _pending_type11[i]
			var decoded_result: Dictionary = WASMDecoder.decode_type_11(qbytes)
			if decoded_result and decoded_result.has("success") and decoded_result.success == true:
				for cortical_id in decoded_result.areas.keys():
					var area_data = decoded_result.areas[cortical_id]
					var x_array: PackedInt32Array = PackedInt32Array(area_data.x_array)
					var y_array: PackedInt32Array = PackedInt32Array(area_data.y_array)
					var z_array: PackedInt32Array = PackedInt32Array(area_data.z_array)
					var p_array: PackedFloat32Array = PackedFloat32Array(area_data.p_array)
					FEAGI_sent_direct_neural_points_bulk.emit(cortical_id, x_array, y_array, z_array, p_array)
					var area: AbstractCorticalArea = _get_cortical_area_case_insensitive(cortical_id)
					if area:
						area.FEAGI_set_direct_points_bulk_data(x_array, y_array, z_array, p_array)
					else:
						_handle_missing_cortical_area(cortical_id)
	# Clear queue after processing
	if OS.has_feature("web") and WASMDecoder.is_wasm_ready():
		_pending_type11.clear()

	_socket.poll()
	match(_socket.get_ready_state()):
		WebSocketPeer.State.STATE_CONNECTING:
			# Currently connecting to feagi, waiting for FEAGI to confirm
			pass
		WebSocketPeer.State.STATE_OPEN:
			# Connection active with FEAGI
			if _socket_health != WEBSOCKET_HEALTH.CONNECTED:
				if _retry_count != 0:
					push_warning("FEAGI Websocket: Recovered from the retrying state!") # using warning to make things easier to read
					_retry_count = 0
				_set_socket_health(WEBSOCKET_HEALTH.CONNECTED)
			
			while _socket.get_available_packet_count():
				var raw_packet = _socket.get_packet()
				var retrieved_ws_data = raw_packet.decompress(DEF_SOCKET_BUFFER_SIZE, 1) # for some reason, using the enum instead of the number causes this break
				
				# DEBUG: Check if decompression failed
				if retrieved_ws_data.size() == 0:
					push_error("FEAGI WebSocket: Decompression failed - received empty data!")
					continue
				
				_process_wrapped_byte_structure(retrieved_ws_data)
				
		WebSocketPeer.State.STATE_CLOSING:
			# Closing connection to FEAGI, waiting for FEAGI to respond to close request
			pass
		WebSocketPeer.State.STATE_CLOSED:
			# Closed Connection to FEAGI
			if  _socket.get_available_packet_count() > 0:
				# There was some remenant data
				_socket.get_packet().decompress(DEF_SOCKET_BUFFER_SIZE, 1)
			#TODO FeagiEvents.retrieved_visualization_data.emit(str_to_var(_cache_websocket_data.get_string_from_ascii())) # Add to erase neurons
			if _is_purposfully_disconnecting:
				_is_purposfully_disconnecting = false
				set_process(false)
				return
			# Try to retry the WS connection to save it
			if _retry_count < FeagiCore.feagi_settings.number_of_times_to_retry_WS_connections:
				if _socket_health != WEBSOCKET_HEALTH.RETRYING:
					_set_socket_health(WEBSOCKET_HEALTH.RETRYING)
				FEAGI_socket_retrying_connection.emit(_retry_count, FeagiCore.feagi_settings.number_of_times_to_retry_WS_connections)
				get_tree().create_timer(1.0).timeout.connect(_reconnect_websocket) # this is dum. what can be causing the skips though?
				push_warning("FEAGI Websocket: Recovered from the retrying state! Retry %d / %d" % [_retry_count, FeagiCore.feagi_settings.number_of_times_to_retry_WS_connections]) # using warning to make things easier to read
				_retry_count += 1
				return
			else:
				# Ran out of retries
				push_error("FEAGI Websocket: Websocket failed to recover!")
				_set_socket_health(WEBSOCKET_HEALTH.NO_CONNECTION)
				set_process(false)

## Inits address needed to connect
func setup(feagi_socket_address: StringName) -> void:
	_socket_web_address = feagi_socket_address

## Starts a connection
func connect_websocket() -> void:
	if _socket_web_address == "":
		push_error("FEAGI WS: No address specified!")
	_is_purposfully_disconnecting = false
	_retry_count = 0
	# On Web, ensure WASM is initialized before opening the socket to avoid early packets
	if OS.has_feature("web") and not WASMDecoder.is_wasm_ready():
		WASMDecoder.ensure_wasm_loaded()
		if not _waiting_for_wasm:
			_waiting_for_wasm = true
			var timer := get_tree().create_timer(0.1)
			timer.timeout.connect(func():
				_waiting_for_wasm = false
				connect_websocket()
			)
		return
	set_process(true)
	_reconnect_websocket()

## Force closes the socket. This does not cause 'FEAGI_socket_health_changed' to fire
func disconnect_websocket() -> void:
	if _socket == null:
		return
	# this is purposeful, we dont want to emit anything
	_socket_health = WEBSOCKET_HEALTH.NO_CONNECTION
	_is_purposfully_disconnecting = true
	_socket.close()
	

## attempts to send data over websocket
func websocket_send(data: Variant) -> void:
	if _socket_health != WEBSOCKET_HEALTH.CONNECTED:
		push_warning("FEAGI Websocket: Unable to send data to closed socket!")
		return
	_socket.send((data.to_ascii_buffer()).compress(1)) # for some reason, using the enum instead of the number causes this break

func _process_wrapped_byte_structure(bytes: PackedByteArray) -> void:
	# DEBUG: Log the structure ID detection
	var structure_id = bytes[0] if bytes.size() > 0 else -1
	
	# SAFETY CHECK: Ensure we have data before processing
	if bytes.size() == 0:
		push_error("FEAGI: Cannot process empty byte array!")
		return
	
	## respond as per type
	match(bytes[0]):
		1: # JSON wrapper
			bytes = bytes.slice(2)
			var dict: Dictionary = str_to_var(bytes.get_string_from_ascii()) 
			if !dict:
				push_error("FEAGI: Unable to parse WS Data!")
				return
			if dict.has("status"):
				var dict_status = dict["status"]
				FeagiCore.feagi_local_cache.update_health_from_FEAGI_dict(dict_status)
				
				# Check for genome changes via timestamp OR genome_num counter
				var genome_changed = false
				
				if dict_status.has("genome_timestamp"):
					if (!is_zero_approx(_temp_genome_ID - dict_status["genome_timestamp"])):
						if !is_zero_approx(_temp_genome_ID):
							print("🔄 GENOME RESET DETECTED: genome_timestamp changed from ", _temp_genome_ID, " to ", dict_status["genome_timestamp"])
							genome_changed = true
						_temp_genome_ID = dict_status["genome_timestamp"]
				
				if dict_status.has("genome_num"):
					var current_genome_num = dict_status["genome_num"]
					if _temp_genome_num > 0 and current_genome_num != _temp_genome_num:
						print("🔄 GENOME RESET DETECTED: genome_num changed from ", _temp_genome_num, " to ", current_genome_num)
						genome_changed = true
					_temp_genome_num = current_genome_num
				
				# Trigger reset and clear stale cache if genome changed
				if genome_changed:
					print("🗑️ CLEARING stale missing cortical areas cache (had ", _missing_cortical_areas.size(), " entries)")
					_missing_cortical_areas.clear()
					_case_mapping_cache.clear()
					print("📡 WEBSOCKET: Emitting feagi_requesting_reset signal...")
					feagi_requesting_reset.emit()
					print("✅ WEBSOCKET: feagi_requesting_reset signal emitted")
						
					
		7: # ActivatedNeuronLocation
			# ignore version for now
			push_warning("ActivatedNeuronLocation data type is deprecated!")
		8: # SingleRawImage
			# ignore version for now
			feagi_return_visual_data.emit(bytes)
		9: # multi structure
			# ignore version for now
			var number_contained_structures: int = bytes[2]
			var structure_start_index: int = 0 # cached
			var structure_length: int = 0 # cached
			var header_offset: int = 3 # cached, lets us know where to read from the subheader
			for structure_index in number_contained_structures:
				structure_start_index = bytes.decode_u32(header_offset)        # Little Endian by default
				structure_length = bytes.decode_u32(header_offset + 4)        # Little Endian by default
				_process_wrapped_byte_structure(bytes.slice(structure_start_index, structure_start_index + structure_length))
				header_offset += 8
		10: # SVO neuron activations (legacy support)
			var cortical_ID: StringName = bytes.slice(2,8).get_string_from_ascii()
			var SVO_data: PackedByteArray = bytes.slice(8) # TODO this is not efficient at all
			FEAGI_sent_SVO_data.emit(cortical_ID, SVO_data)
			
			# TODO I dont like this
			var area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(cortical_ID)
			if area:
				area.FEAGI_set_SVO_visualization_data(SVO_data)
		
		11: # Direct Neural Points (NEW - feagi-data-processing format with bulk arrays)
			# Type 11 structure: [Type:1][Version:1][NumAreas:2][AreaHeaders][NeuronData]
			# AreaHeaders: [CorticalID:6][DataOffset:4][DataLength:4] per area = 14 bytes per area
			# NeuronData: [X array][Y array][Z array][P array] per area
			
			if OS.has_feature("web"):
				if not WASMDecoder.is_wasm_ready():
					# Queue until WASM is ready and return early
					_pending_type11.append(bytes.duplicate())
					return
				var decoded_result: Dictionary = WASMDecoder.decode_type_11(bytes)
				if !decoded_result or !decoded_result.has("success") or decoded_result.success != true:
					var err = decoded_result.get("error", "unknown")
					# Suppress noisy logs while WASM is still loading
					if err == "WASM not ready" or err == "WASM not initialized":
						return
					print("   ❌ ERROR: Type 11 WASM decode failed: ", err)
					return
				# Process each decoded cortical area with DIRECT bulk arrays
				for cortical_id in decoded_result.areas.keys():
					var area_data = decoded_result.areas[cortical_id]
					var x_array: PackedInt32Array = PackedInt32Array(area_data.x_array)
					var y_array: PackedInt32Array = PackedInt32Array(area_data.y_array)
					var z_array: PackedInt32Array = PackedInt32Array(area_data.z_array)
					var p_array: PackedFloat32Array = PackedFloat32Array(area_data.p_array)
					FEAGI_sent_direct_neural_points_bulk.emit(cortical_id, x_array, y_array, z_array, p_array)
					var area: AbstractCorticalArea = _get_cortical_area_case_insensitive(cortical_id)
					if area:
						area.FEAGI_set_direct_points_bulk_data(x_array, y_array, z_array, p_array)
					else:
						_handle_missing_cortical_area(cortical_id)
			else:
				# Use Rust-based high-performance deserializer (REQUIRED on desktop)
				if _rust_deserializer == null:
					push_error("🦀 CRITICAL: Rust deserializer is null! Cannot process Type 11 data.")
					return
				var decoded_result: Dictionary = _rust_deserializer.decode_type_11_data(bytes)
				if !decoded_result.success:
					print("   ❌ ERROR: Type 11 decode failed: ", decoded_result.error)
					return
				# Process each decoded cortical area with DIRECT bulk arrays (no conversion loops!)
				for cortical_id in decoded_result.areas.keys():
					var area_data = decoded_result.areas[cortical_id]
					FEAGI_sent_direct_neural_points_bulk.emit(
						cortical_id,
						area_data.x_array,
						area_data.y_array,
						area_data.z_array,
						area_data.p_array
					)
					var area: AbstractCorticalArea = _get_cortical_area_case_insensitive(cortical_id)
					if area:
						area.FEAGI_set_direct_points_bulk_data(area_data.x_array, area_data.y_array, area_data.z_array, area_data.p_array)
					else:
						_handle_missing_cortical_area(cortical_id)

		_: # Unknown
			print("   ❌ ROUTING: UNKNOWN structure type ", structure_id, " - ERROR!")
			push_error("Unknown data type %d recieved!" % bytes[0])

func _reconnect_websocket() -> void:
	_socket = null # enforce dereference
	_socket =  WebSocketPeer.new()
	_socket.inbound_buffer_size = DEF_SOCKET_INBOUND_BUFFER_SIZE
	_socket.connect_to_url(_socket_web_address)

func _handle_missing_cortical_area(cortical_id: StringName) -> void:
	# Skip handling missing areas during genome reload/processing to avoid spam
	var genome_state = FeagiCore.genome_load_state
	if genome_state == FeagiCore.GENOME_LOAD_STATE.GENOME_RELOADING or genome_state == FeagiCore.GENOME_LOAD_STATE.GENOME_PROCESSING:
		# Suppress debug output during genome reload - this is expected behavior
		return
	
	# Also skip if cache is empty (genome hasn't loaded yet)
	var cache_size = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.size()
	if cache_size == 0:
		# Suppress debug output when cache is empty - genome is still loading
		return
	
	print("🔍 DEBUG: _handle_missing_cortical_area() called for '%s'" % cortical_id)
	var current_time = Time.get_time_dict_from_system()
	var current_timestamp = current_time.hour * 3600 + current_time.minute * 60 + current_time.second
	
	# Initialize tracking for this cortical area if not seen before
	if cortical_id not in _missing_cortical_areas:
		_missing_cortical_areas[cortical_id] = {
			"last_warning_time": 0.0,
			"fetch_attempted": false
		}
	
	var area_info = _missing_cortical_areas[cortical_id]
	var time_since_last_warning = current_timestamp - area_info.last_warning_time
	
	# Only show warning if enough time has passed
	if time_since_last_warning >= MISSING_AREA_WARNING_INTERVAL:
		print("   ⚠️  WARNING: Cortical area '", cortical_id, "' not found in cache (will retry fetching) - cache size: ", cache_size)
		area_info.last_warning_time = current_timestamp
		
		# Attempt to fetch the missing cortical area from FEAGI (only once per area)
		if not area_info.fetch_attempted and FeagiCore.can_interact_with_feagi():
			area_info.fetch_attempted = true
			print("   🔄 Attempting to fetch missing cortical area '", cortical_id, "' from FEAGI...")
			_fetch_missing_cortical_area_async(cortical_id)

func _fetch_missing_cortical_area_async(cortical_id: StringName) -> void:
	print("🔍 DEBUG: _fetch_missing_cortical_area_async() called for '%s'" % cortical_id)
	# Double-check if the area is actually missing before fetching
	if cortical_id in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas:
		print("   ℹ️ Cortical area '", cortical_id, "' is already in cache, skipping fetch")
		_missing_cortical_areas.erase(cortical_id)
		return
	
	# Fetch the cortical area details from FEAGI
	var result = await FeagiCore.requests.get_cortical_area(cortical_id)
	if not result.has_errored:
		print("   ✅ Successfully fetched missing cortical area '", cortical_id, "' from FEAGI")
		
		# Verify it's actually in the cache now
		await get_tree().process_frame  # Wait one frame for any pending operations
		if cortical_id in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas:
			print("   ✅ Confirmed: '", cortical_id, "' is now in cache")
			_missing_cortical_areas.erase(cortical_id)
		else:
			push_error("   ❌ CRITICAL: '", cortical_id, "' was fetched but is NOT in cache! Cache size: ", FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.size())
			# Don't erase from tracking so it can be retried
	else:
		print("   ❌ Failed to fetch cortical area '", cortical_id, "' from FEAGI - this may be expected if the area doesn't exist")
		# Don't retry immediately for areas that return 400 errors
		_missing_cortical_areas.erase(cortical_id)

func _get_cortical_area_case_insensitive(cortical_id: StringName) -> AbstractCorticalArea:
	# First try exact match (most common case)
	var area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(cortical_id)
	if area:
		return area
	
	# Check case mapping cache
	var lowercase_id = cortical_id.to_lower()
	if lowercase_id in _case_mapping_cache:
		var cached_id = _case_mapping_cache[lowercase_id]
		area = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(cached_id)
		if area:
			return area
		else:
			# Cached mapping is stale, remove it
			_case_mapping_cache.erase(lowercase_id)
	
	# Do case-insensitive search and cache the result
	for cached_id in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		if cached_id.to_lower() == lowercase_id:
			_case_mapping_cache[lowercase_id] = cached_id
			area = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[cached_id]
			# Only log the first time we discover a case mismatch
			if cortical_id != cached_id:
				print("   🔄 Case mismatch detected: neuron data '%s' → cached area '%s' (cached for future lookups)" % [cortical_id, cached_id])
			return area
	
	return null

func _on_genome_reloaded() -> void:
	# Reset missing cortical area tracking when genome reloads
	# This allows areas to be fetched again if they're still missing after reload
	print("   🔄 Genome reloaded - resetting missing cortical area tracking")
	_missing_cortical_areas.clear()
	_case_mapping_cache.clear()  # Clear case mapping cache too

func _set_socket_health(new_health: WEBSOCKET_HEALTH) -> void:
	var prev_health: WEBSOCKET_HEALTH = _socket_health
	_socket_health = new_health
	FEAGI_socket_health_changed.emit(prev_health, new_health)

# All deserialization is now handled by the Rust extension
# The _decode_type_11_optimized function has been removed as it's no longer needed
