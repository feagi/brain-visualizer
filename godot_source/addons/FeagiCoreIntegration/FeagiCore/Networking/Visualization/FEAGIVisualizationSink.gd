extends Node
class_name FEAGIVisualizationSink
## Single consumer of the FEAGI data stream, whatever transport delivered it (WebSocket, shared
## memory, later zenoh). Transports hand raw packet bytes to [method ingest_packet]; this node routes
## them, decodes Type 11 neuron data and drives Brain Monitor MultiMeshes, bulk-array consumers, the
## firing recorder and the live inspector.

signal FEAGI_sent_direct_neural_points_bulk(cortical_ID: StringName, x_array: PackedInt32Array, y_array: PackedInt32Array, z_array: PackedInt32Array, p_array: PackedFloat32Array)
signal FEAGI_sent_SVO_data(cortical_ID: StringName, SVO_data: PackedByteArray)
signal feagi_return_visual_data(SingleRawImage: PackedByteArray)

const MISSING_AREA_WARNING_INTERVAL: float = 10.0  # Only warn every 10 seconds per area
const _BV_FAST_CACHE_REFRESH_INTERVAL_MS: int = 1000

# Rate-limited apply diagnostics (logging only)
const _DIAGNOSTICS_ENABLED: bool = false
const _APPLY_LOG_INTERVAL_MS: int = 1000

# Opt-in Type 11 root-cause: set env BV_TYPE11_ROOTCAUSE=1 (see RECONNECTION_FIX.md)
const _TYPE11_ROOTCAUSE_LOG_INTERVAL_MS: int = 2000
const _TYPE11_ROOTCAUSE_REBUILD_LOG_MS: int = 3000

## Areas whose packets must be decoded into arrays as well as applied by the MultiMesh fast path.
var bulk_decode_registry: Type11BulkDecodeRegistry = Type11BulkDecodeRegistry.new()
## Name of the decoder in use, or "none" when BV cannot decode this FEAGI's stream.
var frame_decoder_name: String:
	get: return _frame_decoder.get_format_name() if _frame_decoder != null else "none"
## Cortical areas currently drawn through the MultiMesh fast path.
var fast_path_area_count: int:
	get: return _bv_fast_multimeshes_by_id.size()

# Decodes frames for the stream format in use; null when BV has no decoder for it.
var _frame_decoder: VisualizationFrameDecoder = null
# One-time warning when frames are dropped because no decoder can handle them (no silent drop)
var _decoder_missing_warned: bool = false
# Frames that arrived while the decoder was still loading (web WASM)
var _pending_frames: Array[PackedByteArray] = []

# Fast path: decoders that support it write frames directly into MultiMeshes (no per-area arrays/signal dispatch).
var _bv_fast_multimeshes_by_id: Dictionary = {}
var _bv_fast_dimensions_by_id: Dictionary = {}
var _bv_fast_cache_last_refresh_ms: int = 0
# Guard: prevents multiple identical call_deferred("_deferred_rebuild_bv_fastpath_after_cache_touch") from queuing per frame.
var _fastpath_rebuild_pending: bool = false
# Number of [method FeagiCore.bv_end_visual_rebuild_pause_one] calls owed once the fast-path cache rebuild
# actually completes. Accumulated (never dropped) across coalesced calls so every matching
# [method FeagiCore.bv_begin_visual_rebuild_pause] is guaranteed a release, even if several rebuild
# requests overlap and get coalesced into a single deferred cache refresh.
var _fastpath_rebuild_pause_ends_owed: int = 0

# Missing cortical area handling
var _missing_cortical_areas: Dictionary = {}  # cortical_id -> {last_warning_time, fetch_attempted}
# Case-insensitive cortical area mapping cache
var _case_mapping_cache: Dictionary = {}  # lowercase_id -> actual_cached_id

var _last_apply_log_ms: int = 0
var _type11_rootcause_last_packet_log_ms: int = 0
var _type11_rootcause_last_rebuild_log_ms: int = 0
var _type11_rootcause_banner_printed: bool = false


