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

# BUTT UGLY HACK UNTIL WE HAVE A PROPER BURST SYSTEM RUNNGER
var _cortical_areas_to_visualize_clear: Array

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
				var retrieved_ws_data = _socket.get_packet().decompress(DEF_SOCKET_BUFFER_SIZE, 1) # for some reason, using the enum instead of the number causes this break
				
				# BUTT UGLY HACK UNTIL WE HAVE A PROPER BURST SYSTEM RUNNGER
				_cortical_areas_to_visualize_clear = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.values()
				
				_process_wrapped_byte_structure(retrieved_ws_data)
				
				for area in _cortical_areas_to_visualize_clear:
					area.FEAGI_set_no_visualizeation_data()
				

				
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
				structure_start_index = bytes.decode_u32(header_offset)
				structure_length = bytes.decode_u32(header_offset + 4)
				_process_wrapped_byte_structure(bytes.slice(structure_start_index, structure_start_index + structure_length))
				header_offset += 8
		10: # SVO neuron activations (legacy support)
			print("⚡ DPR RENDERER: Received legacy Type 10 (SVO) data (", bytes.size(), " bytes) - clearing points for compatibility")
			var cortical_ID: StringName = bytes.slice(2,8).get_string_from_ascii()
			var SVO_data: PackedByteArray = bytes.slice(8) # TODO this is not efficient at all
			FEAGI_sent_SVO_data.emit(cortical_ID, SVO_data)
			
			# TODO I dont like this
			var area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(cortical_ID)
			if area:
				area.FEAGI_set_SVO_visualization_data(SVO_data)
				
				# BUTT UGLY HACK
				var index: int = _cortical_areas_to_visualize_clear.find(area)
				if index != -1:
					_cortical_areas_to_visualize_clear.remove_at(index)
		
		11: # Direct Neural Points (Type 11 - handle both formats)
			print("⚡ DPR RENDERER: Processing Type 11 (Direct Neural Points) data (", bytes.size(), " bytes)")
			
			# Determine if this is brain visualizer plugin format or standard feagi_bytes format
			# Brain visualizer format: Header(2) + CorticalID(6) + PointData
			# Standard feagi_bytes format: Header(2) + NumAreas(4) + SecondaryHeaders + DataSection
			
			var is_brain_visualizer_format = false
			
			if bytes.size() >= 8:
				# Check if bytes 2-7 look like a valid cortical ID (ASCII characters)
				var potential_cortical_id = bytes.slice(2, 8)
				var looks_like_cortical_id = true
				
				for i in range(6):
					var byte_val = potential_cortical_id[i]
					# Valid cortical ID contains printable ASCII (0x20-0x7E) or null padding
					if byte_val != 0 and (byte_val < 0x20 or byte_val > 0x7E):
						looks_like_cortical_id = false
						break
				
				# Also check if bytes 2-5 could be a valid number of areas (little endian uint32)
				if bytes.size() >= 6:
					var potential_num_areas = bytes.decode_u32(2)
					# If num_areas is reasonable (1-1000) and doesn't look like cortical ID, it's feagi_bytes format
					if potential_num_areas >= 1 and potential_num_areas <= 1000 and not looks_like_cortical_id:
						is_brain_visualizer_format = false
					else:
						is_brain_visualizer_format = looks_like_cortical_id
			
			if is_brain_visualizer_format:
				# Brain visualizer plugin format: Header(2) + CorticalID(6) + PointData
				print("   📋 Using brain visualizer Type 11 format")
				var cortical_ID: StringName = bytes.slice(2,8).get_string_from_ascii()
				var points_data: PackedByteArray = bytes.slice(8) # Direct point data
				FEAGI_sent_direct_neural_points.emit(cortical_ID, points_data)
				
				# Update cortical area with direct points data
				var area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(cortical_ID)
				if area:
					area.FEAGI_set_direct_points_visualization_data(points_data)
					
					# BUTT UGLY HACK
					var index: int = _cortical_areas_to_visualize_clear.find(area)
					if index != -1:
						_cortical_areas_to_visualize_clear.remove_at(index)
			else:
				# Standard feagi_bytes Type 11 format: Header(2) + NumAreas(4) + SecondaryHeaders + DataSection
				print("   📋 Using standard feagi_bytes Type 11 format")
				
				if bytes.size() < 6:
					print("   ❌ Invalid feagi_bytes Type 11 data - too short")
					return
				
				var num_areas = bytes.decode_u32(2)
				print("   📊 Processing ", num_areas, " cortical areas")
				
				# Parse secondary headers
				var secondary_header_offset = 6
				
				for area_index in range(num_areas):
					if secondary_header_offset + 14 > bytes.size():
						print("   ❌ Invalid secondary header ", area_index)
						break
					
					# Extract cortical ID (6 bytes, ASCII, null-terminated)
					var cortical_id_bytes = bytes.slice(secondary_header_offset, secondary_header_offset + 6)
					var cortical_ID: StringName = cortical_id_bytes.get_string_from_ascii().strip_edges()
					
					# Extract data offset and neuron count (4 bytes each)
					var data_offset = bytes.decode_u32(secondary_header_offset + 6)
					var neuron_count = bytes.decode_u32(secondary_header_offset + 10)
					
					secondary_header_offset += 14
					
					print("   🧠 Area: ", cortical_ID, ", neurons: ", neuron_count, ", offset: ", data_offset)
					
					# Calculate absolute offset in the data section
					var data_section_start = 6 + (num_areas * 14)
					var absolute_offset = data_section_start + data_offset
					
					# Calculate size of this area's data (16 bytes per neuron: x,y,z,potential as float32)
					var area_data_size = neuron_count * 16
					
					if absolute_offset + area_data_size > bytes.size():
						print("   ❌ Insufficient data for area ", cortical_ID)
						continue
					
					# Extract the point data for this cortical area
					var points_data = bytes.slice(absolute_offset, absolute_offset + area_data_size)
					
					# Convert to brain visualizer format for compatibility with existing DPR renderer
					# Format: [count(uint32)] + [x,y,z,potential(float32)] * count
					var converted_data = PackedByteArray()
					converted_data.resize(4 + area_data_size)
					converted_data.encode_u32(0, neuron_count)
					
					# Copy coordinate and potential data
					for i in range(area_data_size):
						converted_data[4 + i] = points_data[i]
					
					# Send to DPR renderer
					FEAGI_sent_direct_neural_points.emit(cortical_ID, converted_data)
					
					# Update cortical area
					var area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(cortical_ID)
					if area:
						area.FEAGI_set_direct_points_visualization_data(converted_data)
						
						# BUTT UGLY HACK
						var index: int = _cortical_areas_to_visualize_clear.find(area)
						if index != -1:
							_cortical_areas_to_visualize_clear.remove_at(index)

			
		_: # Unknown
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
