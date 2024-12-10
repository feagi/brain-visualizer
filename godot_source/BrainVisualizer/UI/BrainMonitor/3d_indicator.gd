extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	FeagiCore.network.websocket_API.FEAGI_socket_health_changed.connect(toggle_between_states)
	draw_disconnected() # lol

func toggle_between_states(_prev_state: FEAGIWebSocketAPI.WEBSOCKET_HEALTH, connection_state: FEAGIWebSocketAPI.WEBSOCKET_HEALTH) -> void:
	match(connection_state):
		FEAGIWebSocketAPI.WEBSOCKET_HEALTH.CONNECTED:
			draw_connected()
		FEAGIWebSocketAPI.WEBSOCKET_HEALTH.NO_CONNECTION:
			draw_disconnected()

func draw_disconnected():
	$Cube.set_surface_override_material(0, global_material.websocket_status)
	$Cube001.set_surface_override_material(0, global_material.websocket_status)
	$Cube002.set_surface_override_material(0, global_material.websocket_status)

func draw_connected():
	$Cube.set_surface_override_material(0, global_material.websocket_status_red)
	$Cube001.set_surface_override_material(0, global_material.websocket_status_red)
	$Cube002.set_surface_override_material(0, global_material.websocket_status_red)
