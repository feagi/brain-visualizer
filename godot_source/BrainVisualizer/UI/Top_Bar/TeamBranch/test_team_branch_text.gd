extends SceneTree
## Unit tests for the team branch badge text and desktop message dispatch.
## Run: godot --headless --path godot_source --script res://BrainVisualizer/UI/Top_Bar/TeamBranch/test_team_branch_text.gd

const TeamBranchTextScript = preload("res://BrainVisualizer/UI/Top_Bar/TeamBranch/TeamBranchText.gd")
const DesktopTeamEventsScript = preload("res://Autoload/DesktopTeamEvents.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_collaborative_badge()
	failures += _test_fork_badge()
	failures += _test_non_team_state_hides_badge()
	failures += _test_event_text()
	failures += _test_history_line()
	failures += _test_message_dispatch()
	failures += _test_live_health_poll_refreshes_change_chip()
	failures += _test_layout_moves_fold_into_one_row()
	failures += _test_teammate_names()
	if failures == 0:
		print("TeamBranchText tests: PASS")
		quit(0)
	else:
		push_error("TeamBranchText tests: FAIL (%d)" % failures)
		quit(1)


func _expect(condition: bool, label: String) -> int:
	if condition:
		return 0
	push_error("FAILED: " + label)
	return 1


func _team_state(branch: Dictionary) -> Dictionary:
	return {"type": "team_brain_state", "team": true, "experiment_id": "exp-1", "branch": branch}


func _test_collaborative_badge() -> int:
	var state := _team_state({"mode": "collaborative", "master_genome_id": "g-team", "master_revision": 12})
	var failures := 0
	failures += _expect(TeamBranchTextScript.badge_label(state) == "Collaborative genome (rev 12)", "collaborative label")
	failures += _expect(TeamBranchTextScript.mode_of(state) == "collaborative", "collaborative mode")
	failures += _expect(TeamBranchTextScript.badge_tooltip(state).contains("shared genome"), "collaborative tooltip")
	return failures


func _test_fork_badge() -> int:
	var state := _team_state({"mode": "fork", "master_genome_id": "g-team", "diverged_from_revision": 10})
	var failures := 0
	failures += _expect(TeamBranchTextScript.badge_label(state) == "Independent fork (from rev 10)", "fork label")
	failures += _expect(TeamBranchTextScript.badge_tooltip(state).contains("own fork"), "fork tooltip")
	failures += _expect(TeamBranchTextScript.badge_label(_team_state({"mode": "unknown"})) == "Branch unknown", "unknown label")
	return failures


func _test_non_team_state_hides_badge() -> int:
	var failures := 0
	failures += _expect(not TeamBranchTextScript.is_team_state({"type": "team_brain_state", "team": false}), "personal run")
	failures += _expect(not TeamBranchTextScript.is_team_state({}), "no state yet")
	failures += _expect(TeamBranchTextScript.badge_label({}) == "", "empty label")
	return failures


func _test_event_text() -> int:
	var failures := 0
	failures += _expect(
		TeamBranchTextScript.event_text({"kind": "master_saved", "actor_display_name": "Bob", "revision": 12})
			== "Bob saved revision 12 of the collaborative genome.",
		"save text"
	)
	failures += _expect(
		TeamBranchTextScript.event_text({"kind": "master_replaced", "actor_display_name": "", "revision": null})
			== "A teammate replaced the collaborative genome with a fork (a new revision).",
		"replace text"
	)
	failures += _expect(
		TeamBranchTextScript.event_text({"kind": "genome_change", "actor_display_name": "Bob", "target_id": "vision", "operation": "update_cortical_area"})
			== "Bob changed vision (update_cortical_area).",
		"live change text"
	)
	return failures


func _test_history_line() -> int:
	var failures := 0
	var line := TeamBranchTextScript.history_line({
		"kind": "genome_change",
		"actor_display_name": "You",
		"target_id": "vision",
		"operation": "update_cortical_area",
		"timestamp_ms": 1700000000000,
	})
	failures += _expect(line.ends_with("You updated vision."), "own history line")
	var bias_minutes := int(Time.get_time_zone_from_system().get("bias", 0))
	var local_parts := Time.get_datetime_dict_from_unix_time(1700000000 + bias_minutes * 60)
	var local_clock := "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(local_parts["year"]), int(local_parts["month"]), int(local_parts["day"]),
		int(local_parts["hour"]), int(local_parts["minute"]), int(local_parts["second"]),
	]
	failures += _expect(line.begins_with(local_clock), "history clock uses local time")
	failures += _expect(
		TeamBranchTextScript.history_line({"kind": "genome_change", "actor_display_name": "Bob", "target_id": "motor", "operation": "delete_cortical_area"})
			== "Bob deleted motor.",
		"peer history line"
	)
	failures += _expect(TeamBranchTextScript.change_count_chip(0) == "", "chip hidden at zero")
	failures += _expect(TeamBranchTextScript.change_count_chip(3) == "3", "chip count")
	failures += _expect(TeamBranchTextScript.change_count_chip(120) == "99+", "chip cap")
	failures += _expect(not TeamBranchTextScript.change_chip_is_yellow(0), "blue when every change is yours")
	failures += _expect(TeamBranchTextScript.change_chip_is_yellow(1), "yellow when someone else changed the genome")
	var breakdown := TeamBranchTextScript.change_breakdown_tooltip({"You": 2, "Bob": 1, "Ada": 3})
	failures += _expect(breakdown == "You made 2 changes\nAda made 3 changes\nBob made 1 change", "tooltip lists you, then each other person")
	failures += _expect(
		TeamBranchTextScript.change_breakdown_tooltip({"You": 1}) == "You made 1 change",
		"tooltip is only your line when nobody else changed it"
	)
	var ledger := TeamBranchTextScript.events_from_ledger([
		{"replayable": false, "origin": "local", "operation": {"kind": "connectome_imported"}, "targets": []},
		{"replayable": true, "origin": "local", "operation": {"kind": "create_cortical_areas", "params": [{"name": "Analog GPIO Sensor Unit 0"}]}, "targets": [{"id": "aWFncAEAAAA="}], "timestamp_ms": 1700000000000},
		{"replayable": true, "origin": "replayed", "agent_id": "bob-nuid", "operation": {"kind": "update_cortical_area"}, "targets": [{"id": "vision"}], "after": {"name": "vision"}},
	], "")
	failures += _expect(ledger.size() == 2, "ledger skips markers")
	failures += _expect(str(ledger[0].get("actor_display_name")) == "You", "local ledger row is you")
	failures += _expect(str(ledger[0].get("target_id")) == "Analog GPIO Sensor Unit 0", "created input name")
	failures += _expect(str(ledger[1].get("actor_display_name")) == "bob-nuid", "replayed author kept")
	var named := TeamBranchTextScript.events_from_ledger([
		{
			"replayable": true,
			"origin": "local",
			"operation": {"kind": "update_cortical_area", "changes": {"cortical_name": "Image Vision IPU"}},
			"targets": [{"id": "aWFncAEAAAA="}],
			"after": {"cortical_name": "Image Vision IPU"},
		},
		{
			"replayable": true,
			"origin": "local",
			"operation": {"kind": "delete_cortical_area"},
			"targets": [{"id": "bW90b3IAAAA="}],
			"before": {"area": {"cortical_name": "Motor"}, "incoming_mappings": {}},
		},
		{
			"replayable": true,
			"origin": "local",
			"operation": {"kind": "update_cortical_area"},
			"targets": [{"id": "aWFncAEAAAA="}],
		},
	], "")
	failures += _expect(str(named[0].get("target_id")) == "Image Vision IPU", "update uses cortical name")
	failures += _expect(not str(named[0].get("target_id")).contains("="), "update does not show the cortical id")
	failures += _expect(str(named[1].get("target_id")) == "Motor", "delete uses the area name")
	failures += _expect(str(named[2].get("target_id")) == "a cortical area", "an id alone is not shown")
	var columns := TeamBranchTextScript.history_columns(named[0])
	failures += _expect(str(columns["who"]) == "You", "table who column")
	failures += _expect(str(columns["action"]) == "Name Image Vision IPU", "a rename says the new name")
	var detailed := TeamBranchTextScript.events_from_ledger([
		{
			"replayable": true,
			"origin": "local",
			"operation": {
				"kind": "update_cortical_area",
				"changes": {
					"neuron_fire_threshold": 2,
					"neuron_leak_coefficient": 0.2,
					"cortical_id": "aWFncAEAAAA=",
					"coordinates_3d": [4, 8, 1],
				},
			},
			"targets": [{"id": "aWFncAEAAAA="}],
			"before": {
				"cortical_name": "Image Vision IPU",
				"neuron_fire_threshold": 1,
				"neuron_leak_coefficient": 0.1,
				"coordinates_3d": [0, 0, 0],
			},
			"after": {"cortical_name": "Image Vision IPU"},
		},
	], "")
	failures += _expect(
		str(detailed[0].get("detail")) == "Fire threshold 1 → 2, Leak 0.1 → 0.2, Position (0, 0, 0) → (4, 8, 1)",
		"an update lists each property and its old and new value"
	)
	failures += _expect(not str(detailed[0].get("detail")).contains("="), "an update does not print the cortical id")
	failures += _expect(
		str(TeamBranchTextScript.history_columns(detailed[0])["action"]) == str(detailed[0].get("detail")),
		"the action column is the property list"
	)
	var undone := TeamBranchTextScript.events_from_ledger([
		{
			"replayable": true,
			"origin": "local",
			"operation": {"kind": "update_cortical_area", "changes": {"coordinates_3d": [103, 210, 0]}},
			"targets": [{"id": "aWFncAEAAAA="}],
			"before": {
				"cortical_name": "Image Vision IPU",
				"coordinates_3d": {"x": 16, "y": 110, "z": 0},
				"position": {"x": 219, "y": 210, "z": 0},
			},
			"after": {"cortical_name": "Image Vision IPU", "position": {"x": 103, "y": 210, "z": 0}},
		},
	], "")
	failures += _expect(
		str(undone[0].get("detail")) == "Position (219, 210, 0) → (103, 210, 0)",
		"undo shows the live position it left, not the stale original coordinate"
	)
	failures += _expect(str(columns["target"]) == "Image Vision IPU", "table target column")
	failures += _expect(
		TeamBranchTextScript.emphasized("You", TeamBranchTextScript.ACTOR_COLOR) == "[b][color=#8ab4f8]You[/color][/b]",
		"person cell is bold and colored"
	)
	failures += _expect(
		TeamBranchTextScript.emphasized("Image Vision IPU", TeamBranchTextScript.TARGET_COLOR).contains("[b]"),
		"target cell is bold"
	)
	return failures


