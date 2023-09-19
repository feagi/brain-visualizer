extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	FeagiRequests.feagi_interface.net.socket_state_changed.connect(toggle_between_states)

func toggle_between_states(connection_state: WebSocketPeer.State) -> void:
	match(connection_state):
		WebSocketPeer.STATE_OPEN:
			draw_connected()
		WebSocketPeer.STATE_CLOSED:
			draw_disconnected()

func draw_disconnected():
	$Cube.set_surface_override_material(0, global_material.glow)
	$Cube001.set_surface_override_material(0, global_material.glow)
	$Cube002.set_surface_override_material(0, global_material.glow)

func draw_connected():
	$Cube.set_surface_override_material(0, global_material.red)
	$Cube001.set_surface_override_material(0, global_material.red)
	$Cube002.set_surface_override_material(0, global_material.red)


