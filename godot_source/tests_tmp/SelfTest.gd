extends Node
## Temporary self-test for the pre-zenoh refactor. Loads the real main scene, waits for the genome,
## then exercises the firing recorder, live inspector and WebSocket drop recovery. Prints [SELFTEST].

const MAIN_SCENE := "res://BrainVisualizer/BrainVisualizer.tscn"

var _link_events: Array[String] = []
var _failures: int = 0


func _ready() -> void:
	var main: Node = load(MAIN_SCENE).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = main
	await _run()


func _log(msg: String) -> void:
	print("[SELFTEST] ", msg)


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	_log("%s %s: %s" % ["PASS" if ok else "FAIL", name, detail])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _run() -> void:
	if OS.get_environment("SELFTEST_EXPECT_PROTOCOL") == "ZENOH":
		await _test_zenoh_detection()
		_finish()
		return
	var sink: FEAGIVisualizationSink = null
	var t := 0.0
	while t < 120.0:
		if FeagiCore.network != null:
			sink = FeagiCore.network.visualization_sink
		if sink != null and FeagiCore.genome_load_state == FeagiCore.GENOME_LOAD_STATE.GENOME_READY and BV.UI != null and sink._bv_fast_multimeshes_by_id.size() > 0:
			break
		await _wait(1.0)
		t += 1.0
	if t >= 120.0:
		_check("startup", false, "genome/fast path not ready after 120s")
		_finish()
		return
	_log("ready after %.0fs; fast path keys=%d; link=%s" % [t, sink._bv_fast_multimeshes_by_id.size(), FEAGINetworking.VISUALIZATION_LINK_HEALTH.keys()[FeagiCore.network.visualization_link_health]])
	FeagiCore.network.visualization_link_health_changed.connect(func(prev, cur):
		_link_events.append("%s->%s" % [FEAGINetworking.VISUALIZATION_LINK_HEALTH.keys()[prev], FEAGINetworking.VISUALIZATION_LINK_HEALTH.keys()[cur]]))
	await _wait(3.0)
	var net := FeagiCore.network
	var all_features := true
	for feature in FEAGINetworking.FEAGI_FEATURE.values():
		all_features = all_features and net.supports_feature(feature)
	var decoder_name: String = sink._frame_decoder.get_format_name() if sink._frame_decoder != null else "none"
	_check("protocol detection (legacy)", net.feagi_protocol == FEAGINetworking.FEAGI_PROTOCOL.LEGACY and all_features and decoder_name == "Type 11 (native)",
		"protocol=%s all_features_supported=%s decoder=%s" % [FEAGINetworking.FEAGI_PROTOCOL.keys()[net.feagi_protocol], all_features, decoder_name])

	var power: AbstractCorticalArea = null
	for cid in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
		if AbstractCorticalArea.is_power_area(cid):
			power = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[cid]
	if power == null:
		_check("power area", false, "no power area in cache")
		_finish()
		return

	if OS.get_environment("FEAGI_VIZ_NEURONS_SHM") != "":
		# Shared memory configured at startup: the genome must still load and data must flow over SHM.
		await _test_shm(power, sink)
		_finish()
		return
	if OS.get_environment("SELFTEST_SHM_PATH") != "":
		# Switch to shared memory mid-session (startup activation is a separate, pre-existing bug).
		await _test_recorder("websocket data before switch", power, sink)
		FeagiCore.network.shm_transport.enable_shared_memory_visualization(OS.get_environment("SELFTEST_SHM_PATH"))
		await _wait(3.0)
		await _test_shm(power, sink)
		_finish()
		return
	await _test_recorder("recorder", power, sink)
	await _test_live_inspector(power, sink)
	await _test_ws_drop(power, sink, true)
	await _test_ws_drop(power, sink, false)
	_finish()


func _test_shm(area: AbstractCorticalArea, sink: FEAGIVisualizationSink) -> void:
	var net := FeagiCore.network
	var shm_ok := net.transport_mode == FEAGINetworking.TRANSPORT_MODE.SHARED_MEMORY and net.shm_transport.is_active
	var link_ok := net.visualization_link_health == FEAGINetworking.VISUALIZATION_LINK_HEALTH.CONNECTED
	var ws_idle := net.websocket_API.socket_health != FEAGIWebSocketAPI.WEBSOCKET_HEALTH.CONNECTED
	_check("shm transport", shm_ok and link_ok and ws_idle,
		"transport=%s shm_active=%s shm_path=%s link=%s websocket=%s" % [FEAGINetworking.TRANSPORT_MODE.keys()[net.transport_mode], net.shm_transport.is_active, net.shm_transport.shm_path, FEAGINetworking.VISUALIZATION_LINK_HEALTH.keys()[net.visualization_link_health], FEAGIWebSocketAPI.WEBSOCKET_HEALTH.keys()[net.websocket_API.socket_health]])
	await _test_recorder("shm data reaches recorder", area, sink)


