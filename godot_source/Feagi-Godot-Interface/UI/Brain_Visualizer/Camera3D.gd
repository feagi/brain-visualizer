# Copyright 2016-2022 The FEAGI Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

extends Camera3D

const CAMERA_TURN_SPEED = 200

@export var camera_pan_button: MouseButton = MOUSE_BUTTON_LEFT
@export var camera_turn_button: MouseButton = MOUSE_BUTTON_RIGHT
@export var camera_movement_speed: float =  2.0
@export var camera_pan_speed: float = 0.1
@export var camera_rotation_speed: float = 0.001
# Are these exports used?
@export var forward_action = "ui_up"
@export var backward_action = "ui_down"
@export var left_action = "ui_left"
@export var right_action = "ui_right"
@export var spacebar = "ui_select"
@export var reset = "reset"

var _is_user_currently_focusing_camera: bool = false
var _initial_position: Vector3
var _initial_euler_rotation: Vector3

func _ready() -> void:
	var bv_background: FullScreenControl = get_node("../BV_Background")
	bv_background.click_event.connect(_scroll_movment_and_toggle_camera_focus)
	bv_background.pan_event.connect(_touch_pan_gesture)
	_initial_position = position
	_initial_euler_rotation = rotation_degrees

# Guard Clauses!
func _input(event: InputEvent):

	# Feagi Interaction doesnt require camera control
	if event is InputEventKey:
		_FEAGI_data_interaction(event)

	if !_is_user_currently_focusing_camera:
		return
	
	# If user starts / stops keyboard press
	if event is InputEventKey:
		_keyboard_camera_movement(event)

	# If user is moving the mouse
	if event is  InputEventMouseMotion:
		_mouse_motion(event)

## Resets Cameras position and rotation to starting state
func reset_camera() -> void:
	teleport_to(_initial_position, _initial_euler_rotation)


func teleport_to(new_position: Vector3, new_euler_rotation: Vector3) -> void:
	position = new_position
	rotation_degrees = new_euler_rotation


func _scroll_movment_and_toggle_camera_focus(event: InputEventMouseButton):

	# This section is here to allow for scroll movement without having to focus the camera
	match event.button_index:
		MOUSE_BUTTON_WHEEL_DOWN:
			translate(Vector3(0,0,camera_movement_speed))
		MOUSE_BUTTON_WHEEL_UP:
			translate(Vector3(0,0,-camera_movement_speed))

	if (event.button_index != camera_pan_button) and (event.button_index != camera_turn_button):
		return
	_is_user_currently_focusing_camera = event.is_pressed()


# The camera itself should probably not be the thing sending the websocket requests. TODO move to seperate once we have the free time
func _FEAGI_data_interaction(_keyboard_event: InputEventKey) -> void:
	if Input.is_action_just_pressed("spacebar"): 
		$"../../../FEAGIInterface".net.websocket_send(str(Godot_list.godot_list))
		print(Godot_list.godot_list)
		return
	if Input.is_action_just_pressed("del"): 
		for key in Godot_list.godot_list["data"]["direct_stimulation"]:
			Godot_list.godot_list["data"]["direct_stimulation"][key] = []
			print(Godot_list.godot_list)
		return




# TODO fix the awkward initial delay, we need to move this to a fixed process thread
func _keyboard_camera_movement(_keyboard_event: InputEventKey) -> void:
	var dir: Vector3 = Vector3(0,0,0)

	if Input.is_key_pressed(KEY_R):
		reset_camera()
		return
	if Input.is_key_pressed(KEY_W):
		dir += Vector3(0,0,-1)
	if Input.is_key_pressed(KEY_S):
		dir += Vector3(0,0,1)
	if Input.is_key_pressed(KEY_A):
		dir += Vector3(-1,0,0)
	if Input.is_key_pressed(KEY_D):
		dir += Vector3(1,0,0)
	if Input.is_key_pressed(KEY_UP):
		dir += Vector3(0,0,-1)
	if Input.is_key_pressed(KEY_DOWN):
		dir += Vector3(0,0,1)
	if Input.is_key_pressed(KEY_LEFT):
		dir += Vector3(-1,0,0)
	if Input.is_key_pressed(KEY_RIGHT):
		dir += Vector3(1,0,0)
	
	dir = dir.normalized() * camera_movement_speed
	translate(dir)


# TODO couldnt panning happen in 2 dimensions? not just y? This should be discussed so we are all in agreeement
## Touch screen panning
func _touch_pan_gesture(event: InputEventPanGesture) -> void:
	var direction = Vector3(0,0,event.delta.y).normalized()
	translate(direction)

## Mouse moving controls
func _mouse_motion(event: InputEventMouseMotion) -> void:


	if Input.is_mouse_button_pressed(camera_turn_button):
		rotation.x += event.relative.y * -camera_rotation_speed
		rotation.y += event.relative.x * -camera_rotation_speed
		return
	
	if Input.is_mouse_button_pressed(camera_pan_button):
		var move: Vector3 = Vector3(event.relative.x * -camera_pan_speed, event.relative.y * camera_pan_speed, 0)
		translate(move)


