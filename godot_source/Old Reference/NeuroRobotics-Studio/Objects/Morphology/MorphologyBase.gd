extends Object
class_name MorphologyBase
# Base class for other morphology types

signal morphologyUpdated(MorphologyBase)

var name: MorphologyName:
	get: return _name

var timeOfLastMorphologyUpdate: float:
	get: return _timeOfLastMorphologyUpdate

var secondsSinceLastMorphologyUpdate: float:
	get: return  _timeOfLastMorphologyUpdate - Time.get_unix_time_from_system()

var _name: MorphologyName
var _timeOfLastMorphologyUpdate: float

func _init(morphologyNameStr: String):
	_name = MorphologyName.new(morphologyNameStr)
	_timeOfLastMorphologyUpdate = Time.get_unix_time_from_system()