func _test_recorder(name: String, area: AbstractCorticalArea, sink: FEAGIVisualizationSink) -> void:
	var recorder := AreaFiringVoxelRecorder.new()
	var areas: Array[AbstractCorticalArea] = [area]
	recorder.set_monitored_areas(areas)
	var started := recorder.start_recording()
	var registered := sink.bulk_decode_registry.source_has(Type11BulkDecodeRegistry.SOURCE_RECORDER, String(area.cortical_ID))
	await _wait(3.0)
	var bursts := recorder.get_burst_update_count()
	var voxels := recorder.get_total_voxel_count()
	recorder.stop_recording()
	var cleared := not sink.bulk_decode_registry.source_has(Type11BulkDecodeRegistry.SOURCE_RECORDER, String(area.cortical_ID))
	_check(name, started and registered and bursts > 0 and voxels > 0 and cleared,
		"started=%s registered=%s bursts_in_3s=%d voxels=%d registry_cleared_on_stop=%s" % [started, registered, bursts, voxels, cleared])


func _test_live_inspector(area: AbstractCorticalArea, sink: FEAGIVisualizationSink) -> void:
	var ui = BV.UI
	var overlay: UI_BrainMonitor_Overlay = null
	for bm in ui._find_all_brain_monitors_in_scene_tree():
		if bm != null and bm._UI_layer_for_BM != null:
			overlay = bm._UI_layer_for_BM
			break
	if overlay == null:
		_check("live inspector", false, "no Brain Monitor overlay found")
		return
	ui.brain_monitor_activity_mode = UIManager.BRAIN_MONITOR_ACTIVITY_MODE.VOXEL_INSPECTOR
	var win: WindowVoxelInspector = ui._window_manager.spawn_voxel_inspector()
	win.set_live_inspector_enabled(true)
	ui.request_live_voxel_inspector(overlay, area, Vector3i(0, 0, 0), Vector2(200, 200))
	var registered := sink.bulk_decode_registry.source_has(Type11BulkDecodeRegistry.SOURCE_LIVE_INSPECTOR, String(area.cortical_ID))
	# The readout tracks the latest frame and power does not fire every burst; watch every frame for 2s.
	var sample = null
	var found_frames := 0
	var hover_frames := 0
	var hover_lost_reasons: Array[String] = []
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2000:
		await get_tree().process_frame
		if ui._live_voxel_hovering:
			hover_frames += 1
		else:
			# Real hovering re-requests on every mouse move; real mouse motion over the window can end it,
			# and UI events can switch the activity mode or the live toggle off. Record why, then restore.
			var why := "mode=%s live_toggle=%s" % [UIManager.BRAIN_MONITOR_ACTIVITY_MODE.keys()[ui.brain_monitor_activity_mode], win.is_live_inspector_enabled() if is_instance_valid(win) else "window_freed"]
			if not hover_lost_reasons.has(why):
				hover_lost_reasons.append(why)
			ui.brain_monitor_activity_mode = UIManager.BRAIN_MONITOR_ACTIVITY_MODE.VOXEL_INSPECTOR
			if not is_instance_valid(win):
				win = ui._window_manager.spawn_voxel_inspector()
			win.set_live_inspector_enabled(true)
			ui.request_live_voxel_inspector(overlay, area, Vector3i(0, 0, 0), Vector2(200, 200))
		var s_now = ui._live_firing_sample
		if s_now is Dictionary and bool(s_now.get("found", false)):
			found_frames += 1
			sample = s_now
	var found := found_frames > 0
	ui.end_live_voxel_inspector_hover(overlay)
	var cleared := not sink.bulk_decode_registry.source_has(Type11BulkDecodeRegistry.SOURCE_LIVE_INSPECTOR, String(area.cortical_ID))
	win.set_live_inspector_enabled(false)
	_check("live inspector", registered and found and cleared,
		"hover_registered=%s frames_hovering=%d frames_with_firing_sample=%d hover_lost_states=%s last_sample=%s registry_cleared_on_leave=%s" % [registered, hover_frames, found_frames, str(hover_lost_reasons), str(sample), cleared])