func _ready() -> void:
	set_process(false) # only runs while frames wait for a loading decoder
	select_frame_decoder_for_protocol(FEAGINetworking.FEAGI_PROTOCOL.UNKNOWN)
	if FeagiCore.feagi_local_cache:
		FeagiCore.feagi_local_cache.genome_cache_replaced.connect(_on_genome_reloaded)
		FeagiCore.feagi_local_cache.cortical_areas_reloaded.connect(_on_genome_reloaded)
		FeagiCore.feagi_local_cache.cortical_areas.cortical_area_added.connect(func(_area): bulk_decode_registry.invalidate_areas())
		FeagiCore.feagi_local_cache.cortical_areas.cortical_area_about_to_be_removed.connect(func(_area): bulk_decode_registry.invalidate_areas())


func _process(_delta: float) -> void:
	if _frame_decoder == null or not _frame_decoder.is_available():
		return
	var queued := _pending_frames
	_pending_frames = []
	set_process(false)
	for frame in queued:
		ingest_frame(frame)


## Route one FEAGI stream packet by its first byte: byte containers and Type 11 neuron data go to
## [method ingest_frame]; health JSON, raw images and legacy SVO go to their consumers. Every
## transport hands its binary packets here.
func ingest_packet(bytes: PackedByteArray) -> void:
	var structure_id = bytes[0] if bytes.size() > 0 else -1

	# SAFETY CHECK: Ensure we have data before processing
	if bytes.size() == 0:
		push_error("FEAGI: Cannot process empty byte array!")
		return

	# Current FeagiByteContainer versions (3, 4) wrap Type 11; the Rust/WASM decoders parse the container.
	if bytes[0] == 3 or bytes[0] == 4:
		ingest_frame(bytes)
		return

	# FEAGI Byte Container v2 (first byte == 2)
	# This is a wrapper format used by FEAGI (SHM/WS) that can contain one or more structures.
	# Format (from feagi-serialization::FeagiByteContainer):
	# - [0]   version (u8) == 2
	# - [1:3] increment_counter (u16 LE)
	# - [3]   struct_count (u8)
	# - then struct_count * u32 LE lengths
	# - then each structure payload (each payload begins with structure type, e.g., 1 or 11)
	if bytes[0] == 2:
		if bytes.size() < 4:
			push_error("FEAGI: Invalid ByteContainer v2 (too short)")
			return
		var struct_count := int(bytes[3])
		if struct_count <= 0:
			# Valid empty container
			return
		var lookup_len := 4 * struct_count
		var header_total := 4 + lookup_len
		if bytes.size() < header_total:
			push_error("FEAGI: Invalid ByteContainer v2 (header truncated)")
			return
		var data_off := header_total
		for i in range(struct_count):
			var len_off := 4 + i * 4
			var struct_len := int(bytes.decode_u32(len_off))
			if struct_len <= 0:
				continue
			if data_off + struct_len > bytes.size():
				push_error("FEAGI: Invalid ByteContainer v2 (structure out of bounds)")
				return
			var struct_bytes := bytes.slice(data_off, data_off + struct_len)
			ingest_packet(struct_bytes)
			data_off += struct_len
		return
	
	## respond as per type
	match(bytes[0]):
		1: # JSON wrapper (may be legacy status OR SHM JSON Type 11)
			bytes = bytes.slice(2)
			var text := bytes.get_string_from_ascii()
			# 🔍 TEMP DEBUG: Log JSON parsing (first 3)
			if not has_meta("_json_parse_count"):
				set_meta("_json_parse_count", 0)
			var json_count = get_meta("_json_parse_count")
			if json_count < 3:
				print("🦀 [VIZ] TYPE 1 JSON PARSE #%d: %d chars, first 80: %s" % [json_count + 1, text.length(), text.substr(0, 80)])
				set_meta("_json_parse_count", json_count + 1)
			var dict_any: Variant = str_to_var(text)
			var dict: Dictionary = {}
			if typeof(dict_any) == TYPE_DICTIONARY:
				dict = dict_any
			else:
				var json_parsed = JSON.parse_string(text)
				if typeof(json_parsed) == TYPE_DICTIONARY:
					dict = json_parsed
				else:
					push_error("FEAGI: Unable to parse stream data (neither var nor json)!")
					return
			# 🔍 TEMP DEBUG: Log what keys we have
			if json_count < 3:
				print("🦀 [VIZ] TYPE 1 PARSED: has_status=%s, keys=%s" % [dict.has("status"), dict.keys()])
			# SHM JSON Type 11 passthrough
			if dict.has("type") and int(dict.get("type", -1)) == 11 and dict.has("areas") and typeof(dict["areas"]) == TYPE_DICTIONARY:
				var areas: Dictionary = dict["areas"]
				var decoded_areas: Dictionary = {}
				var total_points := 0
				for cortical_id in areas.keys():
					var a = areas[cortical_id]
					if typeof(a) != TYPE_DICTIONARY:
						continue
					var x_arr := PackedInt32Array(a.get("x", []))
					total_points += x_arr.size()
					decoded_areas[cortical_id] = {
						"x_array": x_arr,
						"y_array": PackedInt32Array(a.get("y", [])),
						"z_array": PackedInt32Array(a.get("z", [])),
						"p_array": PackedFloat32Array(a.get("p", [])),
					}
				apply_decoded_areas(decoded_areas)
				if _DIAGNOSTICS_ENABLED:
					print("[VIZ] Processed JSON Type 11: areas=", areas.size(), " points=", total_points)
				return
			if dict.has("status"):
				var dict_status = dict["status"]
				# 🔍 TEMP DEBUG: Log health data updates (first 5)
				if not has_meta("_health_update_count"):
					set_meta("_health_update_count", 0)
				var health_count = get_meta("_health_update_count")
				if health_count < 5:
					print("🦀 [VIZ] TYPE 1 HEALTH UPDATE #%d:" % [health_count + 1])
					print("  - connected: %s" % [dict_status.get("connected", "missing")])
					print("  - brain_readiness: %s" % [dict_status.get("brain_readiness", "missing")])
					print("  - genome_availability: %s" % [dict_status.get("genome_availability", "missing")])
					print("  - genome_timestamp: %s" % [dict_status.get("genome_timestamp", "missing")])
					set_meta("_health_update_count", health_count + 1)
				FeagiCore.feagi_local_cache.update_health_from_FEAGI_dict(dict_status)
					
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
			# 🔍 TEMP DEBUG: Log Type 9 processing (first 10)
			if not has_meta("_type9_log_count"):
				set_meta("_type9_log_count", 0)
			var type9_count = get_meta("_type9_log_count")
			if type9_count < 10:
				print("🦀 [VIZ] TYPE 9 RECEIVED: %d structures, total %d bytes" % [number_contained_structures, bytes.size()])
				set_meta("_type9_log_count", type9_count + 1)
			for structure_index in range(number_contained_structures):
				structure_start_index = bytes.decode_u32(header_offset)        # Little Endian by default
				structure_length = bytes.decode_u32(header_offset + 4)        # Little Endian by default
				var structure_data = bytes.slice(structure_start_index, structure_start_index + structure_length)
				if type9_count < 10 and structure_data.size() > 0:
					print("   - Structure %d: type=%d, offset=%d, length=%d" % [structure_index, structure_data[0], structure_start_index, structure_length])
				ingest_packet(structure_data)
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
			ingest_frame(bytes)

		_: # Unknown
			print("   ❌ ROUTING: UNKNOWN structure type ", structure_id, " - ERROR!")
			push_error("Unknown data type %d recieved!" % bytes[0])


