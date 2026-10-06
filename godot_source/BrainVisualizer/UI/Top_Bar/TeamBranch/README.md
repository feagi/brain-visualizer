# Team branch badge

Shows whether the team experiment running in FEAGI is on the **collaborative
genome** (the team's shared master genome) or an **independent fork**, and
shows teammates' live changes to the collaborative genome as notifications.

## Design

feagi-desktop is the source of truth for the branch. Brain Visualizer only
displays it:

- `Autoload/DesktopTeamEvents.gd` connects to the loopback WebSocket that
  feagi-desktop serves (`commands/team_bv_events.rs`). The URL and reconnect
  delay come from `FEAGI_DESKTOP_EVENTS_WS_URL` and
  `FEAGI_DESKTOP_EVENTS_RECONNECT_SECONDS`, set by the desktop at launch. Without
  them (web build, standalone launch) the autoload stays idle and the badge is
  hidden. It emits `team_brain_state_changed` and `team_main_branch_event`.
- `TeamBranchBadge.gd` is mounted by `TopBar.gd` after the main button strip.
  It is hidden unless a team experiment runs, and forwards live events to
  `BV.UI.notification_system`.
- `TeamBranchText.gd` holds the pure text helpers (badge label, tooltip, event
  line).

Messages are JSON text frames:

- `{"type": "team_brain_state", "team": true, "branch": {"mode": "collaborative" | "fork" | "pending" | "unknown", ...}}`
- `{"type": "team_main_branch_event", "event": {"kind": "master_saved" | "master_replaced" | ..., "actor_display_name": ..., "revision": ...}}`

BV never sends state changes back; replacing the collaborative genome happens
in Neurorobotics Studio.

## Tests

```
godot --headless --path godot_source --script res://BrainVisualizer/UI/Top_Bar/TeamBranch/test_team_branch_text.gd
```
