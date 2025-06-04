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
		
		11: # Direct Neural Points (NEW - optimized format)
			# Type 11 structure: [ID:1][Version:1][NumAreas:4][SecondaryHeaders][AllNeuronData]
			# SecondaryHeaders: For each area: [CorticalID:6][DataOffset:4][NeuronCount:4]
			# AllNeuronData: All neuron data concatenated at the end
			
			var num_areas = bytes.decode_u32(2)  # Number of areas at offset 2 (Little Endian)
			
			# Calculate where neuron data section starts
			var secondary_headers_size = num_areas * 14  # Each area: 6+4+4 bytes
			var neuron_data_section_start = 6 + secondary_headers_size  # After [ID:1][Version:1][NumAreas:4][SecondaryHeaders]
			
			# For summary tracking
			var total_neurons_processed = 0
			var successful_areas = 0
			
			# Process each cortical area using the secondary headers
			var header_offset = 6  # Start after [ID:1][Version:1][NumAreas:4]
			
			for area_idx in range(num_areas):
				
				# Parse area header: [CorticalID:6bytes][DataOffset:4bytes][NeuronCount:4bytes]
				if header_offset + 14 > bytes.size():  # Need at least 14 bytes for header
					print("   ❌ ERROR: Insufficient data for area header at offset ", header_offset)
					print("   📏 Need 14 bytes, have ", bytes.size() - header_offset, " bytes remaining")
					break
				
				var cortical_ID: StringName = bytes.slice(header_offset, header_offset + 6).get_string_from_ascii()
				var data_offset = bytes.decode_u32(header_offset + 6)  # Offset into neuron data section
				var neuron_count = bytes.decode_u32(header_offset + 10)
				header_offset += 14  # Move to next header
				
				# Calculate absolute offset in the byte array
				var absolute_data_offset = neuron_data_section_start + data_offset
				var neuron_data_size = neuron_count * 16  # 16 bytes per neuron
				
				# Validate data bounds
				if absolute_data_offset + neuron_data_size > bytes.size():
					print("   ❌ ERROR: Insufficient data for neuron data. Need ", neuron_data_size, " bytes at absolute offset ", absolute_data_offset)
					print("   📏 Total byte array size: ", bytes.size(), " bytes")
					print("   📏 End offset would be: ", absolute_data_offset + neuron_data_size)
					break
				
				# Extract ONLY the neuron data for this specific area from the correct offset
				var points_data: PackedByteArray = bytes.slice(absolute_data_offset, absolute_data_offset + neuron_data_size)
				
				for neuron_idx in range(neuron_count):
					var neuron_offset = neuron_idx * 16  # Each neuron is 16 bytes
					if neuron_offset + 16 <= points_data.size():
						var x = points_data.decode_u32(neuron_offset)      # X coordinate (uint32)
						var y = points_data.decode_u32(neuron_offset + 4)  # Y coordinate (uint32) 
						var z = points_data.decode_u32(neuron_offset + 8)  # Z coordinate (uint32)
						var potential = points_data.decode_float(neuron_offset + 12)  # Potential (float32)
					else:
						print("     ❌ ERROR: Insufficient data for neuron[", neuron_idx, "] at offset ", neuron_offset)
				
				# Success tracking
				total_neurons_processed += neuron_count
				successful_areas += 1
				
				# Emit signal for this specific area
				FEAGI_sent_direct_neural_points.emit(cortical_ID, points_data)
				
				# Update cortical area with correct neuron data
				var area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(cortical_ID)
				if area:
					area.FEAGI_set_direct_points_visualization_data(points_data)
				else:
					print("   ⚠️  WARNING: Cortical area '", cortical_ID, "' not found in cache")

			
		_: # Unknown
			print("   ❌ ROUTING: UNKNOWN structure type ", structure_id, " - ERROR!")
			push_error("Unknown data type %d recieved!" % bytes[0])

func _reconnect_websocket() -> void:
	_socket = null # enforce dereference
	_socket =  WebSocketPeer.new()
	_socket.inbound_buffer_size = DEF_SOCKET_INBOUND_BUFFER_SIZE
	_socket.connect_to_url(_socket_web_address)

func _set_socket_health(new_health: WEBSOCKET_HEALTH) -> void:
	var prev_health: WEBSOCKET_HEALTH = _socket_health
	_socket_health = new_health
	FEAGI_socket_health_changed.emit(prev_health, new_health)
