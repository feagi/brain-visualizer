extends Control
class_name MouseControls

var graphOffset: Vector2
var startDragOffset: Vector2
var graphFollowMouse: bool = false
var graphShader: Material
var graphRef: Sprite2D

var relativeMousePosition: Vector2:
	get:
		var output: Vector2 = get_viewport().get_mouse_position()
		output.x = output.x / get_viewport_rect().size.x
		output.y = output.x / get_viewport_rect().size.y
		return output


# Called when the node enters the scene tree for the first time.
func _ready():
	graphRef = get_parent().get_child(0)
	graphShader = graphRef.material
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if graphFollowMouse:
		graphOffset = startDragOffset + relativeMousePosition
		graphShader.set_shader_parameter("offset", graphOffset)
	pass

func _startDrag():
	startDragOffset = relativeMousePosition
	graphFollowMouse= true

func _endDrag():
	graphFollowMouse= false
	graphOffset = startDragOffset + relativeMousePosition
	


func _input(event):

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_startDrag()
		else:
			_endDrag()

