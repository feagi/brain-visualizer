# Genome change history

While a team experiment is on the collaborative genome, Brain Visualizer keeps a
history of structural changes from this member and from teammates.

## Design

feagi-desktop is the source of truth. Brain Visualizer only displays it:

- `Autoload/DesktopTeamEvents.gd` connects to the loopback WebSocket that
  feagi-desktop serves (`commands/team_bv_events.rs`). The URL and reconnect
  delay come from `FEAGI_DESKTOP_EVENTS_WS_URL` and
  `FEAGI_DESKTOP_EVENTS_RECONNECT_SECONDS`, set by the desktop at launch. Without
  them (web build, standalone launch) the autoload stays idle.
- `GenomeHistoryButton` is mounted by `TopBar.gd` immediately before Settings.
  One chip on the bottom-right of the icon shows the combined count since the
  history window was closed. The chip stays blue when every change is yours and
  turns yellow when anyone else has changes. Its tooltip lists your count, then
  one line per other person. Opening the window clears the chip. Closing it
  starts the count again. The window lists every change from this session,
  newest first.
- The list is FEAGI's change ledger (`GET /v1/genome/changes`). FeagiCore reads
  it whenever the repeating health check sees `genome_change_sequence` move,
  including edits made after connect. Creating or deleting an input stays in
  this list; it is still not copied to teammates.
- `WindowGenomeChangeHistory` is the table (Time, Who, Action, Target). It opens
  wide enough for those columns and the right edge, bottom edge, and corner
  resize it. Columns are Time, Who, Target, then Action. Who is bold. The
  cortical name keeps its own color at the normal weight.
  An update names each property that changed, with the previous value and the new one.
  Cortical ids are not shown; the row uses the area name from the change, or
  the live name when the ledger only stored an id. `TeamBranchText.gd` holds
  the row text and the chip count.

Messages are JSON text frames:

- `{"type": "team_brain_state", "team": true, "branch": {"mode": "collaborative" | "fork" | "pending" | "unknown", ...}}`
- `{"type": "team_main_branch_event", "event": {"kind": "genome_change" | "genome_change_rejected" | "genome_change_gap" | ..., "actor_display_name": ..., "operation": ..., "target_id": ..., "timestamp_ms": ...}}`

BV never sends state changes back.

## Tests

```
godot --headless --path godot_source --script res://BrainVisualizer/UI/Top_Bar/TeamBranch/test_team_branch_text.gd
```