func _test_message_dispatch() -> int:
	var events: Node = DesktopTeamEventsScript.new()
	var received := {"state": {}, "event": {}}
	events.team_brain_state_changed.connect(func(state: Dictionary): received["state"] = state)
	events.team_main_branch_event.connect(func(event: Dictionary): received["event"] = event)
	events.handle_message(JSON.stringify(_team_state({"mode": "fork", "diverged_from_revision": 3})))
	events.handle_message(JSON.stringify({"type": "team_main_branch_event", "event": {"kind": "master_saved"}}))
	events.handle_message("not json")
	var failures := 0
	failures += _expect(TeamBranchTextScript.mode_of(received["state"]) == "fork", "state dispatched")
	failures += _expect(TeamBranchTextScript.mode_of(events.latest_state) == "fork", "latest state kept")
	failures += _expect(str((received["event"] as Dictionary).get("kind", "")) == "master_saved", "event dispatched")
	failures += _expect(events.change_history.size() == 0, "socket notices are not the ledger")
	events.append_ledger_events([{"kind": "genome_change", "actor_display_name": "You", "mine": true, "target_id": "vision", "operation": "update_cortical_area"}], 4)
	failures += _expect(events.change_history.size() == 1, "ledger rows are kept")
	failures += _expect(events.unseen_own_count == 1, "own chip counts your change")
	failures += _expect(events.unseen_other_count == 0, "own change stays off the teammate chip")
	failures += _expect(events.unseen_change_count == 1, "unseen count")
	failures += _expect(events.ledger_cursor == 4, "cursor advances")
	events.append_ledger_events([{"kind": "genome_change", "actor_display_name": "Bob", "mine": false, "target_id": "motor", "operation": "delete_cortical_area"}], 5)
	failures += _expect(events.unseen_other_count == 1, "teammate chip counts their change")
	failures += _expect(events.unseen_own_count == 1, "teammate change leaves your chip")
	failures += _expect(
		TeamBranchTextScript.change_breakdown_tooltip(events.unseen_by_actor) == "You made 1 change\nBob made 1 change",
		"mixed changes name each person"
	)
	events.mark_change_history_seen()
	failures += _expect(events.unseen_own_count == 0 and events.unseen_other_count == 0, "opening history clears both chips")
	failures += _expect(events.history_window_open, "opening history starts a viewing session")
	failures += _expect(events.change_history.size() == 2, "clearing the chips keeps the list")
	events.append_ledger_events([{"kind": "genome_change", "mine": true, "actor_display_name": "You", "target_id": "vision"}], 6)
	failures += _expect(events.unseen_own_count == 0, "changes while history is open are not counted")
	failures += _expect(events.change_history.size() == 3, "an open history window still lists the change")
	events.mark_history_window_closed()
	events.append_ledger_events([{"kind": "genome_change", "mine": true, "actor_display_name": "You", "target_id": "vision"}], 7)
	failures += _expect(events.unseen_own_count == 1, "counting starts again after history closes")
	failures += _expect(events.unseen_other_count == 0, "a closed window does not invent teammate changes")
	failures += _expect(
		TeamBranchTextScript.change_breakdown_tooltip(events.unseen_by_actor) == "You made 1 change",
		"tooltip follows the unseen people"
	)
	events.free()
	return failures


