extends MeshInstance3D
var location = Vector3()
var flagged = false

func _on_visible_on_screen_notifier_3d_screen_entered():
	print(get_node("."), " entered!")


# Comment this out for shader future to resume
#func _on_area_3d_mouse_entered():
#	var material = mesh.surface_get_material(0)
#	print("material: ", material) # material: <ShaderMaterial#-9223372000867646247>
#	material.set_shader_parameter("red_intensity", 1.0)
#	mesh.surface_set_material(0, material)

func _on_area_3d_input_event(_camera, event, _position, _normal, _shape_idx):
	var name_fetch = get_name().rsplit("*")
	if $"../../Windows/Quick_Connect".visible:
		if event is InputEventMouseButton and event.pressed:
			if $"../../Windows/Quick_Connect/source".text == "Select a cortical":
				var cortical_name = FeagiCache.cortical_areas_cache.cortical_areas[name_fetch[0]]
				$"../../Windows/Quick_Connect/source".text = cortical_name.name
				$"..".update_all_node_from_cortical(name_fetch, global_material.glow)
			if $"../../Windows/Quick_Connect/destination".text == "Select a cortical":
				var cortical_name = FeagiCache.cortical_areas_cache.cortical_areas[name_fetch[0]]
				$"../../Windows/Quick_Connect/destination".text = cortical_name.name
				$"..".update_all_node_from_cortical(name_fetch, global_material.destination)
	if event is InputEventMouseButton and event.pressed and Input.is_action_pressed("shift"):
		if event.button_index == 1 and get_surface_override_material(0) == global_material.selected and event.pressed == true:
			if get_surface_override_material(0) == global_material.selected:
				location = Vector3(transform.origin)
				for item in Godot_list.godot_list["data"]["direct_stimulation"][name_fetch[0]]:
					if location == item:
						Godot_list.godot_list["data"]["direct_stimulation"][name_fetch[0]].erase(item)
			set_surface_override_material(0, global_material.deselected)
		elif event.button_index == 1 == true:
			if get_surface_override_material(0) == global_material.white:
				location = Vector3(transform.origin) * Vector3(1,1,-1)
				if Godot_list.godot_list["data"]["direct_stimulation"].get(name_fetch[0]):
					Godot_list.godot_list["data"]["direct_stimulation"][name_fetch[0]].append(location)
				else:
					Godot_list.godot_list["data"]["direct_stimulation"][name_fetch[0]] = []
					Godot_list.godot_list["data"]["direct_stimulation"][name_fetch[0]].append(location)
				
			if get_surface_override_material(0) == global_material.deselected:
				location = Vector3(transform.origin) * Vector3(1,1,-1)
				if Godot_list.godot_list["data"]["direct_stimulation"].get(name_fetch[0]):
					Godot_list.godot_list["data"]["direct_stimulation"][name_fetch[0]].append(location)
				else:
					Godot_list.godot_list["data"]["direct_stimulation"][name_fetch[0]] = []
					Godot_list.godot_list["data"]["direct_stimulation"][name_fetch[0]].append(location)
			set_surface_override_material(0, global_material.selected)
#	elif event is InputEventMouseButton and event.pressed and event.button_index==1:
#		select_cortical.selected.append(get_name())
func _on_area_3d_mouse_entered():
	if get_surface_override_material(0) == global_material.selected:
		set_surface_override_material(0, global_material.selected)
	elif get_surface_override_material(0) == global_material.glow:
		set_surface_override_material(0, global_material.glow)
	elif get_surface_override_material(0) == global_material.destination:
		set_surface_override_material(0, global_material.destination)
	else:
		set_surface_override_material(0, global_material.white)

func _on_area_3d_mouse_exited():
	if get_surface_override_material(0) == global_material.selected:
		set_surface_override_material(0, global_material.selected)
	elif get_surface_override_material(0) == global_material.glow:
		set_surface_override_material(0, global_material.glow)
	elif get_surface_override_material(0) == global_material.destination:
		set_surface_override_material(0, global_material.destination)
	else:
		set_surface_override_material(0, global_material.deselected)

func _input(_event):
	if Input.is_action_just_pressed("del"):
		set_surface_override_material(0, global_material.deselected)