## Decode and apply one visualization frame with the current decoder. For Type 11 that is a
## FeagiByteContainer (first byte 2, 3 or 4) or raw Type 11 bytes (first byte 11).
func ingest_frame(frame: PackedByteArray) -> void:
	if frame.is_empty():
		return
	if _frame_decoder == null or not _frame_decoder.is_available():
		if _frame_decoder != null and _frame_decoder.queue_until_available():
			_pending_frames.append(frame.duplicate())
			set_process(true)
			return
		if not _decoder_missing_warned:
			_decoder_missing_warned = true
			var why := "no decoder for this FEAGI's stream format" if _frame_decoder == null else "%s decoder is not available (build/enable rust_extensions/feagi_data_deserializer)" % _frame_decoder.get_format_name()
			push_warning("[VIZ] Neural activity is not being processed: %s." % why)
		return
	if _frame_decoder.supports_multimesh_apply():
		_ingest_with_multimesh_fast_path(frame)
	else:
		_ingest_decoding_all_areas(frame)


## Use [param decoder] for every following frame (e.g. a zenoh-format decoder). Null drops frames with a warning.
func set_frame_decoder(decoder: VisualizationFrameDecoder) -> void:
	_frame_decoder = decoder
	_decoder_missing_warned = false
	_pending_frames.clear()
	set_process(false)
	request_bv_fastpath_cache_rebuild()
	print("[VIZ] Frame decoder: %s" % ("none" if decoder == null else decoder.get_format_name()))