func _test_ws_drop(area: AbstractCorticalArea, sink: FEAGIVisualizationSink, graceful: bool) -> void:
	var ws: FEAGIWebSocketAPI = FeagiCore.network.websocket_API
	_link_events.clear()
	var kind := "graceful close" if graceful else "abrupt drop"
	if graceful:
		_log("closing WebSocket with a close frame FEAGI does not acknowledge (close(1001))")
		ws._socket.close(1001, "selftest drop")
	else:
		_log("dropping WebSocket abruptly (close(-1): no close handshake, like a dead link)")
		ws._socket.close(-1)
	var t := 0.0
	var dropped := false
	var states_seen: Array[String] = []
	while t < 45.0:
		await _wait(0.5)
		t += 0.5
		var st: String = "null" if ws._socket == null else ["CONNECTING", "OPEN", "CLOSING", "CLOSED"][ws._socket.get_ready_state()]
		if states_seen.is_empty() or states_seen[-1] != st:
			states_seen.append(st)
			_log("socket state %s at %.1fs (ws health=%s, process=%s)" % [st, t, FEAGIWebSocketAPI.WEBSOCKET_HEALTH.keys()[ws.socket_health], ws.is_processing()])
		if FeagiCore.network.visualization_link_health != FEAGINetworking.VISUALIZATION_LINK_HEALTH.CONNECTED:
			dropped = true
		if dropped and FeagiCore.network.visualization_link_health == FEAGINetworking.VISUALIZATION_LINK_HEALTH.CONNECTED:
			break
	var recovered := FeagiCore.network.visualization_link_health == FEAGINetworking.VISUALIZATION_LINK_HEALTH.CONNECTED
	_check("ws %s recovery" % kind, dropped and recovered,
		"dropped=%s recovered=%s after %.1fs link_events=%s connection_state=%s" % [dropped, recovered, t, str(_link_events), FEAGINetworking.CONNECTION_STATE.keys()[FeagiCore.network.connection_state]])
	await _wait(3.0)
	await _test_recorder("data after %s recovery" % kind, area, sink)


func _finish() -> void:
	_log("DONE failures=%d" % _failures)
	await _wait(0.5)
	get_tree().quit(1 if _failures > 0 else 0)


## Against a server that answers like the feagi-interop (zenoh) FEAGI: detect it, gate agent features,
## pick no decoder, and refuse to register instead of falling back to WebSocket.
func _test_zenoh_detection() -> void:
	var t := 0.0
	while t < 30.0 and (FeagiCore.network == null or FeagiCore.network.feagi_protocol == FEAGINetworking.FEAGI_PROTOCOL.UNKNOWN):
		await _wait(0.5)
		t += 0.5
	await _wait(3.0)
	var net := FeagiCore.network
	var any_feature := false
	for feature in FEAGINetworking.FEAGI_FEATURE.values():
		any_feature = any_feature or net.supports_feature(feature)
	var sink := net.visualization_sink
	var decoder_name: String = sink._frame_decoder.get_format_name() if sink._frame_decoder != null else "none"
	_check("protocol detection (zenoh stub)", net.feagi_protocol == FEAGINetworking.FEAGI_PROTOCOL.ZENOH and not any_feature and decoder_name == "none",
		"protocol=%s any_agent_feature_supported=%s decoder=%s after %.1fs" % [FEAGINetworking.FEAGI_PROTOCOL.keys()[net.feagi_protocol], any_feature, decoder_name, t])
	_check("no stream registration on zenoh", net._transport_registration_failed and net.connection_state == FEAGINetworking.CONNECTION_STATE.DISCONNECTED,
		"registration_failed=%s connection_state=%s" % [net._transport_registration_failed, FEAGINetworking.CONNECTION_STATE.keys()[net.connection_state]])
	var out: FeagiRequestOutput = await FeagiCore.requests.refresh_agent_capabilities_cache(true)
	_check("agent request gated", out.failed_requirement_key == &"FEAGI_FEATURE_UNSUPPORTED",
		"refresh_agent_capabilities_cache -> failed_requirement=%s" % out.failed_requirement_key)

