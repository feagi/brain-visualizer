extends Node
## Team experiment events from feagi-desktop (branch badge, live teammate changes).
##
## feagi-desktop is the source of truth for whether the running team experiment is
## on the collaborative genome or an independent fork. When it launches Brain
## Visualizer it sets FEAGI_DESKTOP_EVENTS_WS_URL (a loopback WebSocket) and
## FEAGI_DESKTOP_EVENTS_RECONNECT_SECONDS. Without them (web build, standalone
## launch) this node stays idle and no badge is shown.
##
## Messages (JSON text frames):
## - {"type": "team_brain_state", "team": bool, "branch": {"mode": ...}}
## - {"type": "team_main_branch_event", "event": {...}}

signal team_brain_state_changed(state: Dictionary)
signal team_main_branch_event(event: Dictionary)
signal change_history_changed

## Genome changes received this session, oldest first. Includes this member and teammates.
var change_history: Array[Dictionary] = []
## This member's changes since the history window was last closed.
var unseen_own_count: int = 0
## Teammates' changes since the history window was last closed.
var unseen_other_count: int = 0
## Unseen changes by display name since the history window was last closed. Includes "You".
var unseen_by_actor: Dictionary = {}
## Own plus teammate counts. Kept so older callers can read one total.
var unseen_change_count: int = 0
## True while the history window is on screen. Changes in that time are listed, not counted.
var history_window_open: bool = false
## Last FEAGI ledger sequence already copied into [member change_history].
var ledger_cursor: int = 0

const URL_ENV: String = "FEAGI_DESKTOP_EVENTS_WS_URL"
const RECONNECT_ENV: String = "FEAGI_DESKTOP_EVENTS_RECONNECT_SECONDS"

## Last branch state received; empty until the desktop sends one.
var latest_state: Dictionary = {}

var _url: String = ""
var _reconnect_seconds: float = 0.0
var _socket: WebSocketPeer = null
var _retry_in: float = 0.0


func _ready() -> void:
	_url = OS.get_environment(URL_ENV).strip_edges()
	if _url == "":
		set_process(false)
		return
	var raw_reconnect: String = OS.get_environment(RECONNECT_ENV).strip_edges()
	if not raw_reconnect.is_valid_float() or float(raw_reconnect) <= 0.0:
		push_error("[DesktopTeamEvents] %s must be a positive number when %s is set" % [RECONNECT_ENV, URL_ENV])
		set_process(false)
		return
	_reconnect_seconds = float(raw_reconnect)
	_open()


func _open() -> void:
	_socket = WebSocketPeer.new()
	var error: int = _socket.connect_to_url(_url)
	if error != OK:
		push_warning("[DesktopTeamEvents] Could not connect to %s (error %d)" % [_url, error])
		_schedule_retry()


func _schedule_retry() -> void:
	_socket = null
	_retry_in = _reconnect_seconds


func _process(delta: float) -> void:
	if _socket == null:
		_retry_in -= delta
		if _retry_in <= 0.0:
			_open()
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while _socket.get_available_packet_count() > 0:
				handle_message(_socket.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			_schedule_retry()


## Dispatch one desktop message. Public so it can be exercised without a socket.
func handle_message(text: String) -> void:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var message: Dictionary = parsed
	match str(message.get("type", "")):
		"team_brain_state":
			latest_state = message
			team_brain_state_changed.emit(message)
		"team_main_branch_event":
			var event = message.get("event")
			if typeof(event) == TYPE_DICTIONARY:
				team_main_branch_event.emit(event)


## Append ledger rows newer than [member ledger_cursor]. Returns the number added.
## Counts rise only while the history window is closed, split into this member and teammates.
func append_ledger_events(events: Array, latest_sequence: int) -> int:
	if latest_sequence > ledger_cursor:
		ledger_cursor = latest_sequence
	if events.is_empty():
		return 0
	var added := 0
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		change_history.append(event)
		added += 1
		if history_window_open:
			continue
		var actor := _actor_label(event)
		unseen_by_actor[actor] = int(unseen_by_actor.get(actor, 0)) + 1
		if actor == "You":
			unseen_own_count += 1
		else:
			unseen_other_count += 1
	_sync_unseen_total()
	change_history_changed.emit()
	return added


## The history window just opened. Chips go back to empty until it closes.
func mark_change_history_seen() -> void:
	history_window_open = true
	if unseen_own_count == 0 and unseen_other_count == 0 and unseen_by_actor.is_empty():
		return
	unseen_own_count = 0
	unseen_other_count = 0
	unseen_by_actor.clear()
	_sync_unseen_total()
	change_history_changed.emit()


## The history window just closed. Later ledger rows are what the chips count.
func mark_history_window_closed() -> void:
	history_window_open = false


func _is_own_change(event: Dictionary) -> bool:
	if event.has("mine"):
		return bool(event["mine"])
	return str(event.get("actor_display_name", "")) == "You"


func _actor_label(event: Dictionary) -> String:
	if _is_own_change(event):
		return "You"
	var actor := str(event.get("actor_display_name", "")).strip_edges()
	if actor == "" or actor == "<null>":
		return "A teammate"
	return actor


func _sync_unseen_total() -> void:
	unseen_change_count = unseen_own_count + unseen_other_count