## Pick the decoder for [param protocol] on this platform. Called by [FEAGINetworking] once it knows
## which FEAGI it talks to.
func select_frame_decoder_for_protocol(protocol: FEAGINetworking.FEAGI_PROTOCOL) -> void:
	match protocol:
		FEAGINetworking.FEAGI_PROTOCOL.ZENOH:
			# The feagi-interop stream format is not defined yet.
			set_frame_decoder(null)
		_:
			if OS.has_feature("web"):
				if not (_frame_decoder is Type11WasmFrameDecoder):
					set_frame_decoder(Type11WasmFrameDecoder.new())
			elif not (_frame_decoder is Type11NativeFrameDecoder):
				set_frame_decoder(Type11NativeFrameDecoder.new())


## Apply already-decoded areas ({cortical_id: {x_array, y_array, z_array, p_array}}) to every consumer.
## Used by decoders that produce arrays for all areas (web WASM, legacy SHM JSON).
func apply_decoded_areas(areas: Dictionary) -> void:
	_note_live_inspector_firing_frame(areas)
	for cortical_id in areas.keys():
		var clean_id := _normalize_type11_cortical_key(cortical_id)
		# Death area is non-visualizable; power area is allowed (custom cone animation)
		if AbstractCorticalArea.is_death_area(clean_id):
			continue
		var area_data: Dictionary = areas[cortical_id]
		var x_array := PackedInt32Array(area_data.get("x_array", PackedInt32Array()))
		var y_array := PackedInt32Array(area_data.get("y_array", PackedInt32Array()))
		var z_array := PackedInt32Array(area_data.get("z_array", PackedInt32Array()))
		var p_array := PackedFloat32Array(area_data.get("p_array", PackedFloat32Array()))
		FEAGI_sent_direct_neural_points_bulk.emit(StringName(clean_id), x_array, y_array, z_array, p_array)
		var area: AbstractCorticalArea = _get_cortical_area_case_insensitive(clean_id)
		if area:
			area.FEAGI_set_direct_points_bulk_data(x_array, y_array, z_array, p_array)
		else:
			_handle_missing_cortical_area(clean_id)


## Register cortical areas that need Type 11 bulk coordinates on the desktop fast path (firing recorder).
func bv_set_type11_bulk_dispatch_cortical_ids(cortical_ids: Array[StringName]) -> void:
	bulk_decode_registry.set_source_ids(Type11BulkDecodeRegistry.SOURCE_RECORDER, cortical_ids)


## Clear Type 11 bulk coordinate dispatch registration.
func bv_clear_type11_bulk_dispatch_cortical_ids() -> void:
	bulk_decode_registry.clear_source(Type11BulkDecodeRegistry.SOURCE_RECORDER)


## Public hook for Brain Monitor: after 3D cortical nodes re-register DirectPoints MultiMeshes on new cache
## instances, rebuild the desktop Type 11 map so packets target the current MultiMeshes (reconnect safe).
## Guard prevents duplicate deferred calls when multiple brain monitor instances or signal handlers call this per frame;
## [param pause_ends_owed] accumulates across coalesced calls so every caller's matching
## [method FeagiCore.bv_begin_visual_rebuild_pause] is still released exactly once, even when its own
## rebuild request gets coalesced into an already-pending one.
func request_bv_fastpath_cache_rebuild(pause_ends_owed: int = 0) -> void:
	_fastpath_rebuild_pause_ends_owed += pause_ends_owed
	bulk_decode_registry.invalidate_areas()
	if not _uses_multimesh_fast_path():
		# No fast path (and no pause to release: [method FeagiCore.bv_begin_visual_rebuild_pause]
		# is itself a no-op on web) - drain immediately so the counter never grows unbounded.
		var owed: int = _fastpath_rebuild_pause_ends_owed
		_fastpath_rebuild_pause_ends_owed = 0
		_release_visual_rebuild_pauses(owed)
		return
	_bv_fast_multimeshes_by_id.clear()
	_bv_fast_dimensions_by_id.clear()
	_bv_fast_cache_last_refresh_ms = 0
	if not _fastpath_rebuild_pending:
		_fastpath_rebuild_pending = true
		call_deferred("_deferred_rebuild_bv_fastpath_after_cache_touch")


