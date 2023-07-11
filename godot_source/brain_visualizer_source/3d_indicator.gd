extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
		$Cube.set_surface_override_material(0, global_material.glow)
		$Cube001.set_surface_override_material(0, global_material.glow)
		$Cube002.set_surface_override_material(0, global_material.glow)
		print("test: ", network_setting.state)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if network_setting.state == 1:
		$Cube.set_surface_override_material(0, global_material.red)
		$Cube001.set_surface_override_material(0, global_material.red)
		$Cube002.set_surface_override_material(0, global_material.red)
	else:
		$Cube.set_surface_override_material(0, global_material.glow)
		$Cube001.set_surface_override_material(0, global_material.glow)
		$Cube002.set_surface_override_material(0, global_material.glow)
#	if $"../red_voxel".multimesh.instance_count == 0:
#		$Cube.set_surface_override_material(0, global_material.glow)
#		$Cube001.set_surface_override_material(0, global_material.glow)
#		$Cube002.set_surface_override_material(0, global_material.glow)
