extends MeshInstance3D
var location = Vector3()
var flagged = false

var _ui_manager: UIManager

func _ready() -> void:
	_ui_manager = get_node("/root/BrainVisualizer/UIManager") as UIManager

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
	var cortical_area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[name_fetch[0]]
	
	if event is InputEventMouseMotion:
		if cortical_area.neuron_count < 999:
			BV.BM.notate_highlighted_neuron(cortical_area, (Vector3i(transform.origin) * Vector3i(1,1,-1)) - cortical_area.coordinates_3D)
	
	if event is InputEventMouseButton and event.pressed and Input.is_action_pressed("shift") and (BV.BM.limit_neuron_selection_to_cortical_area == null or BV.BM.limit_neuron_selection_to_cortical_area == cortical_area):
		var added: bool
		if event.button_index == 1 and get_surface_override_material(0) == global_material.selected and event.pressed == true:
			added = false
			if get_surface_override_material(0) == global_material.selected:
				location = Vector3(transform.origin) * Vector3(1,1,-1)
				for item in Godot_list.godot_list["data"]["direct_stimulation"][name_fetch[0]]:
					if location == item:
						Godot_list.godot_list["data"]["direct_stimulation"][name_fetch[0]].erase(item)
			set_surface_override_material(0, global_material.deselected)
		elif event.button_index == 1 == true: # lol
			added = true
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
		BV.BM.voxel_selected_to_list.emit(cortical_area, (Vector3i(transform.origin) * Vector3i(1,1,-1)) - cortical_area.coordinates_3D, added)
	elif event is InputEventMouseButton and event.pressed and event.button_index== MOUSE_BUTTON_LEFT:

		var selected: Array[GenomeObject] = [cortical_area]
		BV.UI.selection_system.clear_all_highlighted()
		BV.UI.selection_system.add_to_highlighted(cortical_area)
		BV.UI.selection_system.select_objects(SelectionSystem.SOURCE_CONTEXT.FROM_BRAIN_MONITOR)
		BV.UI.selection_system.cortical_area_voxel_clicked(cortical_area, (Vector3i(transform.origin) * Vector3i(1,1,-1)) - cortical_area.coordinates_3D)
		

func _on_area_3d_mouse_entered():
	#$"../Camera3D".disable_mouse_control = true
	if get_surface_override_material(0) == global_material.selected:
		set_surface_override_material(0, global_material.selected)
	elif get_surface_override_material(0) == global_material.glow:
		set_surface_override_material(0, global_material.glow)
	elif get_surface_override_material(0) == global_material.destination:
		set_surface_override_material(0, global_material.destination)
	else:
		set_surface_override_material(0, global_material.white)

func _on_area_3d_mouse_exited():
	#$"../Camera3D".disable_mouse_control = false
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

func clear():
	set_surface_override_material(0, global_material.deselected)
