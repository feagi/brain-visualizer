extends VBoxContainer
class_name WindowDeveloperOptionsPartCameraAnimations # Microsoft would be proud

const _PLAY_DISABLED_TOOLTIP: String = "Animation data missing."
const _DEV_CAM_ANIMATION_NAME: StringName = "DEV_CAM_PATH"
const _PERSISTED_JSON_META_KEY: StringName = &"camera_animation_json_cache"
static var _persisted_animation_json_cache: String = ""

var _camera: Camera3D
var _stored_positions: Array[Vector3] = []
var _stored_rotations: Array[Quaternion] = []
var _stored_times: Array[float] = []
var _presentation_frames: Array[Dictionary] = []
var _presentation_current_index: int = 0
var _presentation_mode_active: bool = false
var _presentation_is_playing_timed: bool = false
var _timed_playback_start_index: int = 0
var _presentation_initial_camera_position: Vector3 = Vector3.ZERO
var _presentation_initial_camera_rotation: Quaternion = Quaternion.IDENTITY
var _has_presentation_initial_camera_pose: bool = false
var _hidden_host_window: Control = null
var _presentation_close_in_progress: bool = false
var _suppress_json_cache_writes: bool = false

var _animation_save: TextEdit
var _play_button: Button

func _ready() -> void:
	_animation_save = $AnimationSave
	_play_button = $Play
	if _animation_save != null:
		var restored_json: String = _load_persisted_animation_json_cache()
		if not restored_json.is_empty():
			_animation_save.text = restored_json
	if _animation_save != null and not _animation_save.text_changed.is_connected(_on_animation_save_text_changed):
		_animation_save.text_changed.connect(_on_animation_save_text_changed)
	# [method WindowCameraAnimations.setup] may set the camera after this; only fall back to the active monitor if unset.
	call_deferred("_ensure_default_camera_if_unset")
	_sync_action_button_states()


func _ensure_default_camera_if_unset() -> void:
	if _camera != null:
		return
	configure_from_brain_monitor(BV.UI.get_active_brain_monitor())


func _exit_tree() -> void:
	if _presentation_mode_active:
		presentation_close()


## Use the PancakeCam under this brain monitor (or clear if the path is missing).
func configure_from_brain_monitor(bm: UI_BrainMonitor_3DScene) -> void:
	if bm != null and bm.has_node("SubViewport/Center/PancakeCam"):
		_camera = bm.get_node("SubViewport/Center/PancakeCam") as Camera3D
	else:
		_camera = null
	_sync_action_button_states()

func _on_animation_save_text_changed() -> void:
	_persist_animation_json_cache()
	_sync_action_button_states()


func _persist_animation_json_cache() -> void:
	if _animation_save == null:
		return
	if _suppress_json_cache_writes:
		return
	var json_text: String = _animation_save.text
	# Guard against teardown-driven empty writes while closing the presentation flow.
	if json_text.is_empty() and _persisted_animation_json_cache != "":
		return
	_persisted_animation_json_cache = json_text
	if BV != null and BV.UI != null:
		BV.UI.set_meta(_PERSISTED_JSON_META_KEY, json_text)


func _load_persisted_animation_json_cache() -> String:
	if BV != null and BV.UI != null and BV.UI.has_meta(_PERSISTED_JSON_META_KEY):
		var cached_from_ui: Variant = BV.UI.get_meta(_PERSISTED_JSON_META_KEY, "")
		if cached_from_ui is String:
			var cached_text: String = cached_from_ui
			_persisted_animation_json_cache = cached_text
			return cached_text
	return _persisted_animation_json_cache

func _sync_action_button_states() -> void:
	# Play: enabled only when there is JSON content to execute.
	if _play_button != null and _animation_save != null:
		var has_animation_data := _animation_save.text.strip_edges() != ""
		_play_button.disabled = not has_animation_data
		_play_button.tooltip_text = "" if has_animation_data else _PLAY_DISABLED_TOOLTIP

