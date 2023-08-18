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
var direction = Vector3(0, 0, 0)
var velocity = Vector3(0, 0, 0)
var flagged = false ## This allows space and del to be able to send data without being overwritten by spam "{}"
var is_not_typing = true
var cortical_pointer = ""

const CAMERA_TURN_SPEED = 200

@export_range(0, 10, 0.01) var sensitivity : float = 3

func _input(event):
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CONFINED_HIDDEN:
		if event is InputEventMouseMotion:
			if Input.is_physical_key_pressed(KEY_SHIFT): # boost
	#	        rotate_y(-event.relative.x * mouse_sensitivity)
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
			elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
				rotation.y -= event.relative.x / 1000 * sensitivity # TODO: Need to look how blender rotates based on origin
				rotation.x -= event.relative.y / 1000 * sensitivity

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN if event.pressed else Input.MOUSE_MODE_VISIBLE)
			MOUSE_BUTTON_WHEEL_UP: # zoom in
					var direction = Vector3(
						0,
						0, 
						-5
					).normalized()
					translate(direction)
			MOUSE_BUTTON_WHEEL_DOWN: # zoom out
					var direction = Vector3(
						0,
						0,
						5
					).normalized()
					translate(direction)
					
