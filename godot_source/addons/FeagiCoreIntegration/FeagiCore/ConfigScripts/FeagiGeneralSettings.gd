extends Resource
class_name FeagiGeneralSettings


@export var seconds_between_latency_pings: float ## The number of seconds between ping attempts to calculate latency
@export var seconds_between_healthcheck_pings: float = 5 ## The number of seconds to wait between healthcheck pings
@export var number_of_times_to_retry_HTTP_connections: int = 5 ## The number of times a HTTP worker should try retrying a connection
@export var number_of_times_to_retry_WS_connections: int = 5 ## The number of times the websocket should attempt to reconnect
@export var allow_developer_menu: bool ## if we should allow the user to open the developer menu
@export var developer_menu_hotkey: Key = Key.KEY_QUOTELEFT ## keyboard key that opens the developer menu # ~, sv_cheats_1, impulse 101
@export var seconds_between_agent_heartbeats: float ## Seconds between heartbeats BV sends FEAGI to stay registered; also how often the liveness watcher checks the session. Must be > 0
@export var max_missed_agent_heartbeat_acks: int ## Consecutive heartbeat intervals without a FEAGI ack before the session counts as dead and BV re-registers. Must be > 0
@export var seconds_info_notification: float ## how long to show info notifications
@export var seconds_warning_notification: float ## how long to show warning notifications
@export var seconds_error_notification: float ## how long to show error notifications
@export var agent_descriptor_b64: String = "" ## 48-byte agent descriptor (base64) for legacy FEAGI agent registration
@export var auth_token_b64: String = "" ## 32-byte auth token (base64) for legacy FEAGI agent registration
## Which FEAGI generation to talk to. "auto" probes the server at connect time; env FEAGI_PROTOCOL overrides.
@export_enum("auto", "legacy", "zenoh") var feagi_protocol: String = "auto"

## Returns an error message when the agent heartbeat settings cannot drive a session, or "" when they are valid.
## Both values come from config; there are no defaults, so an unset (0) value is an error.
static func validate_agent_heartbeat_settings(seconds_between_heartbeats: float, max_missed_acks: int) -> String:
	if not is_finite(seconds_between_heartbeats) or seconds_between_heartbeats <= 0.0:
		return "seconds_between_agent_heartbeats must be a finite number > 0 (got %s)" % seconds_between_heartbeats
	if max_missed_acks <= 0:
		return "max_missed_agent_heartbeat_acks must be > 0 (got %d)" % max_missed_acks
	return ""
