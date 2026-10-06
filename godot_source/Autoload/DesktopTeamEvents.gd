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
