extends Resource
class_name FeagiGeneralSettings


@export var seconds_between_latency_pings: float ## The number of seconds between ping attempts to calculate latency
@export var seconds_between_healthcheck_pings: float = 5 ## The number of seconds to wait between healthcheck pings
@export var number_of_times_to_retry_HTTP_connections: int = 5 ## The number of times a HTTP worker should try retrying a connection
@export var number_of_times_to_retry_WS_connections: int = 5 ## The number of times the websocket should attempt to reconnect
@export var allow_developer_menu: bool ## if we should allow the user to open the developer menu
@export var developer_menu_hotkey: Key = Key.KEY_QUOTELEFT ## keyboard key that opens the developer menu # ~, sv_cheats_1, impulse 101
@export var seconds_info_notification: float ## how long to show info notifications
@export var seconds_warning_notification: float ## how long to show warning notifications
@export var seconds_error_notification: float ## how long to show error notifications
