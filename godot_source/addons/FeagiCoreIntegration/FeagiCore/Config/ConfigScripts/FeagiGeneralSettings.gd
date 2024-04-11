extends Resource
class_name FeagiGeneralSettings

enum POLL_WEBSOCKET_BEHAVIOR {
	NO_POLLING,
	POLL_IF_GENOME_LOADED,
	ALWAYS_POLL
}

@export var connect_even_if_no_genome: bool ## Continue connecting if healthcheck returns but genome is stated as not loaded
@export var websocket_dropping_means_disconnect: bool ## If any websocket dropping should cause a disconnection
@export var attempt_connect_websocket_on_launch: bool # During initial connection to HTTP, if we should also connect to websocket
@export var load_genome_on_connect_if_available: bool ## If genome should automatically be loaded into cache if genome is available
@export var poll_websocket_connection_if_no_websocket: POLL_WEBSOCKET_BEHAVIOR ## In the case websocket is down, how / if we should try to reconnect
@export var seconds_between_latency_pings: float ## The number of seconds between ping attempts to calculate latency
@export var enable_HTTP_healthcheck: bool ## if we should occasionally ping the FEAGI health endpoint
