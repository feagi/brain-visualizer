extends Node3D

const camera_snap_offset: Vector3 = Vector3(0.0, 15.0, -25.0)

var shader_material # Wait for shader 
var global_name_list = {}

var _CorticalAreaPreviewPrefab: PackedScene = preload("res://Feagi-Godot-Interface/UI/Brain_Visualizer/CorticalBox/CorticalBoxPreview.tscn")

func _ready():
	FeagiCacheEvents.cortical_area_added.connect(on_cortical_area_added)
#	shader_material = $cortical_area_box.mesh.material # EXPERIMENT
	FeagiEvents.retrieved_visualization_data.connect(test)
	FeagiCacheEvents.cortical_area_removed.connect(delete_single_cortical)
	FeagiCacheEvents.cortical_area_updated.connect(check_cortical) # disabled due to being triggered every click

## Generates and parents a preview and returns the object 
func generate_prism_preview() -> CorticalBoxPreview:
	var preview: CorticalBoxPreview = _CorticalAreaPreviewPrefab.instantiate()
	add_child(preview)
	return preview

## Snaps the camera to a cortical area
func snap_camera_to_cortical_area(cortical_area: CorticalArea) -> void:
	var camera: BVCam = $Camera3D
	var bv_location: Vector3 = cortical_area.BV_position()
	camera.position = cortical_area.BV_position() + camera_snap_offset
	camera.point_camera_at(cortical_area.BV_position())

func on_cortical_area_added(cortical_area: CorticalArea) -> void:
	generate_cortical_area(cortical_area)


func generate_cortical_area(cortical_area_data : CorticalArea):
	var textbox = $blank_textbox.duplicate()
	var viewport = textbox.get_node("SubViewport")
	textbox.scale = Vector3(1,1,1)
	textbox.transform.origin = Vector3(cortical_area_data.coordinates_3D.x + (cortical_area_data.dimensions.x/1.5), cortical_area_data.coordinates_3D.y +1 + cortical_area_data.dimensions.y, -1 * cortical_area_data.dimensions.z - cortical_area_data.coordinates_3D.z)
	textbox.get_node("SubViewport/Label").set_text(str(cortical_area_data.name))
	textbox.set_texture(viewport.get_texture())
	textbox.set_name(cortical_area_data.name + str("_textbox"))
	if not textbox.get_name() in global_name_list:
		global_name_list[textbox.get_name()] = []
	global_name_list[textbox.get_name()].append([textbox])
	if int(cortical_area_data.dimensions.x) * int(cortical_area_data.dimensions.y) * int(cortical_area_data.dimensions.z) < 999: # Prevent massive cortical area
		generate_model(cortical_area_data.cortical_ID, cortical_area_data.coordinates_3D.x,cortical_area_data.coordinates_3D.y,cortical_area_data.coordinates_3D.z,cortical_area_data.dimensions.x, cortical_area_data.dimensions.z, cortical_area_data.dimensions.y)
	else:
		generate_one_model(cortical_area_data.cortical_ID, cortical_area_data.coordinates_3D.x,cortical_area_data.coordinates_3D.y,cortical_area_data.coordinates_3D.z,cortical_area_data.dimensions.x, cortical_area_data.dimensions.z, cortical_area_data.dimensions.y)
# Uncomment below for the new approach to reduce the CPU usuage
#	var new_node = $cortical_area_box.duplicate() # Duplicate node
#	new_node.visible = true
#	new_node.set_name(cortical_area_data.cortical_ID)
#	new_node.scale = cortical_area_data.dimensions
#	new_node.transform.origin = Vector3((cortical_area_data.dimensions.x/2 + cortical_area_data.coordinates_3D.x),(cortical_area_data.dimensions.y/2 + cortical_area_data.coordinates_3D.y), -1 * (cortical_area_data.dimensions.z/2 + cortical_area_data.coordinates_3D.z))
#	add_child(new_node)
	add_child(textbox)

func generate_one_model(name_input, x_input, y_input, z_input, width_input, depth_input, height_input):
	var new = $cortical_area_box.duplicate() # Duplicate node
	new.visible = true
	new.set_name(name_input)
	add_child(new)
	new.visible = true
	new.scale = Vector3(width_input, height_input, depth_input)
	name_input = name_input.replace(" ", "")
	if not name_input in global_name_list:
		global_name_list[name_input] = []
	global_name_list[name_input].append([new, x_input, y_input, z_input, width_input, depth_input, height_input])
	new.transform.origin = Vector3(width_input/2 + int(x_input), height_input/2+ int(y_input), -1 * (depth_input/2 + int(z_input)))

func generate_model(name_input, x_input, y_input, z_input, width_input, depth_input, height_input):
	var counter = 0
	for x_gain in width_input:
		for y_gain in height_input:
			for z_gain in depth_input:
				if x_gain == 0 or x_gain == (int(width_input)-1) or y_gain == 0 or y_gain == (int(height_input) - 1) or z_gain == 0 or z_gain == (int(depth_input) - 1):
					var new = $cortical_area_box.duplicate() # Duplicate node
					new.visible = true
					new.set_name(name_input+ "*" + str(counter))
					add_child(new)
					new.visible = true
					if not name_input in global_name_list:
						global_name_list[name_input] = []
					global_name_list[name_input].append([new, x_input, y_input, z_input, width_input, depth_input, height_input])
					new.transform.origin = Vector3(x_gain+int(x_input), y_gain+int(y_input), -1 * (z_gain+int(z_input)))
					counter += 1