func _uses_multimesh_fast_path() -> bool:
	return _frame_decoder != null and _frame_decoder.supports_multimesh_apply()


## Decoders without a MultiMesh fast path (web WASM): every area goes through bulk arrays.
func _ingest_decoding_all_areas(frame: PackedByteArray) -> void:
	var decoded: Dictionary = _frame_decoder.decode_areas(frame)
	if decoded.get("success", false) != true:
		var err = decoded.get("error", "unknown")
		# Suppress noisy logs while WASM is still loading
		if err != "WASM not ready" and err != "WASM not initialized":
			print("   ❌ ERROR: %s decode failed: %s" % [_frame_decoder.get_format_name(), err])
		return
	apply_decoded_areas(decoded.areas)


func _ingest_with_multimesh_fast_path(bytes: PackedByteArray) -> void:
	var perf: Dictionary
	if FeagiCore != null and FeagiCore.bv_is_type11_visual_rebuild_pause_active():
		# Avoid writing neuron instances into MultiMeshes while Brain Monitor is tearing down
		# or before deferred fast-path rescan (stale/freed GPU buffers).
		perf = {
			"success": false,
			"areas_applied": 0,
			"neurons_applied": 0,
			"error": "type11_gpu_apply_paused_visual_rebuild",
		}
	else:
		_refresh_bv_fastpath_cache_if_needed()
		perf = _frame_decoder.apply_to_multimeshes(
			bytes,
			_bv_fast_multimeshes_by_id,
			_bv_fast_dimensions_by_id,
			true # clear_all_before_apply
		)
	# Rate-limited decode/apply diagnostics to pinpoint "receiving but not rendering".
	var now_ms := Time.get_ticks_msec()
	if _DIAGNOSTICS_ENABLED and now_ms - _last_apply_log_ms >= _APPLY_LOG_INTERVAL_MS:
		_last_apply_log_ms = now_ms
		print("[VIZ-APPLY] ok=%s areas_applied=%d neurons_applied=%d err='%s'" % [
			str(bool(perf.get("success", false))), int(perf.get("areas_applied", 0)), int(perf.get("neurons_applied", 0)), String(perf.get("error", ""))
		])

	# Memory areas, areas with several renderers, the firing recorder and the live inspector need decoded
	# arrays the single-MultiMesh fast path cannot give. Decode only those areas; the rest are already drawn.
	var decoded: Dictionary = {}
	var rootcause := _type11_rootcause_enabled()
	if rootcause:
		decoded = _frame_decoder.decode_areas(bytes)
	else:
		var bulk_ids := bulk_decode_registry.get_ids()
		if not bulk_ids.is_empty():
			decoded = _frame_decoder.decode_areas(bytes, bulk_ids)
	var areas: Dictionary = {}
	var areas_any: Variant = decoded.get("areas", null)
	if bool(decoded.get("success", false)) and areas_any is Dictionary:
		areas = areas_any
		_note_live_inspector_firing_frame(areas)
		for cortical_id in areas.keys():
			var clean_id := _normalize_type11_cortical_key(cortical_id)
			var area_obj: AbstractCorticalArea = _get_cortical_area_case_insensitive(clean_id)
			if area_obj == null:
				continue
			var requires_bulk := area_obj.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
			requires_bulk = requires_bulk or area_obj.BV_requires_bulk_directpoints_updates()
			var dispatch_for_recorder := bulk_decode_registry.source_has(Type11BulkDecodeRegistry.SOURCE_RECORDER, clean_id)
			if not requires_bulk and not dispatch_for_recorder:
				continue
			var area_data: Dictionary = areas[cortical_id]
			var x_array: PackedInt32Array = area_data.get("x_array", PackedInt32Array())
			var y_array: PackedInt32Array = area_data.get("y_array", PackedInt32Array())
			var z_array: PackedInt32Array = area_data.get("z_array", PackedInt32Array())
			var p_array: PackedFloat32Array = area_data.get("p_array", PackedFloat32Array())
			var n := x_array.size()
			if n <= 0:
				continue
			if dispatch_for_recorder:
				FEAGI_sent_direct_neural_points_bulk.emit(StringName(clean_id), x_array, y_array, z_array, p_array)
			if requires_bulk:
				area_obj.FEAGI_set_direct_points_bulk_data(x_array, y_array, z_array, p_array)
				area_obj.BV_notify_directpoints_activity(n)
	# Preserve renderer side-effects (timers/animations) without moving arrays through signals.
	if perf and perf.has("area_counts"):
		for cortical_id in perf.area_counts.keys():
			var area: AbstractCorticalArea = _get_cortical_area_case_insensitive(_normalize_type11_cortical_key(cortical_id))
			if area:
				area.BV_notify_directpoints_activity(int(perf.area_counts[cortical_id]))
	if rootcause:
		_type11_rootcause_log_packet_vs_fastpath(areas, perf)