func clear_stored_data() -> void:
	var counter: IntInput = $HBoxContainer/num_animation_points
	_stored_positions = []
	_stored_rotations = []
	_stored_times = []
	counter.current_int = 0
	_refresh_exported_animation_json()
	_sync_action_button_states()

func add_frame() -> void:
	if _camera == null:
		BV.NOTIF.add_notification("Developer Camera Animations: No active camera found")
		return
	_append_camera_transform(_camera.position, _camera.quaternion)
	_refresh_exported_animation_json()
	_sync_action_button_states()

func _refresh_exported_animation_json() -> void:
	if _animation_save == null:
		return
	var output_arr: Array = []

	for i in len(_stored_positions):
		output_arr.append(_export_index_as_dict(i))
	_animation_save.text = JSON.stringify(output_arr)

func execute_json() -> void:
	var text_node: TextEdit = $AnimationSave
	var json = text_node.text
	
	# Verify
	if JSON.parse_string(json) == null:
		BV.NOTIF.add_notification("Unable to parse JSON!")
		return
	if _camera == null:
		BV.NOTIF.add_notification("Developer Camera Animations: No active camera to play animation")
		return
	var input_frames: Array = JSON.parse_string(json)
	var parsed_frames: Array[Dictionary] = []
	for i in input_frames.size():
		if not (input_frames[i] is Dictionary):
			BV.NOTIF.add_notification("Invalid frame format at index %i!" % i)
			return
		var frame: Dictionary = input_frames[i]
		if "position" not in frame:
			BV.NOTIF.add_notification("Missing 'position' in frame %i!" % i)
			return
		if "rotation" not in frame:
			BV.NOTIF.add_notification("Missing 'rotation' in frame %i!" % i)
			return
		if "time" not in frame:
			BV.NOTIF.add_notification("Missing 'time' in frame %i!" % i)
			return
		parsed_frames.append(frame.duplicate())
	if parsed_frames.is_empty():
		BV.NOTIF.add_notification("Camera animation has no frames!")
		return
	_enter_presentation_mode(parsed_frames)


func _build_animation_from_frames(frames: Array[Dictionary], start_index: int = 0) -> Animation:
	var generated_animation: Animation = Animation.new()
	generated_animation.add_track(Animation.TrackType.TYPE_POSITION_3D, 0)
	generated_animation.add_track(Animation.TrackType.TYPE_ROTATION_3D, 1)
	# Target the camera node itself (AnimationPlayer will be a child of the camera)
	generated_animation.track_set_path(0, NodePath("."))
	generated_animation.track_set_path(1, NodePath("."))

	var frame_time: float = 0.0
	for i in range(start_index, frames.size()):
		var frame: Dictionary = frames[i]
		var frame_pos: Vector3 = FEAGIUtils.untyped_array_to_vector3(frame["position"])
		var frame_rot: Quaternion = FEAGIUtils.untyped_array_to_quaternion(frame["rotation"])
		generated_animation.position_track_insert_key(0, frame_time, frame_pos)
		generated_animation.rotation_track_insert_key(1, frame_time, frame_rot)
		frame_time += frame["time"]

	generated_animation.length = frame_time
	var lin_interp_option: OptionButton = get_node("../MovementInterp/move_interp") as OptionButton
	var rot_interp_option: OptionButton = get_node("../RotationInterp/rot_interp") as OptionButton
	var lin_interp: Animation.InterpolationType = lin_interp_option.get_selected_id() as Animation.InterpolationType
	var rot_interp: Animation.InterpolationType = rot_interp_option.get_selected_id() as Animation.InterpolationType
	generated_animation.track_set_interpolation_type(0, lin_interp)
	generated_animation.track_set_interpolation_type(1, rot_interp)
	return generated_animation