func test(stored_value):
	if stored_value == null: # Checks if it's null. When it is, it clear red voxels
		$red_voxel.multimesh.instance_count = 0
		$red_voxel.multimesh.visible_instance_count = 0
		return # skip the function
	var total = stored_value.size() # Fetch the full length of array
	$red_voxel.multimesh.instance_count = total
	$red_voxel.multimesh.visible_instance_count = total
	for flag in range(total): # Not sure if this helps? It helped in some ways but meh.Is there better one?
		var voxel_data = stored_value[flag]
		var new_position = Transform3D().translated(Vector3(voxel_data[0], voxel_data[1], -voxel_data[2]))
		$red_voxel.multimesh.set_instance_transform(flag, new_position)

func _clear_node_name_list(node_name):
	"""
	clear all cortical area along with the library list/dict
	"""
	for key in Godot_list.godot_list["data"]["direct_stimulation"]:
		Godot_list.godot_list["data"]["direct_stimulation"][key] = []
	var list = node_name
	if list.is_empty() != true:
		var list_size = global_name_list.size()
		for i in list_size:
			for iteration_name in global_name_list[i]:
				global_name_list[i][iteration_name][0].queue_free()
		global_name_list = {}

func update_all_node_from_cortical(name_input, material):
	for i in global_name_list:
		if name_input in i:
			for x in len(global_name_list[i]):
				global_name_list[i][x][0].set_surface_override_material(0, material)

func delete_single_cortical(cortical_area_data : CorticalArea):
	var name_list : Array = [] # To get cortical name
	var cortical_text = cortical_area_data.name + "_textbox"
	for i in global_name_list:
		if cortical_area_data.cortical_ID in i or cortical_text in i:
			for x in len(global_name_list[i]):
				remove_child(global_name_list[i][x][0])
				global_name_list[i][x][0].queue_free()
			name_list.append(i)
	for i in name_list:
		global_name_list.erase(i)
	
func demo_new_cortical():
	"""
	This is for add new cortical area so the name will be updated when you move it around. This is designed to use
	the duplicated node called "example", so if it has no name, it will display as "example" but if
	it has a letter or name, it will display as the user typed.
	"""
	for i in global_name_list:
		if "example" in i:
			for x in len(global_name_list[i]):
				if global_name_list[i][x][0].get_child(0).get_class() == "Viewport":
					global_name_list[i][x][0].get_child(0).get_child(0).text = "example"

func delete_example():
	"""For the cortical named "example" only"""
	var name_list : Array = [] # To get cortical name
	for i in global_name_list:
		if "example" in i or "example_textbox" in i:
			for x in len(global_name_list[i]):
				remove_child(global_name_list[i][x][0])
				global_name_list[i][x][0].queue_free()
			name_list.append(i)
	for i in name_list:
		global_name_list.erase(i)

func check_cortical(cortical_area_data : CorticalArea):
	var flag = false
	for i in global_name_list:
		if cortical_area_data.cortical_ID in i:
			for x in range(1, 6):
				if x == 1:
					if not global_name_list[i][0][x] == cortical_area_data.coordinates_3D[0]:
						flag = true
				elif x == 2:
					if not global_name_list[i][0][x] == cortical_area_data.coordinates_3D[1]:
						flag = true
				elif x == 3:
					if not global_name_list[i][0][x] == cortical_area_data.coordinates_3D[2]:
						flag = true
				elif x == 4:
					if not global_name_list[i][0][x] == cortical_area_data.dimensions[0]:
						flag = true
				elif x == 5:
					if not global_name_list[i][0][x] == cortical_area_data.dimensions[2]:
						flag = true
				elif x == 6:
					if not global_name_list[i][0][x] == cortical_area_data.dimensions[1]:
						flag = true
	if flag:
		delete_single_cortical(cortical_area_data)
		for i in global_name_list:
			if cortical_area_data.cortical_ID in i:
				print(global_name_list[i])
		generate_cortical_area(cortical_area_data)

func generate_single_cortical(x,y,z,width, depth, height, name_input):
	"""Function for create cortical, import circuit"""
	delete_example()
	var textbox = $blank_textbox.duplicate()
	var viewport = textbox.get_node("SubViewport")
	textbox.scale = Vector3(1,1,1)
	textbox.transform.origin = Vector3(x + (width/1.5), y +1 + height, -1 * depth - z)
	textbox.set_name("example_textbox")
	textbox.get_node("SubViewport/Label").set_text(str(name_input))
	textbox.set_texture(viewport.get_texture())
	if not "example_textbox" in global_name_list:
		global_name_list["example_textbox"] =[]
	global_name_list["example_textbox"].append([textbox, x, y, z, width, depth, height])
	generate_one_model(name_input, x,y,z,width, depth, height)
	add_child(textbox)
	demo_new_cortical()