func _refresh_bv_fastpath_cache_if_needed() -> void:
	var now_ms := Time.get_ticks_msec()
	# If the fast-path map is empty (e.g. after genome/cortical reload), always rebuild so Type 11 can target new MultiMeshes.
	if _bv_fast_multimeshes_by_id.size() > 0 and (now_ms - _bv_fast_cache_last_refresh_ms < _BV_FAST_CACHE_REFRESH_INTERVAL_MS):
		return
	_bv_fast_cache_last_refresh_ms = now_ms
	_bv_fast_multimeshes_by_id.clear()
	_bv_fast_dimensions_by_id.clear()
	if not FeagiCore.feagi_local_cache:
		return
	var areas_dict: Dictionary = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas
	var registered_multimesh: int = 0
	for cortical_id in areas_dict.keys():
		var area: AbstractCorticalArea = areas_dict.get(cortical_id)
		if area == null:
			continue
		# Normalize keys to String for stable Rust lookups (StringName vs String key mismatches are easy to hit).
		var key_str := _normalize_type11_cortical_key(cortical_id)
		var mm := area.BV_get_directpoints_multimesh()
		if mm != null:
			# Keep renderer visuals (mesh sizing) in sync with latest cortical properties.
			# Desktop Type11 fast-path bypasses per-area bulk signals, so we refresh explicitly here.
			area.BV_refresh_directpoints_renderer_visuals()
			_bv_fast_multimeshes_by_id[key_str] = mm
			_bv_fast_dimensions_by_id[key_str] = area.BV_get_directpoints_dimensions()
			registered_multimesh += 1
	_type11_rootcause_log_fastpath_rebuild(registered_multimesh)


func _on_genome_reloaded() -> void:
	# Reset missing cortical area tracking when genome reloads
	# This allows areas to be fetched again if they're still missing after reload
	_missing_cortical_areas.clear()
	_case_mapping_cache.clear()
	bulk_decode_registry.invalidate_areas()
	# Force immediate rebuild of desktop Type11 fast-path caches on next packet.
	_bv_fast_multimeshes_by_id.clear()
	_bv_fast_dimensions_by_id.clear()
	_bv_fast_cache_last_refresh_ms = 0
	# Brain Monitor may create DirectPoints MultiMeshes after this signal; rebuild fast-path map once the tree has settled.
	# Guard prevents duplicate deferred calls when both genome_cache_replaced and cortical_areas_reloaded fire in the same frame.
	if not _fastpath_rebuild_pending:
		_fastpath_rebuild_pending = true
		call_deferred("_deferred_rebuild_bv_fastpath_after_cache_touch")


## Re-scan cortical areas for MultiMesh registration after genome / incremental cortical refresh (desktop Type 11 fast path).
func _deferred_rebuild_bv_fastpath_after_cache_touch() -> void:
	_fastpath_rebuild_pending = false
	# Drain every owed release now, regardless of the "web" early-return below, so a pause requested via
	# [method request_bv_fastpath_cache_rebuild] can never be left stuck if this build has no fast path.
	var pause_ends_owed: int = _fastpath_rebuild_pause_ends_owed
	_fastpath_rebuild_pause_ends_owed = 0
	if not _uses_multimesh_fast_path():
		_release_visual_rebuild_pauses(pause_ends_owed)
		return
	_bv_fast_cache_last_refresh_ms = 0
	_refresh_bv_fastpath_cache_if_needed()
	_release_visual_rebuild_pauses(pause_ends_owed)


