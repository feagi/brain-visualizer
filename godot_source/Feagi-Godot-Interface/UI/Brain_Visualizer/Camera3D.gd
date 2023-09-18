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

# Are these exports used?
@export var forward_action = "ui_up"
@export var backward_action = "ui_down"
@export var left_action = "ui_left"
@export var right_action = "ui_right"
@export var spacebar = "ui_select"
@export var reset = "reset"

var rotation_speed = PI

var x = transform.origin.x
var y = transform.origin.y
var z = transform.origin.z
var x_rotation = Vector3(13.3, 0.0, 0.0)
var velocity = Vector3(0, 0, 0)
var flagged = false ## This allows space and del to be able to send data without being overwritten by spam "{}"| TODO this seems unused?
var cortical_pointer = "" # TODO this seems unused?
var disable_mouse_control = false

const CAMERA_TURN_SPEED = 200

@export_range(0, 10, 0.01) var sensitivity : float = 3

# Guard Clauses!
func _input(event: InputEvent):

	# No movement if the user is typing
	#if VisConfig.is_user_typing:
	#	return
	
	# No movement if the user is dragging a window
	#if VisConfig.is_user_dragging_a_window:
	#	return
	
	# If user starts / stops keyboard press
	if event is InputEventKey:
		_FEAGI_data_interaction(event)

	# If user is panning with the touchscreen
	if event is InputEventPanGesture:
		_touch_pan_gesture(event)
	
	# If user is moving the mouse
	if event is  InputEventMouseMotion:
		_mouse_motion(event)
	
	# If user is pressing a mouse button (or scrolling)
	if event is InputEventMouseButton:
		_mouse_button(event)


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

# TODO couldnt panning happen in 2 dimensions? not just y? This should be discussed so we are all in agreeement
## Touch screen panning
func _touch_pan_gesture(event: InputEventPanGesture) -> void:
	var direction = Vector3(0,0,event.delta.y).normalized()
	translate(direction)

## Mouse moving controls
func _mouse_motion(event: InputEventMouseMotion) -> void:
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_action_pressed("control")):
		rotation.y += event.relative.x / 1000 * sensitivity # TODO: Need to look how blender rotates based on origin
		rotation.x += event.relative.y / 1000 * sensitivity
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_action_pressed("shift"): # boost
		#rotate_y(-event.relative.x * mouse_sensitivity)
		var horizational_view = 0
		var vertical_view = 0
		var speed = 2

		if abs(event.relative.x) > abs(event.relative.y): # whichever moves first
			if event.relative.x > 0:
				horizational_view = -speed
			elif event.relative.x < 0:
				horizational_view = speed
		else:
			if event.relative.y > 0:
				vertical_view = speed
			elif event.relative.y < 0:
				vertical_view = -speed

		var direction_X = Vector3(horizational_view, 0, 0)
		var direction_Y = Vector3(0, vertical_view, 0)
		var direction = direction_X+direction_Y
		translate(direction)

# User is pressing a mouse button (or scrolling)
func _mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN if event.pressed else Input.MOUSE_MODE_VISIBLE)
		MOUSE_BUTTON_WHEEL_UP: # zoom in
				var direction = Vector3(0,0, -1)
				translate(direction)
		MOUSE_BUTTON_WHEEL_DOWN: # zoom out
				var direction = Vector3(0,0,5)
				translate(direction)
