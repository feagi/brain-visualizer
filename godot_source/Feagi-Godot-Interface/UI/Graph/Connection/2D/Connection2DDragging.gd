extends Connection2DBase
class_name Connection2DDragging
## Used for user to see dragging line when connecting 

var source_node: CorticalNode
var _mouse_button_to_release: MouseButton
var _background_center: CanvasItem

func _init(line_source_node: CorticalNode,  parent_object: CanvasItem, button_to_let_go: MouseButton = MouseButton.MOUSE_BUTTON_LEFT) -> void:
	parent_object.add_child(self)
	_background_center = parent_object
	source_node = line_source_node
	super()
	set_line_source_node(line_source_node)
	_mouse_button_to_release = button_to_let_go
	end_point = get_local_mouse_position()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_mouse_button(event)
	if event is InputEventMouseMotion:
		_mouse_move(event)

	

func _mouse_move(event: InputEventMouseMotion):
	end_point = get_local_mouse_position()


func _mouse_button(event: InputEventMouseButton):
	
	if event.button_index != _mouse_button_to_release:
		return
	
	if event.pressed:
		return
	# mouse released, lets check if we are in an area
	# We know all input buttons are added to the 'CB_Input' group, pull all nodes from there
	# and check if our mouse position is within the rect of any of those
	var all_inputs: Array = get_tree().get_nodes_in_group("CB_Input")
	var mouse_position: Vector2 = get_global_mouse_position()
	for input in all_inputs:
		var rectangle: Rect2 = input.get_global_rect()
		if rectangle.has_point(mouse_position):
			print("GRAPH: User Dragged to " + input.cortical_node_parent.cortical_area_ID)
			VisConfig.window_manager.spawn_edit_mappings(source_node.cortical_area_ref, input.cortical_node_parent.cortical_area_ref)
			queue_free()
			return
	
	print("GRAPH: Drag Connection Dropped")
	queue_free()