func _release_visual_rebuild_pauses(count: int) -> void:
	if FeagiCore == null:
		return
	for _i in range(count):
		FeagiCore.bv_end_visual_rebuild_pause_one()


## Fire-time membrane potentials for the voxel under the live inspector cursor.
## The neuron array resets membrane potential to 0 when a neuron spikes; the visualization
## frame still carries the potential from the moment of firing.
func _note_live_inspector_firing_frame(areas: Dictionary) -> void:
	if BV == null or BV.UI == null:
		return
	BV.UI.note_live_inspector_firing_frame(areas)


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


func _handle_missing_cortical_area(cortical_id: StringName) -> void:
	var clean_id := _normalize_type11_cortical_key(cortical_id)
	if AbstractCorticalArea.is_death_area(clean_id):
		# Death area cannot be visualized - silently ignore
		return

	# Skip handling missing areas during genome reload/processing to avoid spam
	var genome_state = FeagiCore.genome_load_state
	if genome_state == FeagiCore.GENOME_LOAD_STATE.GENOME_RELOADING or genome_state == FeagiCore.GENOME_LOAD_STATE.GENOME_PROCESSING:
		return

	# Also skip if cache is empty (genome hasn't loaded yet)
	var cache_size = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.size()
	if cache_size == 0:
		return

	# If the cleaned ID is in cache, it's not actually missing - just had quotes
	if clean_id in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas:
		return

	var current_time = Time.get_time_dict_from_system()
	var current_timestamp = current_time.hour * 3600 + current_time.minute * 60 + current_time.second

	if clean_id not in _missing_cortical_areas:
		_missing_cortical_areas[clean_id] = {
			"last_warning_time": 0.0,
			"fetch_attempted": false
		}

	var area_info = _missing_cortical_areas[clean_id]
	var time_since_last_warning = current_timestamp - area_info.last_warning_time

	# Only show warning if enough time has passed
	if time_since_last_warning >= MISSING_AREA_WARNING_INTERVAL:
		print("   ⚠️  WARNING: Cortical area '", clean_id, "' not found in cache (will retry fetching) - cache size: ", cache_size)
		area_info.last_warning_time = current_timestamp

		# Attempt to fetch the missing cortical area from FEAGI (only once per area)
		if not area_info.fetch_attempted and FeagiCore.can_interact_with_feagi():
			area_info.fetch_attempted = true
			print("   🔄 Attempting to fetch missing cortical area '", clean_id, "' from FEAGI...")
			_fetch_missing_cortical_area_async(clean_id)


func _fetch_missing_cortical_area_async(cortical_id: StringName) -> void:
	var clean_id := _normalize_type11_cortical_key(cortical_id)
	# Double-check if the area is actually missing before fetching
	if clean_id in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas:
		_missing_cortical_areas.erase(clean_id)
		return

	var result = await FeagiCore.requests.get_cortical_area(clean_id)
	if not result.has_errored:
		print("   ✅ Successfully fetched missing cortical area '", clean_id, "' from FEAGI")
		# Verify it's actually in the cache now
		await get_tree().process_frame  # Wait one frame for any pending operations
		if clean_id in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas:
			_missing_cortical_areas.erase(clean_id)
		else:
			push_error("   ❌ CRITICAL: '", clean_id, "' was fetched but is NOT in cache! Cache size: ", FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.size())
			# Don't erase from tracking so it can be retried
	else:
		print("   ❌ Failed to fetch cortical area '", clean_id, "' from FEAGI - this may be expected if the area doesn't exist")
		# Don't retry immediately for areas that return 400 errors
		_missing_cortical_areas.erase(clean_id)


func _normalize_type11_cortical_key(key: Variant) -> String:
	# Strip quotes that Rust may add
	return String(key).strip_edges().replace("'", "").replace('"', "")


func _type11_rootcause_enabled() -> bool:
	var v := str(OS.get_environment("BV_TYPE11_ROOTCAUSE")).strip_edges().to_lower()
	return v == "1" or v == "true" or v == "yes"


func _type11_rootcause_sample_ids(ids: Array, max_n: int) -> String:
	if ids.is_empty():
		return "[]"
	var out: PackedStringArray = []
	var n: int = mini(ids.size(), max_n)
	for i in range(n):
		out.append(str(ids[i]))
	var tail := ", ..." if ids.size() > max_n else ""
	return "[%s]%s" % [", ".join(out), tail]


