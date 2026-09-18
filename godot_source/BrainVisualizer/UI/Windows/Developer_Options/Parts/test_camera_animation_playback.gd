extends SceneTree
## Playback contract for camera animation tracks under Godot 4.7 AnimationMixer.
## Mirrors [method WindowDeveloperOptionsPartCameraAnimations.build_camera_transform_animation]
## and sibling-player path resolution without loading BV autoloads.
## Run: godot --headless -s res://BrainVisualizer/UI/Windows/Developer_Options/Parts/test_camera_animation_playback.gd


func _initialize() -> void:
	var failures: int = 0
	failures += _test_build_animation_keys_and_length()
	failures += _test_sibling_player_resolves_camera_path()
	failures += _test_playback_moves_camera()
	if failures == 0:
		print("Camera animation playback tests: PASS")
		quit(0)
	else:
		push_error("Camera animation playback tests: FAIL (%d)" % failures)
		quit(1)


func _sample_frames() -> Array[Dictionary]:
	return [
		{"position": [0.0, 0.0, 0.0], "rotation": [0.0, 0.0, 0.0, 1.0], "time": 1.0},
		{"position": [10.0, 0.0, 0.0], "rotation": [0.0, 0.0, 0.0, 1.0], "time": 1.0},
	]


func _build_camera_transform_animation(
	frames: Array[Dictionary],
	start_index: int,
	track_path: NodePath,
	lin_interp: Animation.InterpolationType,
	rot_interp: Animation.InterpolationType
) -> Animation:
	var generated_animation: Animation = Animation.new()
	generated_animation.add_track(Animation.TrackType.TYPE_POSITION_3D, 0)
	generated_animation.add_track(Animation.TrackType.TYPE_ROTATION_3D, 1)
	generated_animation.track_set_path(0, track_path)
	generated_animation.track_set_path(1, track_path)
	var frame_time: float = 0.0
	for i in range(start_index, frames.size()):
		var frame: Dictionary = frames[i]
		var pos_arr: Array = frame["position"]
		var rot_arr: Array = frame["rotation"]
		generated_animation.position_track_insert_key(
			0,
			frame_time,
			Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		)
		generated_animation.rotation_track_insert_key(
			1,
			frame_time,
			Quaternion(float(rot_arr[0]), float(rot_arr[1]), float(rot_arr[2]), float(rot_arr[3]))
		)
		frame_time += float(frame["time"])
	generated_animation.length = frame_time
	generated_animation.track_set_interpolation_type(0, lin_interp)
	generated_animation.track_set_interpolation_type(1, rot_interp)
	return generated_animation


func _resolve_camera_track_path(player: AnimationPlayer, camera: Node3D) -> NodePath:
	if player == null or camera == null:
		return NodePath()
	var resolved_root: Node = player.get_node_or_null(player.root_node)
	if resolved_root == null:
		return NodePath()
	return resolved_root.get_path_to(camera)


func _test_build_animation_keys_and_length() -> int:
	var animation: Animation = _build_camera_transform_animation(
		_sample_frames(),
		0,
		NodePath("PancakeCam"),
		Animation.INTERPOLATION_LINEAR,
		Animation.INTERPOLATION_LINEAR
	)
	if animation.get_track_count() != 2:
		push_error("expected 2 tracks, got %d" % animation.get_track_count())
		return 1
	if animation.track_get_path(0) != NodePath("PancakeCam"):
		push_error("position track path was %s" % str(animation.track_get_path(0)))
		return 1
	if animation.track_get_key_count(0) != 2:
		push_error("expected 2 position keys, got %d" % animation.track_get_key_count(0))
		return 1
	if not is_equal_approx(animation.length, 2.0):
		push_error("expected length 2.0, got %s" % str(animation.length))
		return 1
	return 0


func _test_sibling_player_resolves_camera_path() -> int:
	var host := Node3D.new()
	host.name = "Center"
	var camera := Camera3D.new()
	camera.name = "PancakeCam"
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(host)
	host.add_child(camera)
	host.add_child(player)
	player.root_node = NodePath("..")
	var track_path: NodePath = _resolve_camera_track_path(player, camera)
	host.free()
	if track_path != NodePath("PancakeCam"):
		push_error("expected PancakeCam track path, got %s" % str(track_path))
		return 1
	return 0


func _test_playback_moves_camera() -> int:
	var host := Node3D.new()
	host.name = "Center"
	var camera := Camera3D.new()
	camera.name = "PancakeCam"
	camera.position = Vector3.ZERO
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(host)
	host.add_child(camera)
	host.add_child(player)
	player.root_node = NodePath("..")
	var track_path: NodePath = _resolve_camera_track_path(player, camera)
	var animation: Animation = _build_camera_transform_animation(
		_sample_frames(),
		0,
		track_path,
		Animation.INTERPOLATION_LINEAR,
		Animation.INTERPOLATION_LINEAR
	)
	var lib := AnimationLibrary.new()
	if not player.has_animation_library(&""):
		player.add_animation_library(&"", lib)
	else:
		lib = player.get_animation_library(&"")
	lib.add_animation(&"DEV_CAM_PATH", animation)
	player.clear_caches()
	player.play(&"DEV_CAM_PATH")
	player.advance(1.0)
	var moved_x: float = camera.position.x
	host.free()
	if moved_x <= 4.0:
		push_error("expected camera to move along X after 1s, got %s" % str(moved_x))
		return 1
	return 0