func _ensure_camera_animation_player() -> AnimationPlayer:
	var player: AnimationPlayer
	if _camera.has_node("AnimationPlayer"):
		player = _camera.get_node("AnimationPlayer") as AnimationPlayer
	else:
		player = AnimationPlayer.new()
		player.name = "AnimationPlayer"
		_camera.add_child(player)
	if not player.animation_finished.is_connected(_on_animation_player_finished):
		player.animation_finished.connect(_on_animation_player_finished)
	player.root_node = NodePath("..")
	return player


func _set_player_animation(player: AnimationPlayer, anim_name: StringName, animation: Animation) -> void:
	var default_lib_name: StringName = ""
	var lib: AnimationLibrary
	if player.has_animation_library(default_lib_name):
		lib = player.get_animation_library(default_lib_name)
	else:
		lib = AnimationLibrary.new()
		player.add_animation_library(default_lib_name, lib)
	if lib.has_animation(anim_name):
		lib.remove_animation(anim_name)
	lib.add_animation(anim_name, animation)


func _stop_timed_playback(stop_mode: bool = true) -> void:
	if _camera == null or not _camera.has_node("AnimationPlayer"):
		_presentation_is_playing_timed = false
		if stop_mode:
			_update_presentation_overlay_state()
		return
	var player := _camera.get_node("AnimationPlayer") as AnimationPlayer
	var paused_position: Vector3 = _camera.position
	var paused_rotation: Quaternion = _camera.quaternion
	if _presentation_is_playing_timed:
		_presentation_current_index = _estimate_checkpoint_index_from_player(player)
	player.pause()
	# Always stop to reset timeline state; we restore exact pause pose below.
	player.stop()
	_presentation_is_playing_timed = false
	if stop_mode:
		_camera.position = paused_position
		_camera.quaternion = paused_rotation
		_update_presentation_overlay_state()


func _estimate_checkpoint_index_from_player(player: AnimationPlayer) -> int:
	if _presentation_frames.is_empty():
		return 0
	var elapsed: float = player.current_animation_position
	var idx: int = _timed_playback_start_index
	var consumed: float = 0.0
	while idx < _presentation_frames.size() - 1:
		var segment_time: float = float(_presentation_frames[idx].get("time", 0.0))
		if elapsed < consumed + segment_time:
			break
		consumed += segment_time
		idx += 1
	return clampi(idx, 0, _presentation_frames.size() - 1)


func _enter_presentation_mode(frames: Array[Dictionary]) -> void:
	if _camera != null:
		_presentation_initial_camera_position = _camera.position
		_presentation_initial_camera_rotation = _camera.quaternion
		_has_presentation_initial_camera_pose = true
	else:
		_has_presentation_initial_camera_pose = false
	_stop_timed_playback(false)
	_presentation_frames = frames
	_presentation_mode_active = true
	_presentation_current_index = 0
	_timed_playback_start_index = 0
	_presentation_is_playing_timed = false
	_apply_presentation_frame(0)
	BV.UI.show_camera_presentation_overlay(self)
	_update_presentation_overlay_state()
	_close_host_camera_animation_window()


func _close_host_camera_animation_window() -> void:
	var walker: Node = self
	while walker != null:
		if walker is BaseDraggableWindow:
			var host_window: Control = walker as Control
			_hidden_host_window = host_window
			host_window.visible = false
			return
		walker = walker.get_parent()


func _apply_presentation_frame(frame_index: int) -> void:
	if _camera == null or _presentation_frames.is_empty():
		return
	var clamped_index: int = clampi(frame_index, 0, _presentation_frames.size() - 1)
	var frame: Dictionary = _presentation_frames[clamped_index]
	_camera.position = FEAGIUtils.untyped_array_to_vector3(frame["position"])
	_camera.quaternion = FEAGIUtils.untyped_array_to_quaternion(frame["rotation"])
	_presentation_current_index = clamped_index


func _update_presentation_overlay_state() -> void:
	if not _presentation_mode_active:
		return
	var can_step: bool = not _presentation_is_playing_timed
	var can_step_prev: bool = can_step and _presentation_current_index > 0
	var can_step_next: bool = can_step and _presentation_current_index < _presentation_frames.size() - 1
	BV.UI.set_camera_presentation_overlay_state(_presentation_is_playing_timed, can_step_prev, can_step_next)


