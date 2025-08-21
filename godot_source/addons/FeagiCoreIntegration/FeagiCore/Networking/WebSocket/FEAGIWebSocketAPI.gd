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

# Missing cortical area handling
var _missing_cortical_areas: Dictionary = {}  # cortical_id -> {last_warning_time, fetch_attempted}
const MISSING_AREA_WARNING_INTERVAL: float = 10.0  # Only warn every 10 seconds per area

# Case-insensitive cortical area mapping cache
var _case_mapping_cache: Dictionary = {}  # lowercase_id -> actual_cached_id

func _ready():
	# Reset missing area tracking when genome reloads
	if FeagiCore.feagi_local_cache:
		FeagiCore.feagi_local_cache.cache_reloaded.connect(_on_genome_reloaded)

func _process(_delta: float):
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
				if dict_status.has("genome_timestamp"):
					if (!is_zero_approx(_temp_genome_ID - dict_status["genome_timestamp"])):
						if !is_zero_approx(_temp_genome_ID):
							print("reset")
							feagi_requesting_reset.emit()
						_temp_genome_ID = dict_status["genome_timestamp"]
						
					
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
			
			# Use the new optimized decoder
			var decoded_result = _decode_type_11_optimized(bytes, 0)
			
			if !decoded_result.success:
				print("   ❌ ERROR: Type 11 decode failed: ", decoded_result.error)
				return
			
			# Process each decoded cortical area with DIRECT bulk arrays (no conversion loops!)
			for cortical_id in decoded_result.areas.keys():
				var area_data = decoded_result.areas[cortical_id]
				
				# Emit bulk arrays directly - ZERO conversion overhead!
				FEAGI_sent_direct_neural_points_bulk.emit(
					cortical_id,
					area_data.x_array,    # PackedInt32Array - direct from decoder
					area_data.y_array,    # PackedInt32Array - direct from decoder  
					area_data.z_array,    # PackedInt32Array - direct from decoder
					area_data.p_array     # PackedFloat32Array - direct from decoder
				)
				
				# Update cortical area with bulk arrays
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
		print("   ⚠️  WARNING: Cortical area '", cortical_id, "' not found in cache (will retry fetching) - cache size: ", FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.size())
		area_info.last_warning_time = current_timestamp
		
		# Attempt to fetch the missing cortical area from FEAGI (only once per area)
		# But skip if genome is currently reloading or processing, as it will be wiped anyway
		if not area_info.fetch_attempted and FeagiCore.can_interact_with_feagi():
			var genome_state = FeagiCore.genome_load_state
			if genome_state == FeagiCore.GENOME_LOAD_STATE.GENOME_RELOADING or genome_state == FeagiCore.GENOME_LOAD_STATE.GENOME_PROCESSING:
				print("   ⏸️  Skipping fetch for '", cortical_id, "' - genome is reloading/processing")
				return
			area_info.fetch_attempted = true
			print("   🔄 Attempting to fetch missing cortical area '", cortical_id, "' from FEAGI...")
			_fetch_missing_cortical_area_async(cortical_id)

func _fetch_missing_cortical_area_async(cortical_id: StringName) -> void:
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
		print("   ❌ Failed to fetch cortical area '", cortical_id, "' from FEAGI: ", result.failed_requirement)

func _on_genome_reloaded() -> void:
	# Reset missing cortical area tracking when genome reloads
	# This allows areas to be fetched again if they're still missing after reload
	print("   🔄 Genome reloaded - resetting missing cortical area tracking")
	_missing_cortical_areas.clear()

func _set_socket_health(new_health: WEBSOCKET_HEALTH) -> void:
	var prev_health: WEBSOCKET_HEALTH = _socket_health
	_socket_health = new_health
	FEAGI_socket_health_changed.emit(prev_health, new_health)

