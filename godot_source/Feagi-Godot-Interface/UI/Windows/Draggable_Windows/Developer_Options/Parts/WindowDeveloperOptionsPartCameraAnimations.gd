extends VBoxContainer
class_name WindowDeveloperOptionsPartCameraAnimations # Microsoft would be proud

var _stored_positions: Array[Vector3] = []
var _stored_rotations: Array[Vector3] = []
var _stored_times: Array[float] = []

func clear_stored_data() -> void:
	var counter: IntInput = $HBoxContainer/num_animation_points
	_stored_positions = []
	_stored_rotations = []
	_stored_times = []
	counter.current_int = 0
	

func append_camera_transform(cam_position: Vector3, cam_euclidean_rotation: Vector3) -> void:
	var tran_time_node: FloatInput = $initial_float
	var counter: IntInput = $HBoxContainer/num_animation_points
	_stored_positions.append(cam_position)
	_stored_rotations.append(cam_euclidean_rotation)
	_stored_times.append(tran_time_node.current_float)
	counter.current_int += 1
	

func export_into_json() -> void:
	var text_node: TextEdit = $AnimationSave
	var output_arr: Array = []
	
	for i in len(_stored_positions):
		output_arr.append(_export_index_as_dict(i))
	var json: StringName = JSON.stringify(output_arr)
	text_node.text = json


func _export_index_as_dict(index: int) -> Dictionary:
	return {
		"position": FEAGIUtils.vector3_to_array(_stored_positions[index]),
		"rotation": FEAGIUtils.vector3_to_array(_stored_rotations[index]),
		"time": _stored_times[index]
	}
