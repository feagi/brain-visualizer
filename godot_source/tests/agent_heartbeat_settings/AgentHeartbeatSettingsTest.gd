extends SceneTree
## Headless test of the agent heartbeat settings validation (FeagiGeneralSettings).
## Run (from godot_source): Godot --headless --path . --script res://tests/agent_heartbeat_settings/AgentHeartbeatSettingsTest.gd
## Exits non-zero on any failure.

const Settings = preload("res://addons/FeagiCoreIntegration/FeagiCore/ConfigScripts/FeagiGeneralSettings.gd")

var _passed: int = 0
var _failed: int = 0


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL %s %s" % [name, detail])


func _init() -> void:
	# Valid settings produce no error.
	_check("valid", Settings.validate_agent_heartbeat_settings(5.0, 3) == "")
	_check("valid_small_interval", Settings.validate_agent_heartbeat_settings(0.25, 1) == "")

	# An unset resource (both exports at their type defaults of 0) is invalid: there are no defaults.
	var unset := Settings.new()
	_check("unset_resource_is_invalid", Settings.validate_agent_heartbeat_settings(unset.seconds_between_agent_heartbeats, unset.max_missed_agent_heartbeat_acks) != "")

	# Interval must be a finite number > 0.
	for bad_interval in [0.0, -1.0, NAN, INF, -INF]:
		_check("bad_interval_%s" % bad_interval, Settings.validate_agent_heartbeat_settings(bad_interval, 3) != "")

	# Missed-ack count must be > 0.
	for bad_count in [0, -1]:
		_check("bad_count_%d" % bad_count, Settings.validate_agent_heartbeat_settings(5.0, bad_count) != "")

	print("agent_heartbeat_settings: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
