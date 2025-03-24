extends Node
class_name UI_BrainMonitor_AbstractInteractableVolumeRenderer
## Base class for all rendering methods for interactive volumes Essentially just a fancy interface
## This class and all derived renderers are purely data sinks, they do not generate any input!

# NOTE: As setup functions may differ n what is required, we will not include it here!

var _position_FEAGI_space: Vector3i ## Lower front left corner, where Z goes away from you (FEAGI space)
var _position_godot_space: Vector3 ## Center of the mesh, as per the default Godot cube
var _dimensions: Vector3i

func update_position_with_new_FEAGI_coordinate(new_FEAGI_coordinate_position: Vector3i) -> void:
	_position_FEAGI_space = new_FEAGI_coordinate_position

	var lower_left_front_corner_offset: Vector3 = Vector3(_dimensions) / 2.0
	lower_left_front_corner_offset.z = -lower_left_front_corner_offset.z # flip Z direction
	_position_godot_space = Vector3(_position_FEAGI_space) + lower_left_front_corner_offset

func update_position_with_new_godot_coordinate(new_godot_coordinate_position: Vector3) -> void:
	_position_godot_space = new_godot_coordinate_position
	
	var lower_left_front_corner_offset: Vector3 = Vector3(_dimensions) / 2.0
	lower_left_front_corner_offset.z = -lower_left_front_corner_offset.z # flip Z direction
	new_godot_coordinate_position.z = -new_godot_coordinate_position.z
	new_godot_coordinate_position = new_godot_coordinate_position - lower_left_front_corner_offset
	_position_FEAGI_space = Vector3i(
		clampi(new_godot_coordinate_position.x, 0, _dimensions.x),
		clampi(new_godot_coordinate_position.y, 0, _dimensions.y),
		clampi(new_godot_coordinate_position.z, 0, _dimensions.z)
	)

func update_dimensions(new_dimensions: Vector3i) -> void:
	_dimensions = new_dimensions

	# Godot center position also changed if we are using the front left bottom corner as 0,0,0
	var lower_left_front_corner_offset: Vector3 = Vector3(_dimensions) / 2.0
	lower_left_front_corner_offset.z = -lower_left_front_corner_offset.z # flip Z direction
	_position_godot_space = Vector3(_position_FEAGI_space) + lower_left_front_corner_offset
	
