extends Control
class_name CorticalNode
## Represents a Cortical Area in a node graph

var cortical_area_name: StringName:
	get:
		if(_cortical_area_ref):
			return _cortical_area_ref.name
		return "ERROR NOT SETUP"

var cortical_area_ID: StringName:
	get: 
		if(_cortical_area_ref):
			return _cortical_area_ref.cortical_ID
		return "ERROR NOT SETUP"

var _cortical_area_ref: CorticalArea

## Since we cannot use _init for scenes, use this instead to initialize
func setup(cortical_area: CorticalArea, node_position: Vector2) -> void:
	_cortical_area_ref = cortical_area
	position = node_position

## FEAGI deleted cortical area, so this node must go
func FEAGI_delete_cortical_area() -> void:
	pass

## user is dragging node around
func on_drag(moving_position: Vector2) -> void:
	pass

## User stopped dragging the node around, request FEAGI to save node position
func on_drag_stop(final_position: Vector2) -> void:
	pass

## User hit the X button to attempt to delete the cortical area
## Request FEAGI for deletion of area
func _user_request_delete_cortical_area() -> void:
	pass






