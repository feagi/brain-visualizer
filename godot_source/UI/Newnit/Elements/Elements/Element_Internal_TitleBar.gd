extends Element_Label
class_name Element_Internal_TitleBar
# This is unique header element with dragging functionality. Intended for title bars
# Do NOT spawn this manually

var isDraggable: bool = true

var isDragging: bool:
	get: return _dragger != null

var _dragger: Dragger_Sub

func _ActivationSecondary(settings: Dictionary) -> void:
	super(settings)
	
	
func _get_drag_data(at_position: Vector2):
	if !isDraggable: return
	_dragger = Dragger_Sub.new(parent.position) # Can only do this since its a popup
	_dragger.value_edited.connect(parent._DragUpProxy)

func _PopulateSubElements() -> Array:
	# used during Activation Primary to add Counter
	return ["titlebar"]

