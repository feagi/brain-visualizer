extends Object
class_name WindowBase


var newnit
var _isWindowActive: bool = false
var _NewnitActivation: Dictionary = {}
var _parentRef: Node
var _newnitType: StringName

func _init(newnitObjectType: StringName, activation: Dictionary, parentRef: Node):
	_newnitType = newnitObjectType
	_parentRef = parentRef
	_NewnitActivation = activation
	_parentRef.add_child(newnit)
	pass

func Close() -> void:
	newnit.queue_free()

func Open(activation: Dictionary = _NewnitActivation) -> void:
	newnit = _ReturnNewnitType()
	_parentRef.add_child(newnit)
	newnit.Activate(activation)
	newnit.DataUp.connect(_DataFromNewnit)

func _DataFromNewnit(data: Dictionary) -> void:
	@warning_ignore("assert_always_false")
	assert(false, "_DataFromNewnit function not overriden correctly!")

func _ReturnNewnitType() -> Object:
	# A utterly stupid workaround for the limitation that ClassDB still doesn't register custom classes
	# without some cursed hackery I do not wish to apply here
	@warning_ignore("assert_always_false")
	assert(false, "_ReturnNewnitType function not overriden correctly!")
	return Newnit_Popup.new() # Example
