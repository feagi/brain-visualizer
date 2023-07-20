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

func Open() -> void:
	#newnit = ClassDB.instantiate(_newnitType)
	newnit = Newnit_Popup.new() # TODO THIS IS A HACK AND MUST BE REMOVED
	_parentRef.add_child(newnit)
	newnit.Activate(_NewnitActivation)
	newnit.DataUp.connect(_DataFromNewnit)

func _DataFromNewnit(data: Dictionary) -> void:
	@warning_ignore("assert_always_false")
	assert(false, "_DataFromNewnit function not overriden correctly!")
