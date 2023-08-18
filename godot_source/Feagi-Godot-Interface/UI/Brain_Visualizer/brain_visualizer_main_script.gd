extends Node3D
var _shaderMat # EXPERIMENT
# Called when the node enters the scene tree for the first time.
func _ready():
#	FeagiCacheEvents.cortical_area_added.connect(on_cortical_area_added)
	_shaderMat = $cortical_area_box.mesh.material # EXPERIMENT
	FeagiEvents.retrieved_visualization_data.connect(test)

#func on_cortical_area_added(cortical_area: CorticalArea) -> void:
#	generate_cortical_area(cortical_area)

func generate_cortical_area(cortical_area_data : CorticalArea):
	var new_node = $cortical_area_box.duplicate()
	new_node.visible = true
	new_node.set_name(cortical_area_data.name)
	new_node.scale = cortical_area_data.dimensions
	new_node.transform.origin = Vector3((cortical_area_data.dimensions.x/2 + cortical_area_data.coordinates_3D.x),(cortical_area_data.dimensions.y/2 + cortical_area_data.coordinates_3D.y), -1 * (cortical_area_data.dimensions.z/2 + cortical_area_data.coordinates_3D.z))
	add_child(new_node)

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

