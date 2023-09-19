extends Node3D

var flag_once = true
var a = NetworkInterface.new()

# Called when the node enters the scene tree for the first time.
func _ready():
		$Cube.set_surface_override_material(0, global_material.glow)
		$Cube001.set_surface_override_material(0, global_material.glow)
		$Cube002.set_surface_override_material(0, global_material.glow)
		if a.current_websocket_state == 1:
			if flag_once:
				flag_once = false
				$Cube.set_surface_override_material(0, global_material.red)
				$Cube001.set_surface_override_material(0, global_material.red)
				$Cube002.set_surface_override_material(0, global_material.red)
			else:
				$Cube.set_surface_override_material(0, global_material.glow)
				$Cube001.set_surface_override_material(0, global_material.glow)
				$Cube002.set_surface_override_material(0, global_material.glow)

### Delete this once you verify that the status is changed or updated.
func _process(delta):
	print(a.current_websocket_state)