## Logs fast-path MultiMesh registration count (throttled). Enable with BV_TYPE11_ROOTCAUSE=1.
func _type11_rootcause_log_fastpath_rebuild(registered_multimesh: int) -> void:
	if not _type11_rootcause_enabled():
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms - _type11_rootcause_last_rebuild_log_ms < _TYPE11_ROOTCAUSE_REBUILD_LOG_MS:
		return
	_type11_rootcause_last_rebuild_log_ms = now_ms
	if not _type11_rootcause_banner_printed:
		_type11_rootcause_banner_printed = true
		print("[TYPE11-ROOTCAUSE] Diagnostics ON (BV_TYPE11_ROOTCAUSE=1). Packet detail every %d ms; rebuild summary every %d ms." % [_TYPE11_ROOTCAUSE_LOG_INTERVAL_MS, _TYPE11_ROOTCAUSE_REBUILD_LOG_MS])
	print("[TYPE11-ROOTCAUSE] fast_path rebuild: cortical_ids_with_multimesh=%d" % registered_multimesh)


## Compare Type 11 payload cortical ids to fast-path map and cache objects (throttled).
func _type11_rootcause_log_packet_vs_fastpath(decoded_areas: Dictionary, perf: Dictionary) -> void:
	var now_ms := Time.get_ticks_msec()
	if now_ms - _type11_rootcause_last_packet_log_ms < _TYPE11_ROOTCAUSE_LOG_INTERVAL_MS:
		return
	_type11_rootcause_last_packet_log_ms = now_ms

	var fast_norm: Dictionary = {}
	for fk in _bv_fast_multimeshes_by_id.keys():
		fast_norm[_normalize_type11_cortical_key(fk)] = true

	var packet_norm: PackedStringArray = []
	var seen: Dictionary = {}
	for ck in decoded_areas.keys():
		var cid := _normalize_type11_cortical_key(ck)
		if cid.is_empty() or seen.has(cid):
			continue
		seen[cid] = true
		packet_norm.append(cid)

	var missing_cache: Array[String] = []
	var no_mesh_ipu_like: Array[String] = []
	var in_packet_not_in_fastmap: Array[String] = []

	for cid in packet_norm:
		var area_obj: AbstractCorticalArea = _get_cortical_area_case_insensitive(cid)
		if area_obj == null:
			missing_cache.append(cid)
			continue
		var requires_bulk := area_obj.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
		requires_bulk = requires_bulk or area_obj.BV_requires_bulk_directpoints_updates()
		var mm = area_obj.BV_get_directpoints_multimesh()
		if mm == null and not requires_bulk:
			no_mesh_ipu_like.append(cid)
		if not fast_norm.has(cid):
			in_packet_not_in_fastmap.append(cid)

	print("[TYPE11-ROOTCAUSE] frame: packet_cortical_ids=%d fast_path_keys=%d apply_ok=%s areas_applied=%d neurons_applied=%d err='%s' bulk_decode_ids=%s" % [
		packet_norm.size(), fast_norm.size(), str(bool(perf.get("success", false))), int(perf.get("areas_applied", 0)), int(perf.get("neurons_applied", 0)), str(perf.get("error", "")),
		_type11_rootcause_sample_ids(Array(bulk_decode_registry.get_ids()), 8)
	])
	if not missing_cache.is_empty():
		print("[TYPE11-ROOTCAUSE] ids in packet but NO AbstractCorticalArea in BV cache (sample): %s" % _type11_rootcause_sample_ids(missing_cache, 8))
	if not no_mesh_ipu_like.is_empty():
		print("[TYPE11-ROOTCAUSE] ids need fast-path MultiMesh but BV_get_directpoints_multimesh()==null (no bulk fallback; sample): %s" % _type11_rootcause_sample_ids(no_mesh_ipu_like, 8))
	if not in_packet_not_in_fastmap.is_empty():
		print("[TYPE11-ROOTCAUSE] ids in packet not present in _bv_fast_multimeshes_by_id after refresh (sample): %s" % _type11_rootcause_sample_ids(in_packet_not_in_fastmap, 8))
