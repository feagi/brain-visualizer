extends Object
class_name WindowBase

var isWindowActive: bool:
	get: return _isWindowActive
	set(v):
		_isWindowActive = v
		# TODO

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

func _onClose() -> void:
	newnit.queue_free()

func _onOpen() -> void:
	newnit = ClassDB.instantiate(_newnitType)
	_parentRef.add_child(newnit)
	newnit.Activate()

func _DataFromNewnit(data: Dictionary) -> void:
	@warning_ignore("assert_always_false")
	assert(false, "_DataFromNewnit function not overriden correctly!")