func _on_animation_player_finished(anim_name: StringName) -> void:
	if anim_name != _DEV_CAM_ANIMATION_NAME:
		return
	if not _presentation_mode_active:
		return
	_presentation_is_playing_timed = false
	_presentation_current_index = _presentation_frames.size() - 1
	_apply_presentation_frame(_presentation_current_index)
	_update_presentation_overlay_state()


func presentation_previous_checkpoint() -> void:
	if not _presentation_mode_active or _presentation_is_playing_timed:
		return
	if _presentation_current_index <= 0:
		return
	_apply_presentation_frame(_presentation_current_index - 1)
	_update_presentation_overlay_state()


func presentation_next_checkpoint() -> void:
	if not _presentation_mode_active or _presentation_is_playing_timed:
		return
	if _presentation_current_index >= _presentation_frames.size() - 1:
		return
	_apply_presentation_frame(_presentation_current_index + 1)
	_update_presentation_overlay_state()


func presentation_reset_to_initial() -> void:
	if not _presentation_mode_active:
		return
	if _presentation_is_playing_timed:
		_stop_timed_playback(true)
	if _camera != null and _has_presentation_initial_camera_pose:
		_camera.position = _presentation_initial_camera_position
		_camera.quaternion = _presentation_initial_camera_rotation
	if not _presentation_frames.is_empty():
		_presentation_current_index = 0
	_update_presentation_overlay_state()


func presentation_toggle_play_pause() -> void:
	if not _presentation_mode_active or _camera == null:
		return
	if _presentation_is_playing_timed:
		_stop_timed_playback(true)
		return
	if _presentation_current_index >= _presentation_frames.size() - 1:
		_apply_presentation_frame(0)
	var player: AnimationPlayer = _ensure_camera_animation_player()
	var generated_animation: Animation = _build_animation_from_frames(_presentation_frames, _presentation_current_index)
	_set_player_animation(player, _DEV_CAM_ANIMATION_NAME, generated_animation)
	_timed_playback_start_index = _presentation_current_index
	_presentation_is_playing_timed = true
	player.play(_DEV_CAM_ANIMATION_NAME)
	_update_presentation_overlay_state()


func presentation_close() -> void:
	if _presentation_close_in_progress:
		return
	_presentation_close_in_progress = true
	# Snapshot persisted JSON before any close/destruction side effects.
	_persist_animation_json_cache()
	_suppress_json_cache_writes = true
	if _presentation_mode_active:
		_stop_timed_playback(false)
	_restore_initial_camera_pose_if_available()
	_presentation_mode_active = false
	_presentation_frames.clear()
	_presentation_current_index = 0
	_timed_playback_start_index = 0
	_presentation_is_playing_timed = false
	_presentation_initial_camera_position = Vector3.ZERO
	_presentation_initial_camera_rotation = Quaternion.IDENTITY
	_has_presentation_initial_camera_pose = false
	var host_to_close: Control = _hidden_host_window
	_hidden_host_window = null
	if host_to_close != null and is_instance_valid(host_to_close):
		if host_to_close.has_method("close_window"):
			host_to_close.call_deferred("close_window")
		else:
			host_to_close.queue_free()
	if BV != null and BV.UI != null:
		BV.UI.hide_camera_presentation_overlay()
	# Re-apply on the next frame to guard against any late camera updates from animation teardown.
	call_deferred("_restore_initial_camera_pose_if_available")
	_presentation_close_in_progress = false


func _restore_initial_camera_pose_if_available() -> void:
	if _camera == null or not _has_presentation_initial_camera_pose:
		return
	_camera.position = _presentation_initial_camera_position
	_camera.quaternion = _presentation_initial_camera_rotation

func _append_camera_transform(cam_position: Vector3, cam_rotation: Quaternion) -> void:
	var tran_time_node: FloatInput = get_node("../TransitionTime/transition_time") as FloatInput
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