## Edits made after connect are seen on the repeating health poll, not only the first one.
func _test_live_health_poll_refreshes_change_chip() -> int:
	var source := FileAccess.get_file_as_string("res://addons/FeagiCoreIntegration/FeagiCore/FeagiCore.gd")
	var periodic := source.find("func _fetch_simulation_timestep")
	var next_func := source.find("\nfunc ", periodic + 1)
	if periodic < 0 or next_func < 0:
		push_error("periodic health check was not found")
		return 1
	var body := source.substr(periodic, next_func - periodic)
	if body.find("_maybe_refresh_change_history") < 0:
		push_error("periodic health check must refresh the history chip")
		return 1
	return 0


func _move(agent: String, sequence: int, stamp_ms: int, name: String) -> Dictionary:
	return {
		"sequence": sequence,
		"agent_id": agent,
		"origin": "replayed",
		"timestamp_ms": stamp_ms,
		"targets": [{"kind": "cortical_area", "id": "aWQ%d" % sequence}],
		"after": {"name": name},
		"operation": {"kind": "update_cortical_area", "changes": {"coordinate_2d": [10, sequence]}},
	}


## A burst of moves by one person in one second is one row; a delete inside it stays its own row.
func _test_layout_moves_fold_into_one_row() -> int:
	var failures := 0
	var ledger := [
		_move("NU-1", 1, 5_000, "a"),
		_move("NU-1", 2, 5_100, "b"),
		_move("NU-1", 3, 5_900, "c"),
		{
			"sequence": 4, "agent_id": "NU-1", "timestamp_ms": 5_950,
			"targets": [{"kind": "classifier", "id": "cl-1"}], "before": {"name": "c2"},
			"operation": {"kind": "delete_classifier"},
		},
		_move("NU-1", 5, 5_990, "d"),
		_move("NU-2", 6, 5_995, "e"),
		_move("NU-1", 7, 6_100, "f"),
		{
			"sequence": 8, "agent_id": "NU-1", "timestamp_ms": 6_200,
			"targets": [{"kind": "cortical_area", "id": "aWQ8"}],
			"operation": {"kind": "update_cortical_area", "changes": {"coordinate_2d": [1, 1], "neuron_fire_threshold": 2}},
		},
	]
	var rows: Array = TeamBranchTextScript.grouped_history(TeamBranchTextScript.events_from_ledger(ledger, "NU-0"))
	failures += _expect(rows.size() == 6, "moves fold, others stay: got %d rows" % rows.size())
	failures += _expect(int(rows[0].get("group_count", 0)) == 3, "three moves in one second are one row")
	failures += _expect(str(rows[0].get("detail", "")) == "Moved 3 areas", "folded row says how many moved")
	failures += _expect(str(rows[0].get("target_id", "")) == "3 areas", "folded row target counts areas")
	failures += _expect(str(rows[1].get("operation", "")) == "delete_classifier", "a delete keeps its own row")
	failures += _expect(not rows[2].has("group_count"), "a move after the delete starts a new row")
	failures += _expect(str(rows[3].get("agent_id", "")) == "NU-2", "another person's move is its own row")
	failures += _expect(not rows[4].has("group_count"), "a move in the next second is a new row")
	failures += _expect(not bool(rows[5].get("position_only", true)), "a move with a parameter edit is an edit")
	return failures


