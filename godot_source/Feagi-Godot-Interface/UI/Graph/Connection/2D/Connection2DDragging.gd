extends Connection2DBase
class_name Connection2DDragging
## Used for user to see dragging line when connecting 

var _mouse_button_to_release: MouseButton
var _background_center: CanvasItem

func _init(line_source_node: CorticalNode,  parent_object: CanvasItem, button_to_let_go: MouseButton = MouseButton.MOUSE_BUTTON_LEFT) -> void:
    parent_object.add_child(self)
    _background_center = parent_object
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
    
    #TODO check for if on area

    queue_free()