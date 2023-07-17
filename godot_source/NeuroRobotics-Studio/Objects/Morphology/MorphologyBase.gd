extends Object
class_name MorphologyBase
# Base class for other morphology types


var name: String:
	get: return _name

var _name: String

func _init(morphologyName: String):
	_name = morphologyName