# Ultra-optimized Type 11 decoder for feagi-data-processing format
func _decode_type_11_optimized(buffer: PackedByteArray, offset: int) -> Dictionary:
	"""
	Decode Type 11 (NeuronCategoricalXYZP) from feagi-data-processing format
	Using bulk array operations for maximum performance
	
	Format:
	1. Global Header: [Type:1][Version:1][NumAreas:2] = 4 bytes
	2. Area Headers: [CorticalID:6][DataOffset:4][DataLength:4] per area = 14 bytes per area  
	3. Neuron Data: [X array][Y array][Z array][P array] per area
	
	Returns: {
		"success": bool,
		"areas": {
			"cortical_id": {
				"x_array": PackedInt32Array,
				"y_array": PackedInt32Array,
				"z_array": PackedInt32Array,
				"p_array": PackedFloat32Array
			}
		},
		"total_neurons": int,
		"error": String (if success=false)
	}
	"""
	var result = {
		"success": false,
		"areas": {},
		"total_neurons": 0,
		"error": ""
	}
	
	var buffer_size = buffer.size()
	var pos = offset
	
	# Check minimum size for global header
	if pos + 4 > buffer_size:
		result.error = "Buffer too small for global header (need 4 bytes)"
		return result
	
	# Read global header
	var structure_type = buffer[pos]
	var version = buffer[pos + 1]
	var num_areas = buffer.decode_u16(pos + 2)  # Little endian uint16
	pos += 4
	
	# Validate header
	if structure_type != 11:
		result.error = "Invalid structure type: %d (expected 11)" % structure_type
		return result
	
	if version != 1:
		result.error = "Unsupported version: %d (expected 1)" % version
		return result
	
	if num_areas == 0:
		result.error = "No cortical areas in data"
		return result
	
	# Check size for area headers
	var area_headers_size = num_areas * 14  # 6 + 4 + 4 bytes per area
	if pos + area_headers_size > buffer_size:
		result.error = "Buffer too small for area headers (need %d bytes)" % area_headers_size
		return result
	
	# Read area headers
	var area_headers = []
	for i in range(num_areas):
		# Read cortical ID (6 bytes) - convert to string efficiently
		var cortical_id = buffer.slice(pos, pos + 6).get_string_from_ascii()
		pos += 6
		
		# Read data offset and length (8 bytes total)
		var data_offset = buffer.decode_u32(pos)      # Little endian uint32
		var data_length = buffer.decode_u32(pos + 4)  # Little endian uint32
		pos += 8
		
		area_headers.append({
			"cortical_id": cortical_id,
			"data_offset": data_offset,
			"data_length": data_length
		})
	
	# Process each area's neuron data with true bulk operations
	var total_neurons = 0
	
	for header in area_headers:
		var cortical_id = header.cortical_id
		var data_offset = header.data_offset
		var data_length = header.data_length
		
		# Validate data range
		if data_offset + data_length > buffer_size:
			result.error = "Area %s data range exceeds buffer (offset=%d, length=%d, buffer_size=%d)" % [cortical_id, data_offset, data_length, buffer_size]
			return result
		
		# Calculate number of neurons in this area
		if data_length % 16 != 0:
			result.error = "Area %s data length %d not divisible by 16" % [cortical_id, data_length]
			return result
		
		var num_neurons = data_length / 16
		if num_neurons == 0:
			# Empty area - skip but don't error
			result.areas[cortical_id] = {
				"x_array": PackedInt32Array(),
				"y_array": PackedInt32Array(),
				"z_array": PackedInt32Array(),
				"p_array": PackedFloat32Array()
			}
			continue
		
		# Extract arrays with ZERO loops - direct bulk conversion
		var array_byte_size = num_neurons * 4  # Each array has num_neurons * 4 bytes
		var data_pos = data_offset
		
		# X array: Direct byte-to-int32 conversion (NO LOOPS!)
		var x_bytes = buffer.slice(data_pos, data_pos + array_byte_size)
		var x_array = x_bytes.to_int32_array()
		data_pos += array_byte_size
		
		# Y array: Direct byte-to-int32 conversion (NO LOOPS!)
		var y_bytes = buffer.slice(data_pos, data_pos + array_byte_size)
		var y_array = y_bytes.to_int32_array()
		data_pos += array_byte_size
		
		# Z array: Direct byte-to-int32 conversion (NO LOOPS!)
		var z_bytes = buffer.slice(data_pos, data_pos + array_byte_size)
		var z_array = z_bytes.to_int32_array()
		data_pos += array_byte_size
		
		# P array: Direct byte-to-float32 conversion (NO LOOPS!)
		var p_bytes = buffer.slice(data_pos, data_pos + array_byte_size)
		var p_array = p_bytes.to_float32_array()
		
		result.areas[cortical_id] = {
			"x_array": x_array,      # PackedInt32Array - direct from bytes
			"y_array": y_array,      # PackedInt32Array - direct from bytes
			"z_array": z_array,      # PackedInt32Array - direct from bytes
			"p_array": p_array       # PackedFloat32Array - direct from bytes
		}
		total_neurons += num_neurons
	
	result.success = true
	result.total_neurons = total_neurons
	return result
