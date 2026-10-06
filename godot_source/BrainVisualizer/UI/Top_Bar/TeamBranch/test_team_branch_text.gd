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
	failures += _test_message_dispatch()
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
	events.free()
	return failures
