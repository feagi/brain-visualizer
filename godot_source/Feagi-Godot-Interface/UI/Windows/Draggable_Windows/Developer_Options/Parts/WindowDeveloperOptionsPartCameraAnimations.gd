extends VBoxContainer
class_name WindowDeveloperOptionsPartCameraAnimations # Microsoft would be proud

var _camera: BVCam
var _stored_positions: Array[Vector3] = []
var _stored_rotations: Array[Quaternion] = []
var _stored_times: Array[float] = []

func _ready() -> void:
	_camera = get_node("/root/FeagiRoot/UI/Brain_Visualizer/Camera3D")

func clear_stored_data() -> void:
	var counter: IntInput = $HBoxContainer/num_animation_points
	_stored_positions = []
	_stored_rotations = []
	_stored_times = []
	counter.current_int = 0

func add_frame() -> void:
	_append_camera_transform(_camera.position, _camera.quaternion)

func export_into_json() -> void:
	var text_node: TextEdit = $AnimationSave
	var output_arr: Array = []
	
	for i in len(_stored_positions):
		output_arr.append(_export_index_as_dict(i))
	var json: StringName = JSON.stringify(output_arr)
	text_node.text = json

func execute_json() -> void:
	var text_node: TextEdit = $AnimationSave
	var json = text_node.text
	
	# Verify
	if JSON.parse_string(json) ==  null:
		VisConfig.UI_manager.make_notification("Unable to parse JSON!")
		return
	var input_frames: Array = JSON.parse_string(json)
	var num_frames: int = len(input_frames)
	for i in num_frames:
		var frame: Dictionary = input_frames[i]
		if "position" not in frame.keys():
			VisConfig.UI_manager.make_notification("Missing 'position' in frame %i!" % i)
			return
		if "rotation" not in frame.keys():
			VisConfig.UI_manager.make_notification("Missing 'rotation' in frame %i!" % i)
			return
		if "time" not in frame.keys():
			VisConfig.UI_manager.make_notification("Missing 'time' in frame %i!" % i)
			return
		#TODO better checks
	
	# Generate animation
	var generated_animation: Animation = Animation.new()
	generated_animation.add_track(Animation.TrackType.TYPE_POSITION_3D, 0)
	generated_animation.add_track(Animation.TrackType.TYPE_ROTATION_3D, 1)
	generated_animation.track_set_path(0, _camera.get_path())
	generated_animation.track_set_path(1, _camera.get_path())
	
	var frame_pos: Vector3
	var frame_rot: Quaternion
	var frame_time: float = 0.0
	
	for i in num_frames:
		var frame: Dictionary = input_frames[i]
		frame_pos = FEAGIUtils.untyped_array_to_vector3(frame["position"])
		frame_rot = FEAGIUtils.untyped_array_to_quaternion(frame["rotation"])
		generated_animation.position_track_insert_key(0, frame_time, frame_pos)
		generated_animation.rotation_track_insert_key(1, frame_time, frame_rot)
		frame_time += frame["time"]
		
	generated_animation.length = frame_time
	var lin_interp_option: OptionButton = $HBoxContainer2/move_interp
	var rot_interp_option: OptionButton = $HBoxContainer3/rot_interp
	var lin_interp: Animation.InterpolationType = lin_interp_option.get_selected_id() as Animation.InterpolationType
	var rot_interp: Animation.InterpolationType = rot_interp_option.get_selected_id() as Animation.InterpolationType
	generated_animation.track_set_interpolation_type(0, lin_interp)
	generated_animation.track_set_interpolation_type(1, rot_interp)
	
	_camera.play_animation(generated_animation)

func _append_camera_transform(cam_position: Vector3, cam_rotation: Quaternion) -> void:
	var tran_time_node: FloatInput = $transition_time
	var counter: IntInput = $HBoxContainer/num_animation_points
	_stored_positions.append(cam_position)
	_stored_rotations.append(cam_rotation)
	_stored_times.append(tran_time_node.current_float)
	counter.current_int += 1

func _export_index_as_dict(index: int) -> Dictionary:
	return {
		"position": FEAGIUtils.vector3_to_array(_stored_positions[index]),
		"rotation": FEAGIUtils.quaternion_to_array(_stored_rotations[index]),
		"time": _stored_times[index]
	}
