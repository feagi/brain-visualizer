extends MeshInstance3D

func _on_visible_on_screen_notifier_3d_screen_entered():
	print(get_node("."), " entered!")



func _on_area_3d_mouse_entered():
	var material = mesh.surface_get_material(0)
	print("material: ", material) # material: <ShaderMaterial#-9223372000867646247>
	material.set_shader_parameter("red_intensity", 1.0)
	mesh.surface_set_material(0, material)