func _test_teammate_names() -> int:
	var failures := 0
	var row := {"kind": "genome_change", "agent_id": "NU-5605143836", "actor_display_name": "NU-5605143836", "mine": false}
	failures += _expect(TeamBranchTextScript.actor_name(row, {"NU-5605143836": "Sam"}) == "Sam", "known teammate shows by name")
	failures += _expect(TeamBranchTextScript.actor_name(row, {}) == "A teammate", "unknown account id is not shown raw")
	failures += _expect(TeamBranchTextScript.actor_name({"mine": true}, {}) == "You", "own change is You")
	failures += _expect(
		TeamBranchTextScript.actor_name({"agent_id": "", "actor_display_name": "Bob", "mine": false}, {}) == "Bob",
		"a name the desktop already sent is kept"
	)
	var events: Node = DesktopTeamEventsScript.new()
	var redraws := [0]
	events.change_history_changed.connect(func(): redraws[0] += 1)
	events.handle_message(JSON.stringify({"type": "team_members", "members": [{"agent_id": "NU-7", "display_name": "Ana"}, {"agent_id": "", "display_name": "x"}]}))
	failures += _expect(events.member_names == {"NU-7": "Ana"}, "team list is kept by agent id")
	failures += _expect(redraws[0] == 1, "a new team list redraws the history")
	events.free()
	return failures
